' Fastream-only bounded TS segment prefetcher.
' Keeps at most two downloaded-but-unconsumed segments on disk.
sub init()
    m.top.functionName = "runTsPrefetch"
end sub

sub runTsPrefetch()
    port = CreateObject("roMessagePort")
    activeGeneration = -1
    ready = {}
    m.top.readyFiles = ready
    m.top.status = "running"
    print "[RokuPlus ts-prefetch] worker_started"

    while not m.top.stopRequested
        generation = m.top.generation
        requestIndex = m.top.requestIndex
        segments = m.top.segments

        if type(segments) <> "roArray" or segments.count() = 0
            wait(200, port)
        else
            if generation <> activeGeneration
                for each oldKey in ready
                    DeleteFile(ready[oldKey])
                end for
                ready = {}
                m.top.readyFiles = ready
                activeGeneration = generation
                print "[RokuPlus ts-prefetch] generation="; activeGeneration; " start="; requestIndex
            end if

            lastIndex = requestIndex + 1
            if lastIndex >= segments.count() then lastIndex = segments.count() - 1
            for index = requestIndex to lastIndex
                if m.top.stopRequested or m.top.generation <> activeGeneration then exit for
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
                        timer = CreateObject("roTimespan")
                        timer.Mark()
                        xfer.SetMessagePort(port)
                        print "[RokuPlus ts-prefetch] fetch_begin segment="; index
                        started = xfer.AsyncGetToFile(filePath)
                        code = -1
                        transferDone = false
                        cancelled = false
                        if started
                            while not transferDone
                                event = wait(200, port)
                                if type(event) = "roUrlEvent" and event.GetSourceIdentity() = xfer.GetIdentity()
                                    if event.GetInt() = 1
                                        code = event.GetResponseCode()
                                        transferDone = true
                                    end if
                                end if
                                if m.top.stopRequested or m.top.generation <> activeGeneration
                                    cancelled = true
                                    xfer.AsyncCancel()
                                    cancelTimer = CreateObject("roTimespan")
                                    cancelTimer.Mark()
                                    while not transferDone and cancelTimer.TotalMilliseconds() < 2500
                                        cancelEvent = wait(100, port)
                                        if type(cancelEvent) = "roUrlEvent" and cancelEvent.GetSourceIdentity() = xfer.GetIdentity() and cancelEvent.GetInt() = 1
                                            code = cancelEvent.GetResponseCode()
                                            transferDone = true
                                        end if
                                    end while
                                    exit while
                                end if
                            end while
                        end if
                        elapsed = timer.TotalMilliseconds()
                        if cancelled or m.top.generation <> activeGeneration or m.top.stopRequested
                            DeleteFile(filePath)
                            print "[RokuPlus ts-prefetch] fetch_cancelled segment="; index; " elapsedMs="; elapsed
                            exit for
                        end if
                        if transferDone and code >= 200 and code < 300
                            ready[key] = filePath
                            m.top.readyFiles = ready
                            print "[RokuPlus ts-prefetch] fetch_ready segment="; index; " elapsedMs="; elapsed
                        else
                            DeleteFile(filePath)
                            ready[key] = "FAILED"
                            m.top.readyFiles = ready
                            print "[RokuPlus ts-prefetch] fetch_failed segment="; index; " status="; code; " elapsedMs="; elapsed
                        end if
                    end if
                end if
            end for
            wait(150, port)
        end if
    end while

    for each key in ready
        DeleteFile(ready[key])
    end for
    m.top.readyFiles = {}
    m.top.status = "stopped"
    print "[RokuPlus ts-prefetch] worker_stopped"
end sub
