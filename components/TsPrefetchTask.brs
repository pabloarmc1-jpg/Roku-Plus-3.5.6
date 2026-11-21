' Fastream-only bounded TS segment prefetcher.
' Runs up to two independent HTTP transfers concurrently and publishes files
' only after their matching roUrlEvent confirms a successful HTTP response.
sub init()
    m.top.functionName = "runTsPrefetch"
end sub

sub runTsPrefetch()
    port = CreateObject("roMessagePort")
    activeGeneration = -1
    ready = {}
    pending = {}
    staleTransfers = {}
    nextToSchedule = 0
    m.top.readyFiles = ready
    m.top.status = "running"
    print "[RokuPlus ts-prefetch] worker_started concurrency=2"

    while not m.top.stopRequested
        generation = m.top.generation
        segments = m.top.segments

        if type(segments) <> "roArray" or segments.count() = 0
            wait(150, port)
        else
            if generation <> activeGeneration
                ' Cancel both old-generation requests before publishing a new window.
                pendingIds = []
                for each pendingId in pending
                    pendingIds.push(pendingId)
                end for
                for each pendingId in pendingIds
                    pendingEntry = pending[pendingId]
                    pendingEntry.xfer.AsyncCancel()
                end for
                cancelTimer = CreateObject("roTimespan")
                cancelTimer.Mark()
                while pending.count() > 0 and cancelTimer.TotalMilliseconds() < 2500
                    cancelEvent = wait(100, port)
                    if type(cancelEvent) = "roUrlEvent"
                        cancelId = cancelEvent.GetSourceIdentity().ToStr()
                        if pending.doesExist(cancelId)
                            cancelEntry = pending[cancelId]
                            DeleteFile(cancelEntry.filePath)
                            pending.Delete(cancelId)
                        end if
                    end if
                end while
                for each pendingId in pending
                    DeleteFile(pending[pendingId].filePath)
                end for
                pending = {}
                for each oldKey in ready
                    oldPath = ready[oldKey]
                    if GetInterface(oldPath, "ifString") <> invalid and oldPath <> "FAILED"
                        DeleteFile(oldPath)
                    end if
                end for
                ready = {}
                m.top.readyFiles = ready
                activeGeneration = generation
                nextToSchedule = m.top.requestIndex
                print "[RokuPlus ts-prefetch] generation="; activeGeneration; " start="; nextToSchedule
            end if

            ' Complete whichever transfer generated this event. Keep each transfer
            ' object referenced in pending until its own event arrives.
            event = wait(75, port)
            if type(event) = "roUrlEvent"
                eventId = event.GetSourceIdentity().ToStr()
                if pending.doesExist(eventId)
                    entry = pending[eventId]
                    statusCode = event.GetResponseCode()
                    elapsed = entry.timer.TotalMilliseconds()
                    if event.GetInt() = 1 and statusCode >= 200 and statusCode < 300 and m.top.generation = activeGeneration and not m.top.stopRequested
                        ready[entry.index.toStr()] = entry.filePath
                        m.top.readyFiles = ready
                        print "[RokuPlus ts-prefetch] fetch_ready segment="; entry.index; " status="; statusCode; " elapsedMs="; elapsed; " active="; pending.count()-1
                    else
                        DeleteFile(entry.filePath)
                        if m.top.generation = activeGeneration and not m.top.stopRequested
                            ready[entry.index.toStr()] = "FAILED"
                            m.top.readyFiles = ready
                            print "[RokuPlus ts-prefetch] fetch_failed segment="; entry.index; " status="; statusCode; " elapsedMs="; elapsed
                        end if
                    end if
                    pending.Delete(eventId)
                else if staleTransfers.doesExist(eventId)
                    ' A timed-out AsyncCancel may still deliver its completion event.
                    ' Remove any late file without allowing it to become a ready segment.
                    DeleteFile(staleTransfers[eventId])
                    staleTransfers.Delete(eventId)
                end if
            end if

            ' A stalled upstream request must not occupy either prefetch slot forever.
            timedOutIds = []
            for each pendingId in pending
                pendingEntry = pending[pendingId]
                if pendingEntry.timer.TotalMilliseconds() >= 30000 then timedOutIds.push(pendingId)
            end for
            for each timedOutId in timedOutIds
                timedOutEntry = pending[timedOutId]
                timedOutEntry.xfer.AsyncCancel()
                staleTransfers[timedOutId] = timedOutEntry.filePath
                DeleteFile(timedOutEntry.filePath)
                pending.Delete(timedOutId)
                if m.top.generation = activeGeneration and not m.top.stopRequested
                    ready[timedOutEntry.index.toStr()] = "FAILED"
                    m.top.readyFiles = ready
                end if
                print "[RokuPlus ts-prefetch] fetch_timeout segment="; timedOutEntry.index; " elapsedMs="; timedOutEntry.timer.TotalMilliseconds()
            end for

            ' Fill at most two transfer slots. Keep the scheduling horizon close
            ' to the segment the relay is currently waiting to consume.
            requestIndex = m.top.requestIndex
            lastAllowed = requestIndex + 2
            if lastAllowed >= segments.count() then lastAllowed = segments.count() - 1
            while pending.count() < 2 and nextToSchedule <= lastAllowed and nextToSchedule < segments.count()
                if m.top.stopRequested or m.top.generation <> activeGeneration then exit while
                index = nextToSchedule
                nextToSchedule++
                key = index.toStr()
                if not ready.doesExist(key)
                    segmentUrl = segments[index]
                    if GetInterface(segmentUrl, "ifString") <> invalid and left(segmentUrl, 8) = "https://"
                        filePath = "tmp:/rp_fastream_" + activeGeneration.toStr() + "_" + key + ".ts"
                        DeleteFile(filePath)
                        xfer = CreateObject("roUrlTransfer")
                        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
                        xfer.SetUrl(segmentUrl)
                        headers = m.top.mediaHeaders
                        if type(headers) = "roAssociativeArray"
                            agent = headers["User-Agent"]
                            referer = headers["Referer"]
                            if GetInterface(agent, "ifString") <> invalid and len(agent) > 0 then xfer.AddHeader("User-Agent", agent)
                            if GetInterface(referer, "ifString") <> invalid and len(referer) > 0 then xfer.AddHeader("Referer", referer)
                        end if
                        xfer.SetMessagePort(port)
                        timer = CreateObject("roTimespan")
                        timer.Mark()
                        started = xfer.AsyncGetToFile(filePath)
                        if started
                            transferId = xfer.GetIdentity().ToStr()
                            pending[transferId] = {xfer:xfer,index:index,filePath:filePath,timer:timer}
                            print "[RokuPlus ts-prefetch] fetch_begin segment="; index; " active="; pending.count()
                        else
                            DeleteFile(filePath)
                            ready[key] = "FAILED"
                            m.top.readyFiles = ready
                            print "[RokuPlus ts-prefetch] fetch_start_failed segment="; index
                        end if
                    else
                        ready[key] = "FAILED"
                        m.top.readyFiles = ready
                    end if
                end if
            end while
        end if
    end while

    pendingIds = []
    for each pendingId in pending
        pendingIds.push(pendingId)
    end for
    for each pendingId in pendingIds
        pending[pendingId].xfer.AsyncCancel()
    end for
    cancelTimer = CreateObject("roTimespan")
    cancelTimer.Mark()
    while pending.count() > 0 and cancelTimer.TotalMilliseconds() < 2500
        cancelEvent = wait(100, port)
        if type(cancelEvent) = "roUrlEvent"
            cancelId = cancelEvent.GetSourceIdentity().ToStr()
            if pending.doesExist(cancelId)
                DeleteFile(pending[cancelId].filePath)
                pending.Delete(cancelId)
            end if
        end if
    end while
    for each pendingId in pending
        DeleteFile(pending[pendingId].filePath)
    end for
    for each key in ready
        readyPath = ready[key]
        if GetInterface(readyPath, "ifString") <> invalid and readyPath <> "FAILED"
            DeleteFile(readyPath)
        end if
    end for
    m.top.readyFiles = {}
    m.top.status = "stopped"
    print "[RokuPlus ts-prefetch] worker_stopped"
end sub
