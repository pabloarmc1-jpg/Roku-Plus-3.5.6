' Experimental single-connection MPEG-TS relay. One HTTP response carries all source segments.
sub init()
    m.top.functionName = "runTsStreamServer"
end sub

sub runTsStreamServer()
    ' The listener has not opened yet: safely remove a relay payload left by
    ' an interrupted previous application session.
    relayTempPath = "tmp:/rp_ts_relay_segment.ts"
    if DeleteFile(relayTempPath)
        print "[RokuPlus ts-relay] startup_cleanup removed_stale_payload=true"
    end if
    port = CreateObject("roMessagePort")
    listener = CreateObject("roStreamSocket")
    listener.setMessagePort(port)
    address = CreateObject("roSocketAddress")
    if not address.setPort(49322)
        m.top.status = "address_error"
        print "[RokuPlus ts-relay] server_failed stage=address"
        return
    end if
    if not listener.setAddress(address)
        m.top.status = "bind_error"
        print "[RokuPlus ts-relay] server_failed stage=bind"
        return
    end if
    listener.notifyReadable(true)
    if not listener.listen(2)
        m.top.status = "listen_error"
        print "[RokuPlus ts-relay] server_failed stage=listen"
        listener.close()
        return
    end if
    m.top.status = "listening"
    print "[RokuPlus ts-relay] listening port=49322 segments="; m.top.segments.count()
    ' Keep the local listener reusable. stopRequested aborts the active response
    ' and rejects new clients until the next playback request resets the flag.
    while true
        event = wait(250,port)
        if type(event) = "roSocketEvent"
            if event.getSocketID() = listener.getID() and listener.isReadable()
                connection = listener.accept()
                if connection <> invalid
                    if m.top.stopRequested
                        connection.close()
                    else
                        rpTsRelayServe(connection,m.top)
                    end if
                end if
            end if
        end if
    end while
end sub

sub rpTsRelayServe(connection as object, server as object)
    connectionGeneration = server.generation
    server.connectionGeneration = connectionGeneration
    request = ""
    complete = false
    connectionPort = CreateObject("roMessagePort")
    connection.setMessagePort(connectionPort)
    connection.notifyReadable(true)
    connection.notifyWritable(true)
    connection.notifyException(true)
    requestTimer = CreateObject("roTimespan")
    requestTimer.Mark()
    while len(request) < 8192 and not complete and requestTimer.TotalMilliseconds() < 5000 and not server.stopRequested and connectionGeneration = server.generation
        if connection.isException() then exit while
        if connection.isReadable()
            part = connection.receiveStr(2048)
            if part = "" then exit while
            request += part
            if instr(1,request,chr(13)+chr(10)+chr(13)+chr(10)) > 0 then complete = true
        else
            requestEvent = wait(100,connectionPort)
            if type(requestEvent) = "roSocketEvent"
                if requestEvent.getSocketID() = connection.getID() and connection.isException() then exit while
            end if
        end if
    end while
    if server.stopRequested or connectionGeneration <> server.generation
        connection.close()
        return
    end if
    if not complete
        if requestTimer.TotalMilliseconds() >= 5000
            print "[RokuPlus ts-relay] rejected_incomplete_request reason=timeout"
        else if len(request) >= 8192
            print "[RokuPlus ts-relay] rejected_incomplete_request reason=header_limit"
        else
            print "[RokuPlus ts-relay] rejected_incomplete_request reason=closed_or_exception"
        end if
        connection.close()
        return
    end if
    firstLine = request.split(chr(10))[0].trim()
    parts = firstLine.split(" ")
    if left(firstLine,4) <> "GET "
        rpTsRelaySendString(connection,"HTTP/1.1 405 Method Not Allowed"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
        connection.close()
        return
    end if
    accessKey = server.accessKey
    requestPath = ""
    if parts.count() >= 2 then requestPath = parts[1]
    queryStart = instr(1,requestPath,"?")
    pathOnly = requestPath
    query = ""
    if queryStart > 0
        pathOnly = left(requestPath,queryStart-1)
        query = mid(requestPath,queryStart+1)
    end if
    suppliedKey = ""
    requestedSegment = ""
    queryValid = true
    if query <> ""
        for each parameter in query.split("&")
            pair = parameter.split("=")
            if pair.count() <> 2
                queryValid = false
                exit for
            end if
            if pair[0] = "key"
                suppliedKey = pair[1]
            else if pair[0] = "segment"
                requestedSegment = pair[1]
            else
                queryValid = false
                exit for
            end if
        end for
    else
        queryValid = false
    end if
    if GetInterface(accessKey,"ifString") = invalid or len(accessKey) < 16 or pathOnly <> "/stream.ts" or suppliedKey <> accessKey or not queryValid
        rpTsRelaySendString(connection,"HTTP/1.1 403 Forbidden"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
        connection.close()
        print "[RokuPlus ts-relay] rejected_client"
        return
    end if
    requestedIndex = -1
    if requestedSegment <> ""
        requestedIndex = requestedSegment.toInt()
        if requestedIndex < 0 or requestedIndex.toStr() <> requestedSegment or requestedIndex >= server.segments.count()
            rpTsRelaySendString(connection,"HTTP/1.1 400 Bad Request"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
            connection.close()
            print "[RokuPlus ts-relay] rejected_segment_request"
            return
        end if
    end if
    print "[RokuPlus ts-relay] client_connected"
    header = "HTTP/1.1 200 OK"+chr(13)+chr(10)
    header += "Content-Type: video/mp2t"+chr(13)+chr(10)
    header += "Transfer-Encoding: chunked"+chr(13)+chr(10)
    header += "Cache-Control: no-store"+chr(13)+chr(10)
    header += "Connection: close"+chr(13)+chr(10)+chr(13)+chr(10)
    rpTsRelaySendString(connection,header,server,connectionPort)
    if not server.sendOk
        connection.close()
        return
    end if
    segments = server.segments
    headers = server.mediaHeaders
    sentSegments = 0
    sentBytes = 0
    ' Keep PID continuity baselines across every HLS segment in this relay response.
    tsContinuityState = {lastCounters:{},haveCounters:{},errors:0,duplicates:0,checked:0}
    tsClockState = {lastPcr:{},havePcr:{},lastDts:{},haveDts:{},lastPts:{},havePts:{},pcrWraps:0,pcrRegressions:0,dtsWraps:0,dtsRegressions:0,ptsWraps:0,psiBuffers:{},psiTables:{},psiActiveVersions:{},pesBuffers:{},headerLastCounters:{},headerHaveCounters:{},pmtPid:-1,programNumber:-1,pcrPid:-1,pmtSignature:"",videoPid:-1,audioPids:[]}
    segmentDiscontinuities = server.segmentDiscontinuities
    startIndex = server.nextSegmentIndex
    if GetInterface(startIndex,"ifInt") = invalid or startIndex < 0 then startIndex = 0
    if requestedIndex >= 0 then startIndex = requestedIndex
    print "[RokuPlus ts-relay] stream_start segment="; startIndex
    prefetchTask = server.prefetchTask
    prefetchGeneration = -1
    if prefetchTask <> invalid then prefetchGeneration = prefetchTask.generation
    for segmentIndex = startIndex to segments.count() - 1
        if server.stopRequested or connectionGeneration <> server.generation then exit for
        if prefetchTask <> invalid
            if prefetchTask.stopRequested or prefetchTask.generation <> prefetchGeneration
                print "[RokuPlus ts-relay] prefetch_generation_changed segment="; segmentIndex
                exit for
            end if
        end if
        if type(segmentDiscontinuities) = "roArray" and segmentDiscontinuities.count() = segments.count()
            if segmentDiscontinuities[segmentIndex] = true
                print "[RokuPlus ts-clock] hls_discontinuity segment="; segmentIndex; " reset=clock_and_continuity_baselines"
                rpTsRelayResetProgramState(tsClockState)
                tsContinuityState.lastCounters = {}
                tsContinuityState.haveCounters = {}
            end if
        end if
        segmentUrl = segments[segmentIndex]
        if GetInterface(segmentUrl,"ifString") = invalid then exit for
        if left(segmentUrl,8) <> "https://" then exit for
        xfer = CreateObject("roUrlTransfer")
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.SetUrl(segmentUrl)
        if type(headers) = "roAssociativeArray"
            agent = headers["User-Agent"]
            referer = headers["Referer"]
            if GetInterface(agent,"ifString") <> invalid and len(agent) > 0 then xfer.AddHeader("User-Agent",agent)
            if GetInterface(referer,"ifString") <> invalid and len(referer) > 0 then xfer.AddHeader("Referer",referer)
        end if
        filePath = "tmp:/rp_ts_relay_segment.ts"
        DeleteFile(filePath)
        prefetched = false
        if prefetchTask <> invalid
            prefetchTimer = CreateObject("roTimespan")
            prefetchTimer.Mark()
            prefetchPath = ""
            prefetchKey = segmentIndex.toStr()
            generationChanged = false
            while prefetchTimer.TotalMilliseconds() < 180000 and not server.stopRequested and connectionGeneration = server.generation
                if prefetchTask.stopRequested or prefetchTask.generation <> prefetchGeneration
                    generationChanged = true
                    exit while
                end if
                readyMap = prefetchTask.readyFiles
                if type(readyMap) = "roAssociativeArray" and readyMap.doesExist(prefetchKey)
                    candidatePath = readyMap[prefetchKey]
                    if GetInterface(candidatePath, "ifString") <> invalid and candidatePath <> "FAILED"
                        prefetchPath = candidatePath
                    end if
                    exit while
                end if
                wait(200, connectionPort)
            end while
            if generationChanged
                print "[RokuPlus ts-relay] prefetch_generation_changed_wait segment="; segmentIndex
                exit for
            end if
            if prefetchPath <> ""
                filePath = prefetchPath
                prefetched = true
                print "[RokuPlus ts-relay] prefetch_hit segment="; segmentIndex; " waitMs="; prefetchTimer.TotalMilliseconds()
            else
                print "[RokuPlus ts-relay] prefetch_miss segment="; segmentIndex; " waitMs="; prefetchTimer.TotalMilliseconds()
            end if
        end if
        if not prefetched
            fetchTimer = CreateObject("roTimespan")
            fetchTimer.Mark()
            print "[RokuPlus ts-relay] upstream_fetch_begin segment="; segmentIndex
            code = xfer.GetToFile(filePath)
            fetchMs = fetchTimer.TotalMilliseconds()
            if server.stopRequested or connectionGeneration <> server.generation
                DeleteFile(filePath)
                exit for
            end if
            print "[RokuPlus ts-relay] upstream_fetch_end segment="; segmentIndex; " status="; code; " elapsedMs="; fetchMs
            if code < 200 or code >= 300
                print "[RokuPlus ts-relay] upstream_failed index="; sentSegments+1; " status="; code
                DeleteFile(filePath)
                exit for
            end if
        end if
        if server.stopRequested or connectionGeneration <> server.generation
            DeleteFile(filePath)
            exit for
        end if
        ' Reject oversized or missing segment files before allocating a byte array.
        ' 16 MiB is above ordinary HLS TS segment sizes while bounding relay RAM.
        fileSystem = CreateObject("roFileSystem")
        diskSize = fileSystem.GetFileSize(filePath)
        if diskSize <= 0 or diskSize > 16777216
            print "[RokuPlus ts-relay] segment_rejected index="; segmentIndex; " bytes="; diskSize; " limit=16777216"
            DeleteFile(filePath)
            if prefetched
                readyMap = prefetchTask.readyFiles
                if type(readyMap) = "roAssociativeArray" and readyMap.doesExist(segmentIndex.toStr())
                    readyMap.Delete(segmentIndex.toStr())
                    prefetchTask.readyFiles = readyMap
                end if
            end if
            exit for
        end if
        payload = CreateObject("roByteArray")
        if not payload.ReadFile(filePath)
            print "[RokuPlus ts-relay] file_read_failed index="; sentSegments+1
            DeleteFile(filePath)
            exit for
        end if
        payloadSize = payload.Count()
        if payloadSize <= 0
            DeleteFile(filePath)
            exit for
        end if
        ' Check packet framing and critical TS header fields on every segment.
        ' The full PSI/clock/continuity inspection remains sampled to bound CPU cost.
        quickAudit = rpTsRelayQuickAuditPayload(payload)
        if quickAudit.aligned and quickAudit.syncErrors = 0 and quickAudit.headerErrors = 0
            fragmentedAudit = rpTsRelayAuditFragmentedHeaders(payload,tsClockState)
            clockAudit = rpTsRelayAuditClocks(payload,tsClockState)
            if fragmentedAudit.pesHeaders > 0 or fragmentedAudit.psiSections > 0 or fragmentedAudit.headerGaps > 0 or fragmentedAudit.headerDuplicates > 0
                print "[RokuPlus ts-audit] fragmented_headers segment="; segmentIndex; " psiSections="; fragmentedAudit.psiSections; " pesHeaders="; fragmentedAudit.pesHeaders; " headerGaps="; fragmentedAudit.headerGaps; " headerDuplicates="; fragmentedAudit.headerDuplicates; " videoPid="; tsClockState.videoPid; " pmtPid="; tsClockState.pmtPid
            end if
            if clockAudit.pcrWraps > 0 or clockAudit.pcrRegressions > 0 or fragmentedAudit.ptsWraps > 0 or fragmentedAudit.dtsWraps > 0 or fragmentedAudit.dtsRegressions > 0
                print "[RokuPlus ts-clock] segment="; segmentIndex; " pcrWraps="; clockAudit.pcrWraps; " pcrRegressions="; clockAudit.pcrRegressions; " ptsWraps="; fragmentedAudit.ptsWraps; " dtsWraps="; fragmentedAudit.dtsWraps; " dtsRegressions="; fragmentedAudit.dtsRegressions
            end if
            boundaryAudit = rpTsRelayAuditContinuity(payload,tsContinuityState)
            if boundaryAudit.errors > 0 or boundaryAudit.duplicates > 0
                print "[RokuPlus ts-audit] continuity segment="; segmentIndex; " checked="; boundaryAudit.checked; " errors="; boundaryAudit.errors; " duplicates="; boundaryAudit.duplicates; " totalErrors="; boundaryAudit.totalErrors; " totalDuplicates="; boundaryAudit.totalDuplicates
            end if
        else
            ' A malformed segment breaks the observation window; do not compare
            ' counters across bytes whose packet boundaries could not be trusted.
            tsContinuityState = {lastCounters:{},haveCounters:{},errors:tsContinuityState.errors,duplicates:tsContinuityState.duplicates,checked:tsContinuityState.checked}
            rpTsRelayResetProgramState(tsClockState)
        end if
        if not quickAudit.aligned or quickAudit.syncErrors > 0 or quickAudit.headerErrors > 0
            print "[RokuPlus ts-audit] structural_warning segment="; segmentIndex; " bytes="; payloadSize; " packets="; quickAudit.packetCount; " aligned="; quickAudit.aligned; " syncErrors="; quickAudit.syncErrors; " headerErrors="; quickAudit.headerErrors; " firstBad="; quickAudit.firstBadOffset
        end if
        auditDue = (sentSegments > 0 and (sentSegments mod 25) = 0) or not quickAudit.aligned or quickAudit.syncErrors > 0 or quickAudit.headerErrors > 0
        if auditDue
            tsAudit = rpTsRelayAuditPayload(payload)
            if not tsAudit.aligned or tsAudit.syncErrors > 0 or tsAudit.patPackets = 0 or tsAudit.continuityErrors > 0
                print "[RokuPlus ts-audit] segment="; segmentIndex; " bytes="; payloadSize; " packets="; tsAudit.packetCount; " aligned="; tsAudit.aligned; " syncErrors="; tsAudit.syncErrors; " firstBad="; tsAudit.firstBadOffset
                print "[RokuPlus ts-audit] pat="; tsAudit.patPackets; " null="; tsAudit.nullPackets; " ccChecked="; tsAudit.continuityChecked; " ccErrors="; tsAudit.continuityErrors; " ccDuplicates="; tsAudit.continuityDuplicates
                print "[RokuPlus ts-audit] pmtPid="; tsAudit.pmtPid; " pmt="; tsAudit.pmtPackets; " videoPid="; tsAudit.videoPid; " h264="; tsAudit.h264; " audioPid="; tsAudit.audioPid; " audioPidCount="; tsAudit.audioPidCount; " audioPids="; tsAudit.audioPidList; " aac="; tsAudit.aac
                print "[RokuPlus ts-audit] idr="; tsAudit.idrCount; " firstIdrPacket="; tsAudit.firstIdrPacket; " sps="; tsAudit.sps; " pps="; tsAudit.pps
                print "[RokuPlus ts-audit] ptsCount="; tsAudit.ptsCount; " firstPts90k="; tsAudit.firstPts; " lastPts90k="; tsAudit.lastPts
                print "[RokuPlus ts-clock] pcrCount="; tsAudit.pcrCount; " pcrErrors="; tsAudit.pcrErrors; " pcrWraps="; tsAudit.pcrWraps; " pcrRegressions="; tsAudit.pcrRegressions; " firstPcr27m="; tsAudit.firstPcr; " lastPcr27m="; tsAudit.lastPcr
                print "[RokuPlus ts-clock] dtsCount="; tsAudit.dtsCount; " dtsWraps="; tsAudit.dtsWraps; " dtsRegressions="; tsAudit.dtsRegressions; " firstDts90k="; tsAudit.firstDts; " lastDts90k="; tsAudit.lastDts
            else if sentSegments mod 25 = 0
                print "[RokuPlus ts-audit] segment="; segmentIndex; " bytes="; payloadSize; " packets="; tsAudit.packetCount; " pat="; tsAudit.patPackets; " null="; tsAudit.nullPackets; " ccChecked="; tsAudit.continuityChecked
                print "[RokuPlus ts-audit] ccErrors="; tsAudit.continuityErrors; " ccDuplicates="; tsAudit.continuityDuplicates; " pmtPid="; tsAudit.pmtPid; " pmt="; tsAudit.pmtPackets; " videoPid="; tsAudit.videoPid; " h264="; tsAudit.h264; " audioPid="; tsAudit.audioPid; " audioPidCount="; tsAudit.audioPidCount; " audioPids="; tsAudit.audioPidList; " aac="; tsAudit.aac
                print "[RokuPlus ts-audit] idr="; tsAudit.idrCount; " firstIdrPacket="; tsAudit.firstIdrPacket; " sps="; tsAudit.sps; " pps="; tsAudit.pps
                print "[RokuPlus ts-audit] ptsCount="; tsAudit.ptsCount; " firstPts90k="; tsAudit.firstPts; " lastPts90k="; tsAudit.lastPts
                print "[RokuPlus ts-clock] pcrCount="; tsAudit.pcrCount; " pcrErrors="; tsAudit.pcrErrors; " pcrWraps="; tsAudit.pcrWraps; " pcrRegressions="; tsAudit.pcrRegressions; " firstPcr27m="; tsAudit.firstPcr; " lastPcr27m="; tsAudit.lastPcr
                print "[RokuPlus ts-clock] dtsCount="; tsAudit.dtsCount; " dtsWraps="; tsAudit.dtsWraps; " dtsRegressions="; tsAudit.dtsRegressions; " firstDts90k="; tsAudit.firstDts; " lastDts90k="; tsAudit.lastDts
            end if
        end if
        if payloadSize <= 0
            DeleteFile(filePath)
            exit for
        end if
        rpTsRelaySendString(connection,rpTsRelayHex(payloadSize)+chr(13)+chr(10),server,connectionPort)
        if not server.sendOk
            DeleteFile(filePath)
            exit for
        end if
        rpTsRelaySendBytes(connection,payload,server,connectionPort)
        if not server.sendOk
            DeleteFile(filePath)
            exit for
        end if
        rpTsRelaySendString(connection,chr(13)+chr(10),server,connectionPort)
        if not server.sendOk
            DeleteFile(filePath)
            exit for
        end if
        sentSegments++
        sentBytes += payloadSize
        server.nextSegmentIndex = segmentIndex + 1
        server.segmentsSent = server.nextSegmentIndex
        if prefetchTask <> invalid
            readyMap = prefetchTask.readyFiles
            if type(readyMap) = "roAssociativeArray" and readyMap.doesExist(segmentIndex.toStr())
                readyMap.delete(segmentIndex.toStr())
                prefetchTask.readyFiles = readyMap
            end if
            prefetchTask.requestIndex = segmentIndex + 1
        end if
        server.bytesSent = server.bytesSent + payloadSize
        if sentSegments = 1 or sentSegments mod 25 = 0
            print "[RokuPlus ts-relay] forwarded segments="; sentSegments; " bytes="; sentBytes
        end if
        DeleteFile(filePath)
    end for
    if server.nextSegmentIndex >= segments.count()
        rpTsRelaySendString(connection,"0"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
        print "[RokuPlus ts-relay] stream_complete segments="; sentSegments; " bytes="; sentBytes
    else
        print "[RokuPlus ts-relay] stream_incomplete segments="; sentSegments; " total="; segments.count()
    end if
    connection.close()
end sub

sub rpTsRelaySendString(connection as object, value as string, server as object, port as object)
    offset = 0
    server.sendOk = true
    progressTimer = CreateObject("roTimespan")
    progressTimer.Mark()
    while offset < len(value)
        if server.stopRequested or server.generation <> server.connectionGeneration or progressTimer.TotalMilliseconds() >= 30000
            reason = "no_progress_timeout"
            if server.stopRequested then reason = "stopped"
            print "[RokuPlus ts-relay] send_abort kind=string offset="; offset; " reason="; reason
            server.sendOk = false
            exit while
        end if
        count = connection.sendStr(mid(value,offset+1))
        if count > 0
            offset += count
            progressTimer.Mark()
        else if count < 0 and (connection.eAgain() or connection.eWouldBlock())
            if not rpTsRelayWaitWritable(connection,port,server)
                print "[RokuPlus ts-relay] send_wait_failed kind=string offset="; offset; " status="; connection.status(); " eConnReset="; connection.eConnReset(); " eConnAborted="; connection.eConnAborted(); " eNotConn="; connection.eNotConn(); " eIsConn="; connection.eIsConn()
                server.sendOk = false
                exit while
            end if
        else
            print "[RokuPlus ts-relay] send_failed kind=string count="; count; " offset="; offset; " status="; connection.status(); " eAgain="; connection.eAgain(); " eWouldBlock="; connection.eWouldBlock(); " eConnReset="; connection.eConnReset(); " eConnAborted="; connection.eConnAborted(); " eNotConn="; connection.eNotConn(); " eIsConn="; connection.eIsConn()
            server.sendOk = false
            exit while
        end if
    end while
end sub

sub rpTsRelaySendBytes(connection as object, value as object, server as object, port as object)
    offset = 0
    total = value.Count()
    chunkLimit = 32768
    server.sendOk = true
    timer = CreateObject("roTimespan")
    timer.Mark()
    progressTimer = CreateObject("roTimespan")
    progressTimer.Mark()
    print "[RokuPlus ts-relay] payload_send_begin bytes="; total; " chunkLimit="; chunkLimit
    while offset < total
        if server.stopRequested or server.generation <> server.connectionGeneration or progressTimer.TotalMilliseconds() >= 30000
            reason = "no_progress_timeout"
            if server.stopRequested then reason = "stopped"
            print "[RokuPlus ts-relay] payload_send_abort bytesSent="; offset; " total="; total; " elapsedMs="; timer.TotalMilliseconds(); " reason="; reason
            server.sendOk = false
            exit while
        end if
        remaining = total - offset
        sendLength = chunkLimit
        if remaining < sendLength then sendLength = remaining
        count = connection.send(value,offset,sendLength)
        if count > 0
            offset = offset + count
            progressTimer.Mark()
            if offset = count
                print "[RokuPlus ts-relay] payload_first_write accepted="; count; " total="; total; " elapsedMs="; timer.TotalMilliseconds()
            end if
        else if count < 0 and (connection.eAgain() or connection.eWouldBlock())
            if not rpTsRelayWaitWritable(connection,port,server)
                print "[RokuPlus ts-relay] send_wait_failed kind=bytes offset="; offset; " requested="; sendLength; " total="; total
                print "[RokuPlus ts-relay] send_wait_failed elapsedMs="; timer.TotalMilliseconds(); " status="; connection.status()
                print "[RokuPlus ts-relay] socket_flags eAgain="; connection.eAgain(); " eWouldBlock="; connection.eWouldBlock(); " eConnReset="; connection.eConnReset()
                print "[RokuPlus ts-relay] socket_flags eConnAborted="; connection.eConnAborted(); " eNotConn="; connection.eNotConn(); " eIsConn="; connection.eIsConn()
                server.sendOk = false
                exit while
            end if
        else
            print "[RokuPlus ts-relay] send_failed kind=bytes count="; count; " offset="; offset; " requested="; sendLength; " total="; total
            print "[RokuPlus ts-relay] send_failed elapsedMs="; timer.TotalMilliseconds(); " status="; connection.status()
            print "[RokuPlus ts-relay] socket_flags eAgain="; connection.eAgain(); " eWouldBlock="; connection.eWouldBlock(); " eConnReset="; connection.eConnReset()
            print "[RokuPlus ts-relay] socket_flags eConnAborted="; connection.eConnAborted(); " eNotConn="; connection.eNotConn(); " eIsConn="; connection.eIsConn()
            server.sendOk = false
            exit while
        end if
    end while
    if server.sendOk
        print "[RokuPlus ts-relay] payload_send_complete bytes="; offset; " elapsedMs="; timer.TotalMilliseconds()
    else
        print "[RokuPlus ts-relay] payload_send_abort bytesSent="; offset; " total="; total; " elapsedMs="; timer.TotalMilliseconds()
    end if
end sub

function rpTsRelayWaitWritable(connection as object, port as object, server as object) as boolean
    ' Wait for the socket's writable notification instead of polling blindly.
    ' A slow decoder can temporarily apply TCP backpressure while consuming a
    ' large TS segment; allow that pause without abandoning a valid connection.
    timer = CreateObject("roTimespan")
    timer.Mark()
    while timer.TotalMilliseconds() < 30000
        if server.stopRequested then return false
        if connection.isException() then return false
        if connection.isWritable() then return true
        event = wait(1000,port)
        if type(event) = "roSocketEvent"
            if event.getSocketID() = connection.getID()
                if connection.isException() then return false
                if connection.isWritable() then return true
            end if
        end if
    end while
    return false
end function

function rpTsRelayHex(value as integer) as string
    digits = "0123456789ABCDEF"
    if value <= 0 then return "0"
    result = ""
    while value > 0
        remainder = value mod 16
        result = mid(digits,remainder+1,1) + result
        value = value \ 16
    end while
    return result
end function

' Fast structural validation for every segment. It does not alter or reject payloads.
' Expensive PSI/PES/clock inspection remains in the sampled deep audit below.
function rpTsRelayQuickAuditPayload(payload as object) as object
    result = {aligned:false,packetCount:0,syncErrors:0,headerErrors:0,firstBadOffset:-1}
    if type(payload) <> "roByteArray" then return result
    total = payload.Count()
    if total <= 0 then return result
    result.aligned = (total mod 188) = 0
    result.packetCount = total \ 188
    for offset = 0 to total - 188 step 188
        if payload[offset] <> &H47
            result.syncErrors++
            if result.firstBadOffset < 0 then result.firstBadOffset = offset
        else
            header = payload[offset+3]
            adaptationControl = (header \ 16) mod 4
            if adaptationControl = 0
                result.headerErrors++
                if result.firstBadOffset < 0 then result.firstBadOffset = offset + 3
            else if adaptationControl = 2 or adaptationControl = 3
                adaptationLength = payload[offset+4]
                maxLength = 183
                if adaptationControl = 3 then maxLength = 182
                if adaptationLength > maxLength or offset + 5 + adaptationLength > offset + 188
                    result.headerErrors++
                    if result.firstBadOffset < 0 then result.firstBadOffset = offset + 4
                end if
            end if
            if payload[offset+1] >= 128
                result.headerErrors++
                if result.firstBadOffset < 0 then result.firstBadOffset = offset + 1
            end if
        end if
    end for
    if not result.aligned and result.firstBadOffset < 0
        result.firstBadOffset = total - (total mod 188)
    end if
    return result
end function

' Read-only MPEG-TS packet audit. The payload is forwarded unchanged.
' PSI inspection is intentionally limited to sections contained in one TS packet.
function rpTsRelayAuditPayload(payload as object) as object
    result = CreateObject("roAssociativeArray")
    result.aligned = false
    result.packetCount = 0
    result.syncErrors = 0
    result.firstBadOffset = -1
    result.patPackets = 0
    result.nullPackets = 0
    result.continuityErrors = 0
    result.continuityChecked = 0
    result.continuityDuplicates = 0
    result.pmtPid = -1
    result.pmtPackets = 0
    result.videoPid = -1
    result.audioPid = -1
    result.audioPidCount = 0
    result.audioPidList = ""
    result.h264 = false
    result.aac = false
    result.idrCount = 0
    result.firstIdrPacket = -1
    result.sps = false
    result.pps = false
    result.ptsCount = 0
    result.firstPts = -1
    result.lastPts = -1
    result.pcrCount = 0
    result.pcrErrors = 0
    result.pcrWraps = 0
    result.pcrRegressions = 0
    result.firstPcr = -1
    result.lastPcr = -1
    result.dtsCount = 0
    result.dtsWraps = 0
    result.dtsRegressions = 0
    result.firstDts = -1
    result.lastDts = -1
    total = payload.Count()
    if total <= 0 then return result
    result.aligned = (total mod 188) = 0
    if not result.aligned
        result.firstBadOffset = total - (total mod 188)
        return result
    end if
    result.packetCount = total \ 188
    lastCounters = {}
    haveCounters = {}
    audioPidSeen = {}
    maxAudioPidList = 8
    lastPcrByPid = {}
    havePcrByPid = {}
    lastDtsByPid = {}
    haveDtsByPid = {}
    for offset = 0 to total - 188 step 188
        if payload[offset] <> &H47
            result.syncErrors++
            if result.firstBadOffset < 0 then result.firstBadOffset = offset
        else
            pid = (payload[offset+1] mod 32) * 256 + payload[offset+2]
            if pid = 0 then result.patPackets++
            if pid = 8191 then result.nullPackets++
            header = payload[offset+3]
            adaptationControl = (header \ 16) mod 4
            continuity = header mod 16
            hasPayload = adaptationControl = 1 or adaptationControl = 3
            discontinuity = false
            if adaptationControl = 2 or adaptationControl = 3
                adaptationLength = payload[offset+4]
                if adaptationLength > 0 and offset + 5 < total
                    adaptationFlags = payload[offset+5]
                    if adaptationFlags >= 128
                        discontinuity = true
                        clockKey = pid.toStr()
                        if havePcrByPid.doesExist(clockKey) then havePcrByPid.Delete(clockKey)
                        if lastPcrByPid.doesExist(clockKey) then lastPcrByPid.Delete(clockKey)
                        if haveDtsByPid.doesExist(clockKey) then haveDtsByPid.Delete(clockKey)
                        if lastDtsByPid.doesExist(clockKey) then lastDtsByPid.Delete(clockKey)
                    end if
                    if (adaptationFlags mod 32) >= 16
                        if adaptationLength >= 7
                            pcrReserved = (payload[offset+10] mod 128) \ 2
                            pcrExtension = (payload[offset+10] mod 2) * 256 + payload[offset+11]
                            if pcrReserved = 63 and pcrExtension <= 299
                                pcrBase = payload[offset+6] * 33554432 + payload[offset+7] * 131072 + payload[offset+8] * 512 + payload[offset+9] * 2 + (payload[offset+10] \ 128)
                                ' Keep PCR in 27 MHz ticks so wrap detection is exact.
                                pcrValue = pcrBase * 300 + pcrExtension
                                clockKey = pid.toStr()
                                if havePcrByPid.doesExist(clockKey)
                                    pcrDelta = pcrValue - lastPcrByPid[clockKey]
                                    if pcrDelta < 0
                                        if (lastPcrByPid[clockKey] - pcrValue) > 1288490188800
                                            result.pcrWraps++
                                        else
                                            result.pcrRegressions++
                                        end if
                                    end if
                                end if
                                if result.pcrCount = 0 then result.firstPcr = pcrValue
                                result.lastPcr = pcrValue
                                lastPcrByPid[clockKey] = pcrValue
                                havePcrByPid[clockKey] = true
                                result.pcrCount++
                            else
                                result.pcrErrors++
                            end if
                        else
                            result.pcrErrors++
                        end if
                    end if
                end if
            end if
            key = pid.toStr()
            if discontinuity and pid <> 8191 and haveCounters.doesExist(key)
                ' A discontinuity indicator resets the PID baseline even on
                ' adaptation-only packets, which do not carry payload bytes.
                haveCounters.Delete(key)
                lastCounters.Delete(key)
            end if
            if hasPayload and pid <> 8191
                key = pid.toStr()
                if haveCounters[key] = true
                    result.continuityChecked++
                    expected = (lastCounters[key] + 1) mod 16
                    if discontinuity
                        ' A declared discontinuity starts a new continuity baseline.
                    else if continuity = lastCounters[key]
                        ' A repeated payload continuity counter is a duplicate candidate,
                        ' not a missing packet. This audit does not byte-compare retransmits.
                        result.continuityDuplicates++
                    else if continuity <> expected
                        result.continuityErrors++
                    end if
                end if
                lastCounters[key] = continuity
                haveCounters[key] = true
            end if
            if hasPayload
                payloadStart = offset + 4
                if adaptationControl = 3
                    payloadStart = offset + 5 + payload[offset+4]
                end if
                if payloadStart < offset + 188 and payloadStart < total
                    ' PSI pointer_field is valid only when PUSI marks a new section.
                    if payload[offset+1] >= 64 and payload[offset+1] < 128
                        pointer = payload[payloadStart]
                        if pointer <= offset + 187 - payloadStart
                            sectionStart = payloadStart + 1 + pointer
                            if pid = 0
                                if sectionStart + 12 <= offset + 188
                                    if payload[sectionStart] = 0
                                        sectionLength = (payload[sectionStart+1] mod 16) * 256 + payload[sectionStart+2]
                                        sectionEnd = sectionStart + 3 + sectionLength
                                        if sectionLength >= 9 and sectionLength <= 1021 and sectionEnd <= offset + 188
                                            entry = sectionStart + 8
                                            while entry + 4 <= sectionEnd - 4
                                                programNumber = payload[entry] * 256 + payload[entry+1]
                                                if programNumber > 0
                                                    result.pmtPid = (payload[entry+2] mod 32) * 256 + payload[entry+3]
                                                    exit while
                                                end if
                                                entry += 4
                                            end while
                                        end if
                                    end if
                                end if
                            else if pid = result.pmtPid
                                if sectionStart + 12 <= offset + 188
                                    if payload[sectionStart] = 2
                                        sectionLength = (payload[sectionStart+1] mod 16) * 256 + payload[sectionStart+2]
                                        sectionEnd = sectionStart + 3 + sectionLength
                                        if sectionLength >= 13 and sectionLength <= 1021 and sectionEnd <= offset + 188
                                            result.pmtPackets++
                                            programInfoLength = (payload[sectionStart+10] mod 16) * 256 + payload[sectionStart+11]
                                            entry = sectionStart + 12 + programInfoLength
                                            if entry <= sectionEnd - 4
                                                while entry + 5 <= sectionEnd - 4
                                                    streamType = payload[entry]
                                                    elementaryPid = (payload[entry+1] mod 32) * 256 + payload[entry+2]
                                                    esInfoLength = (payload[entry+3] mod 16) * 256 + payload[entry+4]
                                                    if entry + 5 + esInfoLength > sectionEnd - 4 then exit while
                                                    if streamType = 27
                                                        result.h264 = true
                                                        result.videoPid = elementaryPid
                                                    else if streamType = 15 or streamType = 17
                                                        result.aac = true
                                                        if result.audioPid < 0 then result.audioPid = elementaryPid
                                                        audioKey = elementaryPid.toStr()
                                                        if not audioPidSeen.doesExist(audioKey)
                                                            audioPidSeen[audioKey] = true
                                                            result.audioPidCount++
                                                            if result.audioPidCount <= maxAudioPidList
                                                                if result.audioPidList <> "" then result.audioPidList += ","
                                                                result.audioPidList += audioKey
                                                            end if
                                                        end if
                                                    end if
                                                    entry += 5 + esInfoLength
                                                end while
                                            end if
                                        end if
                                    end if
                                end if
                            end if
                        end if
                    end if
                end if
                if pid = result.videoPid and result.videoPid >= 0
                    dataStart = payloadStart
                    if payload[offset+1] >= 64 and payload[offset+1] < 128
                        if payloadStart + 9 < offset + 188
                            if payload[payloadStart] = 0 and payload[payloadStart+1] = 0 and payload[payloadStart+2] = 1
                                pesFlags = (payload[payloadStart+7] \ 64) mod 4
                                pesHeaderLength = payload[payloadStart+8]
                                pesHeaderEnd = payloadStart + 9 + pesHeaderLength
                                ' This audit only parses PES optional headers contained in this TS packet.
                                if pesHeaderEnd <= offset + 188
                                    if pesFlags = 2 and pesHeaderLength >= 5 and payloadStart + 14 <= pesHeaderEnd
                                        pts = rpTsRelayReadPts(payload,payloadStart+9,2)
                                        if pts >= 0
                                            if result.ptsCount = 0 then result.firstPts = pts
                                            result.lastPts = pts
                                            result.ptsCount++
                                        end if
                                    else if pesFlags = 3 and pesHeaderLength >= 10 and payloadStart + 19 <= pesHeaderEnd
                                        pts = rpTsRelayReadPts(payload,payloadStart+9,3)
                                        if pts >= 0
                                            if result.ptsCount = 0 then result.firstPts = pts
                                            result.lastPts = pts
                                            result.ptsCount++
                                        end if
                                        dts = rpTsRelayReadPts(payload,payloadStart+14,1)
                                        if dts >= 0
                                            clockKey = pid.toStr()
                                            if haveDtsByPid.doesExist(clockKey)
                                                dtsDelta = dts - lastDtsByPid[clockKey]
                                                if dtsDelta < 0
                                                    if (lastDtsByPid[clockKey] - dts) > 4294967296
                                                        result.dtsWraps++
                                                    else
                                                        result.dtsRegressions++
                                                    end if
                                                end if
                                            end if
                                            if result.dtsCount = 0 then result.firstDts = dts
                                            result.lastDts = dts
                                            lastDtsByPid[clockKey] = dts
                                            haveDtsByPid[clockKey] = true
                                            result.dtsCount++
                                        end if
                                    end if
                                    dataStart = pesHeaderEnd
                                else
                                    dataStart = offset + 188
                                end if
                            end if
                        end if
                    end if
                    ' A four-byte start code plus NAL header must fit inside this TS packet.
                    ' Keep the scan bounded to the packet and the actual byte-array length.
                    nalEnd = offset + 183
                    if nalEnd > total - 5 then nalEnd = total - 5
                    if dataStart <= nalEnd and dataStart < offset + 188
                        for nalOffset = dataStart to nalEnd
                            if payload[nalOffset] = 0 and payload[nalOffset+1] = 0
                                nalType = -1
                                if payload[nalOffset+2] = 1
                                    nalType = payload[nalOffset+3] mod 32
                                else if payload[nalOffset+2] = 0 and payload[nalOffset+3] = 1
                                    nalType = payload[nalOffset+4] mod 32
                                end if
                                if nalType = 5
                                    result.idrCount++
                                    if result.firstIdrPacket < 0 then result.firstIdrPacket = offset \ 188
                                else if nalType = 7
                                    result.sps = true
                                else if nalType = 8
                                    result.pps = true
                                end if
                            end if
                        end for
                    end if
                end if
            end if
        end if
    end for
    return result
end function

' Tracks payload continuity counters across segment boundaries. This scan is
' deliberately lightweight and read-only; it never changes or filters stream bytes.
' Scan PCR and PES clocks on every segment while carrying PID baselines across
' segment boundaries. This is diagnostic only and never alters the payload.
function rpTsRelayAuditClocks(payload as object, state as object) as object
    result = {pcrWraps:0,pcrRegressions:0}
    if type(payload) <> "roByteArray" or type(state) <> "roAssociativeArray" then return result
    total = payload.Count()
    if total <= 0 or (total mod 188) <> 0 then return result
    for offset = 0 to total - 188 step 188
        if payload[offset] = &H47
            pid = (payload[offset+1] mod 32) * 256 + payload[offset+2]
            header = payload[offset+3]
            adaptationControl = (header \\ 16) mod 4
            if adaptationControl = 2 or adaptationControl = 3
                adaptationLength = payload[offset+4]
                if adaptationLength > 0 and adaptationLength <= 183 and offset + 5 + adaptationLength <= offset + 188
                    adaptationFlags = payload[offset+5]
                    key = pid.toStr()
                    discontinuity = adaptationFlags >= 128
                    if discontinuity
                        if state.havePcr.doesExist(key) then state.havePcr.Delete(key)
                        if state.lastPcr.doesExist(key) then state.lastPcr.Delete(key)
                    end if
                    if state.pcrPid >= 16 and state.pcrPid <= 8190 and pid = state.pcrPid and (adaptationFlags mod 32) >= 16 and adaptationLength >= 7
                        pcrReserved = (payload[offset+10] mod 128) \\ 2
                        pcrExtension = (payload[offset+10] mod 2) * 256 + payload[offset+11]
                        if pcrReserved = 63 and pcrExtension <= 299
                            pcrBase = payload[offset+6] * 33554432 + payload[offset+7] * 131072 + payload[offset+8] * 512 + payload[offset+9] * 2 + (payload[offset+10] \\ 128)
                            pcrValue = pcrBase * 300 + pcrExtension
                            if not discontinuity and state.havePcr.doesExist(key)
                                if state.lastPcr[key] - pcrValue > 1288490188800
                                    result.pcrWraps++
                                    state.pcrWraps++
                                else if pcrValue < state.lastPcr[key]
                                    result.pcrRegressions++
                                    state.pcrRegressions++
                                end if
                            end if
                            state.lastPcr[key] = pcrValue
                            state.havePcr[key] = true
                        end if
                    end if
                end if
            end if
        end if
    end for
    return result
end function

' Assemble PSI sections and PES timestamp headers across TS packet boundaries.
' This is a read-only diagnostic pass; it never changes or drops stream bytes.
' Clear PSI byte/table assembly for one PID. Keep version ordering after a
' continuity gap; forget it only after an explicit transport discontinuity.
sub rpTsRelayResetPsiPidState(state as object, pid as integer, clearVersions as boolean)
    key = pid.toStr()
    if type(state.psiBuffers) = "roAssociativeArray" and state.psiBuffers.doesExist(key)
        state.psiBuffers.Delete(key)
    end if
    tablePrefix = key + ":"
    staleTables = []
    if type(state.psiTables) = "roAssociativeArray"
        for tableKey in state.psiTables
            if left(tableKey,len(tablePrefix)) = tablePrefix then staleTables.push(tableKey)
        end for
        for tableKey in staleTables
            state.psiTables.Delete(tableKey)
        end for
    end if
    if clearVersions
        staleVersions = []
        if type(state.psiActiveVersions) = "roAssociativeArray"
            for versionKey in state.psiActiveVersions
                if left(versionKey,len(tablePrefix)) = tablePrefix then staleVersions.push(versionKey)
            end for
            for versionKey in staleVersions
                state.psiActiveVersions.Delete(versionKey)
            end for
        end if
    end if
end sub

function rpTsRelayAuditFragmentedHeaders(payload as object, state as object) as object
    result = {psiSections:0,pesHeaders:0,ptsWraps:0,dtsWraps:0,dtsRegressions:0,headerGaps:0,headerDuplicates:0}
    if type(payload) <> "roByteArray" or type(state) <> "roAssociativeArray" then return result
    total = payload.Count()
    if total <= 0 or (total mod 188) <> 0 then return result
    for offset = 0 to total - 188 step 188
        if payload[offset] = &H47
            pid = (payload[offset+1] mod 32) * 256 + payload[offset+2]
            header = payload[offset+3]
            adaptationControl = (header \\ 16) mod 4
            discontinuity = false
            if adaptationControl = 2 or adaptationControl = 3
                adaptationLength = payload[offset+4]
                if adaptationLength > 0 and adaptationLength <= 183 and offset + 5 + adaptationLength <= offset + 188
                    if payload[offset+5] >= 128
                        discontinuity = true
                        key = pid.toStr()
                        rpTsRelayResetPsiPidState(state,pid,true)
                        if state.pesBuffers.doesExist(key) then state.pesBuffers.Delete(key)
                        if state.headerHaveCounters.doesExist(key) then state.headerHaveCounters.Delete(key)
                        if state.headerLastCounters.doesExist(key) then state.headerLastCounters.Delete(key)
                        if state.havePcr.doesExist(key) then state.havePcr.Delete(key)
                        if state.lastPcr.doesExist(key) then state.lastPcr.Delete(key)
                        if state.haveDts.doesExist(key) then state.haveDts.Delete(key)
                        if state.lastDts.doesExist(key) then state.lastDts.Delete(key)
                        if state.havePts.doesExist(key) then state.havePts.Delete(key)
                        if state.lastPts.doesExist(key) then state.lastPts.Delete(key)
                    end if
                end if
            end if
            hasPayload = adaptationControl = 1 or adaptationControl = 3
            skipPayload = false
            key = pid.toStr()
            if hasPayload and pid <> 8191
                if state.headerHaveCounters.doesExist(key)
                    previousCounter = state.headerLastCounters[key]
                    if not discontinuity and (header mod 16) = previousCounter
                        skipPayload = true
                        result.headerDuplicates++
                    else if not discontinuity and (header mod 16) <> ((previousCounter + 1) mod 16)
                        result.headerGaps++
                        rpTsRelayResetPsiPidState(state,pid,false)
                        if state.pesBuffers.doesExist(key) then state.pesBuffers.Delete(key)
                    end if
                end if
                state.headerLastCounters[key] = header mod 16
                state.headerHaveCounters[key] = true
            end if
            if hasPayload and not skipPayload
                payloadStart = offset + 4
                if adaptationControl = 3
                    adaptationLength = payload[offset+4]
                    if adaptationLength > 183 or offset + 5 + adaptationLength > offset + 188
                        payloadStart = offset + 188
                    else
                        payloadStart = offset + 5 + adaptationLength
                    end if
                end if
                if payloadStart < offset + 188
                    payloadUnitStart = payload[offset+1] >= 64 and payload[offset+1] < 128
                    key = pid.toStr()
                    if pid = 0 or (state.pmtPid >= 0 and pid = state.pmtPid)
                        if payloadUnitStart
                            pointer = payload[payloadStart]
                            if pointer <= offset + 187 - payloadStart
                                if state.psiBuffers.doesExist(key) and pointer > 0
                                    rpTsRelayPsiFeed(state,pid,payload,payloadStart+1,payloadStart+pointer)
                                end if
                                state.psiBuffers[key] = []
                                sectionStart = payloadStart + 1 + pointer
                                if sectionStart < offset + 188
                                    result.psiSections += rpTsRelayPsiFeed(state,pid,payload,sectionStart,offset+188)
                                end if
                            else
                                if state.psiBuffers.doesExist(key) then state.psiBuffers.Delete(key)
                            end if
                        else if state.psiBuffers.doesExist(key)
                            result.psiSections += rpTsRelayPsiFeed(state,pid,payload,payloadStart,offset+188)
                        end if
                    end if
                    if state.videoPid >= 0 and pid = state.videoPid
                        if payloadUnitStart
                            state.pesBuffers[key] = []
                        end if
                        if state.pesBuffers.doesExist(key)
                            pesBuffer = state.pesBuffers[key]
                            for byteIndex = payloadStart to offset + 187
                                if pesBuffer.count() < 19 then pesBuffer.push(payload[byteIndex])
                            end for
                            state.pesBuffers[key] = pesBuffer
                            if pesBuffer.count() >= 9
                                headerComplete = true
                                if pesBuffer[0] = 0 and pesBuffer[1] = 0 and pesBuffer[2] = 1
                                    pesFlags = (pesBuffer[7] \\ 64) mod 4
                                    pesHeaderLength = pesBuffer[8]
                                    requiredBytes = 9
                                    if pesFlags = 2 and pesHeaderLength >= 5
                                        requiredBytes = 14
                                    else if pesFlags = 3 and pesHeaderLength >= 10
                                        requiredBytes = 19
                                    end if
                                    if requiredBytes > 9 and pesBuffer.count() < requiredBytes
                                        headerComplete = false
                                    else if requiredBytes > 9
                                        ptsPrefix = 2
                                        if pesFlags = 3 then ptsPrefix = 3
                                        pts = rpTsRelayReadPtsArray(pesBuffer,9,ptsPrefix)
                                        if pts >= 0
                                            if state.havePts.doesExist(key)
                                                if state.lastPts[key] - pts > 4294967296
                                                    state.ptsWraps++
                                                    result.ptsWraps++
                                                end if
                                            end if
                                            state.lastPts[key] = pts
                                            state.havePts[key] = true
                                        end if
                                        if pesFlags = 3
                                            dts = rpTsRelayReadPtsArray(pesBuffer,14,1)
                                            if dts >= 0
                                                if state.haveDts.doesExist(key)
                                                    if state.lastDts[key] - dts > 4294967296
                                                        state.dtsWraps++
                                                        result.dtsWraps++
                                                    else if dts < state.lastDts[key]
                                                        state.dtsRegressions++
                                                        result.dtsRegressions++
                                                    end if
                                                end if
                                                state.lastDts[key] = dts
                                                state.haveDts[key] = true
                                            end if
                                        end if
                                        result.pesHeaders++
                                    end if
                                else
                                    headerComplete = true
                                end if
                                if headerComplete then state.pesBuffers.Delete(key)
                            end if
                        end if
                    end if
                end if
            end if
        end if
    end for
    return result
end function

' Feed PSI bytes into a bounded per-PID section buffer and parse complete PAT/PMT sections.
function rpTsRelayPsiFeed(state as object, pid as integer, payload as object, first as integer, afterLast as integer) as integer
    if first < 0 or afterLast <= first then return 0
    if afterLast > payload.Count() then return 0
    key = pid.toStr()
    buffer = []
    if state.psiBuffers.doesExist(key) then buffer = state.psiBuffers[key]
    parsed = 0
    for i = first to afterLast - 1
        value = payload[i]
        if buffer.count() = 0 and value = 255 then
            ' PSI stuffing bytes are not the beginning of another section.
        else
            if buffer.count() < 1024 then buffer.push(value)
        end if
        keepReading = true
        while keepReading and buffer.count() >= 3
            sectionLength = (buffer[1] mod 16) * 256 + buffer[2]
            sectionTotal = 3 + sectionLength
            if sectionLength < 9 or sectionLength > 1021
                buffer = []
                keepReading = false
            else if buffer.count() < sectionTotal
                keepReading = false
            else
                section = []
                for sectionIndex = 0 to sectionTotal - 1
                    section.push(buffer[sectionIndex])
                end for
                rpTsRelayParsePsiSection(state,pid,section)
                parsed++
                remainder = []
                for remainderIndex = sectionTotal to buffer.count() - 1
                    remainder.push(buffer[remainderIndex])
                end for
                buffer = remainder
            end if
        end while
    end for
    state.psiBuffers[key] = buffer
    return parsed
end function

' MPEG-2 PSI CRC-32: polynomial 0x04C11DB7, initial value 0xFFFFFFFF,
' no reflection and no final XOR. A valid complete section has remainder zero.
function rpTsRelayCrcXor(leftValue as dynamic, rightValue as dynamic) as dynamic
    result = 0
    place = 1
    a = leftValue
    b = rightValue
    for bitIndex = 0 to 31
        aBit = a mod 2
        bBit = b mod 2
        if aBit <> bBit then result = result + place
        a = a \ 2
        b = b \ 2
        place = place * 2
    end for
    return result
end function

function rpTsRelayPsiCrcValid(section as object) as boolean
    if type(section) <> "roArray" then return false
    total = section.count()
    if total < 12 or total > 1024 then return false
    crc = 4294967295
    for byteIndex = 0 to total - 1
        crc = rpTsRelayCrcXor(crc,section[byteIndex] * 16777216)
        for bitIndex = 0 to 7
            if crc >= 2147483648
                shifted = (crc * 2) mod 4294967296
                crc = rpTsRelayCrcXor(shifted,79764919)
            else
                crc = (crc * 2) mod 4294967296
            end if
        end for
    end for
    return crc = 0
end function

sub rpTsRelayParsePsiSection(state as object, pid as integer, section as object)
    total = section.count()
    if total < 12 or total > 1024 then return
    sectionLength = (section[1] mod 16) * 256 + section[2]
    if sectionLength + 3 <> total then return
    if sectionLength < 9 or sectionLength > 1021 then return
    if (section[1] \\ 16) <> 11 then return
    if (section[5] \\ 64) <> 3 then return
    if section[5] mod 2 <> 1 then return
    if not rpTsRelayPsiCrcValid(section) then return
    sectionNumber = section[6]
    lastSectionNumber = section[7]
    if sectionNumber > lastSectionNumber then return
    if pid = 0 and section[0] = 0
        tableKind = "pat"
    else if pid = state.pmtPid and section[0] = 2
        tableKind = "pmt"
    else
        return
    end if
    tableExtension = section[3] * 256 + section[4]
    if tableKind = "pmt"
        if state.programNumber < 0 or tableExtension <> state.programNumber then return
    end if
    versionNumber = (section[5] \\ 2) mod 32
    tableIdentity = pid.toStr() + ":" + tableKind + ":" + tableExtension.toStr()
    tablePrefix = tableIdentity + ":"
    activeVersions = state.psiActiveVersions
    if type(activeVersions) <> "roAssociativeArray" then activeVersions = {}
    tableKey = tablePrefix + versionNumber.toStr()
    if activeVersions.doesExist(tableIdentity)
        activeVersion = activeVersions[tableIdentity]
        versionDelta = (versionNumber - activeVersion + 32) mod 32
        ' Compare against the last successfully applied version, not a pending one.
        ' This keeps the current table usable while a newer version is incomplete.
        if versionDelta >= 16 then return
        if versionDelta > 0
            staleKeys = []
            for existingKey in state.psiTables
                if left(existingKey,len(tablePrefix)) = tablePrefix and existingKey <> tableKey and existingKey <> tablePrefix + activeVersion.toStr()
                    staleKeys.push(existingKey)
                end if
            end for
            for staleKey in staleKeys
                state.psiTables.Delete(staleKey)
            end for
        end if
    else if tableKind = "pat" and not state.psiTables.doesExist(tableKey)
        ' No PAT version is active yet for this transport_stream_id. Remove
        ' partial assemblies from older transport IDs only once a new candidate
        ' starts; the previous applied program state remains untouched.
        patPrefix = pid.toStr() + ":pat:"
        stalePatTables = []
        for existingKey in state.psiTables
            if left(existingKey,len(patPrefix)) = patPrefix then stalePatTables.push(existingKey)
        end for
        for staleKey in stalePatTables
            state.psiTables.Delete(staleKey)
        end for
    end if
    tableKey = tablePrefix + versionNumber.toStr()
    if not state.psiTables.doesExist(tableKey)
        sections = []
        while sections.count() <= lastSectionNumber
            sections.push(invalid)
        end while
        state.psiTables[tableKey] = {lastSection:lastSectionNumber,sections:sections}
    end if
    tableState = state.psiTables[tableKey]
    ' A retransmission may expose a previously incomplete/corrupt accumulator
    ' with a conflicting last_section_number. Discard that partial assembly and
    ' restart from this CRC-valid section instead of wedging this version forever.
    if tableState.lastSection <> lastSectionNumber
        print "[RokuPlus ts-audit] psi_table_restart pid="; pid; " kind="; tableKind; " version="; versionNumber; " oldLast="; tableState.lastSection; " newLast="; lastSectionNumber
        sections = []
        while sections.count() <= lastSectionNumber
            sections.push(invalid)
        end while
        tableState = {lastSection:lastSectionNumber,sections:sections}
    end if
    sections = tableState.sections
    sections[sectionNumber] = section
    tableState.sections = sections
    state.psiTables[tableKey] = tableState
    complete = true
    for index = 0 to tableState.lastSection
        if tableState.sections[index] = invalid then complete = false
    end for
    if complete
        applied = false
        if tableKind = "pat"
            applied = rpTsRelayApplyPatSections(state,tableState.sections)
        else
            applied = rpTsRelayApplyPmtSections(state,tableState.sections)
        end if
        if applied
            activeVersions[tableIdentity] = versionNumber
            state.psiActiveVersions = activeVersions
            ' A PAT transport ID becomes active only after its complete table
            ' has passed semantic validation and its program selection applied.
            if tableKind = "pat"
                patPrefix = pid.toStr() + ":pat:"
                stalePatTables = []
                for existingKey in state.psiTables
                    if left(existingKey,len(patPrefix)) = patPrefix and existingKey <> tableKey
                        stalePatTables.push(existingKey)
                    end if
                end for
                for staleKey in stalePatTables
                    state.psiTables.Delete(staleKey)
                end for
                stalePatVersions = []
                for existingKey in activeVersions
                    if left(existingKey,len(patPrefix)) = patPrefix and existingKey <> tableIdentity
                        stalePatVersions.push(existingKey)
                    end if
                end for
                for staleKey in stalePatVersions
                    activeVersions.Delete(staleKey)
                end for
                state.psiActiveVersions = activeVersions
            end if
            ' Retain the applied version and discard superseded partial assemblies.
            staleKeys = []
            for existingKey in state.psiTables
                if left(existingKey,len(tablePrefix)) = tablePrefix and existingKey <> tableKey
                    staleKeys.push(existingKey)
                end if
            end for
            for staleKey in staleKeys
                state.psiTables.Delete(staleKey)
            end for
            print "[RokuPlus ts-audit] psi_table_applied pid="; pid; " kind="; tableKind; " version="; versionNumber
        else
            ' Invalid complete candidate: keep the previous applied version/state
            ' and allow a later retransmission of this version to rebuild it.
            if state.psiTables.doesExist(tableKey) then state.psiTables.Delete(tableKey)
            print "[RokuPlus ts-audit] psi_table_rejected pid="; pid; " kind="; tableKind; " version="; versionNumber
        end if
    end if
end sub

function rpTsRelayApplyPatSections(state as object, sections as object) as boolean
    selectedPmtPid = -1
    selectedProgramNumber = -1
    programPids = {}
    for section in sections
        total = section.count()
        if total < 12 then return false
        if ((total - 12) mod 4) <> 0 then return false
        entry = 8
        while entry + 4 <= total - 4
            programNumber = section[entry] * 256 + section[entry+1]
            if (section[entry+2] \\ 32) <> 7 then return false
            pmtPid = (section[entry+2] mod 32) * 256 + section[entry+3]
            if programNumber > 0
                ' PMT PIDs must be in the usable elementary/program range.
                if pmtPid < 16 or pmtPid > 8190 then return false
                programKey = programNumber.toStr()
                if programPids.doesExist(programKey)
                    if programPids[programKey] <> pmtPid then return false
                else
                    programPids[programKey] = pmtPid
                end if
                ' Select deterministically across all PAT sections, rather than
                ' whichever program happens to appear first in section order.
                if selectedProgramNumber < 0 or programNumber < selectedProgramNumber
                    selectedProgramNumber = programNumber
                    selectedPmtPid = pmtPid
                end if
            end if
            entry += 4
        end while
    end for
    previousPmtPid = state.pmtPid
    previousProgramNumber = state.programNumber
    state.pmtPid = selectedPmtPid
    state.programNumber = selectedProgramNumber
    if previousPmtPid <> selectedPmtPid or previousProgramNumber <> selectedProgramNumber
        if previousPmtPid >= 0
            oldPmtKey = previousPmtPid.toStr()
            if state.psiBuffers.doesExist(oldPmtKey) then state.psiBuffers.Delete(oldPmtKey)
            staleKeys = []
            oldTablePrefix = oldPmtKey + ":pmt:"
            for existingKey in state.psiTables
                if left(existingKey,len(oldTablePrefix)) = oldTablePrefix then staleKeys.push(existingKey)
            end for
            for staleKey in staleKeys
                state.psiTables.Delete(staleKey)
            end for
            rpTsRelayClearPmtVersionState(state,previousPmtPid)
        end if
        if selectedPmtPid >= 0
            newPmtKey = selectedPmtPid.toStr()
            if state.psiBuffers.doesExist(newPmtKey) then state.psiBuffers.Delete(newPmtKey)
            staleKeys = []
            newTablePrefix = newPmtKey + ":pmt:"
            for existingKey in state.psiTables
                if left(existingKey,len(newTablePrefix)) = newTablePrefix then staleKeys.push(existingKey)
            end for
            for staleKey in staleKeys
                state.psiTables.Delete(staleKey)
            end for
            rpTsRelayClearPmtVersionState(state,selectedPmtPid)
        end if
        state.pcrPid = -1
        state.pmtSignature = ""
        state.videoPid = -1
        state.audioPids = []
        rpTsRelayResetPesClockState(state)
        print "[RokuPlus ts-audit] pat_program_changed pmtOld="; previousPmtPid; " pmtNew="; selectedPmtPid; " programOld="; previousProgramNumber; " programNew="; selectedProgramNumber; " elementary_state_reset=true"
    end if
    return true
end function

' Forget PMT version ordering when its PID is reassigned or selected again.
sub rpTsRelayClearPmtVersionState(state as object, pid as integer)
    if pid < 0 then return
    prefix = pid.toStr() + ":pmt:"
    keys = []
    for activeKey in state.psiActiveVersions
        if left(activeKey,len(prefix)) = prefix then keys.push(activeKey)
    end for
    for activeKey in keys
        state.psiActiveVersions.Delete(activeKey)
    end for
end sub

' Reset program/clock parser state at HLS discontinuities and malformed segment boundaries.
' The next valid PAT and PMT must establish fresh table and elementary PID identities.
sub rpTsRelayResetProgramState(state as object)
    state.lastPcr = {}
    state.havePcr = {}
    state.lastDts = {}
    state.haveDts = {}
    state.lastPts = {}
    state.havePts = {}
    state.psiBuffers = {}
    state.psiTables = {}
    state.psiActiveVersions = {}
    state.pesBuffers = {}
    state.headerLastCounters = {}
    state.headerHaveCounters = {}
    state.pmtPid = -1
    state.programNumber = -1
    state.pcrPid = -1
    state.pmtSignature = ""
    state.videoPid = -1
    state.audioPids = []
end sub

' Clear fragmented PES and timestamp baselines whenever the PMT changes stream PID assignments.
sub rpTsRelayResetPesClockState(state as object)
    state.pesBuffers = {}
    state.havePts = {}
    state.lastPts = {}
    state.haveDts = {}
    state.lastDts = {}
end sub

function rpTsRelayPidArraysEqual(leftPids as object, rightPids as object) as boolean
    if type(leftPids) <> "roArray" or type(rightPids) <> "roArray" then return false
    if leftPids.count() <> rightPids.count() then return false
    for index = 0 to leftPids.count() - 1
        if leftPids[index] <> rightPids[index] then return false
    end for
    return true
end function

' Fingerprint the complete validated PMT content while excluding version_number
' and CRC bytes. Descriptor, stream-type, PCR, or program-info changes are detected
' even when elementary PID assignments remain unchanged.
function rpTsRelayPmtContentSignature(sections as object) as string
    if type(sections) <> "roArray" or sections.count() = 0 then return ""
    hashA = 7
    hashB = 19
    byteCount = 0
    for section in sections
        if type(section) <> "roArray" then return ""
        total = section.count()
        if total < 16 or total > 1024 then return ""
        for index = 0 to total - 5
            if index <> 5
                value = section[index]
                hashA = (hashA * 31 + value + 1) mod 2147483629
                hashB = (hashB * 131 + value + 1) mod 2147483587
                byteCount++
            end if
        end for
    end for
    return byteCount.toStr() + ":" + hashA.toStr() + ":" + hashB.toStr()
end function

' Validate a descriptor loop without reading beyond its declared bounds.
function rpTsRelayDescriptorLoopValid(section as object, first as integer, length as integer) as boolean
    if type(section) <> "roArray" or first < 0 or length < 0 then return false
    finish = first + length
    if finish > section.count() then return false
    cursor = first
    while cursor < finish
        if cursor + 2 > finish then return false
        descriptorLength = section[cursor+1]
        cursor += 2
        if cursor + descriptorLength > finish then return false
        cursor += descriptorLength
    end while
    return cursor = finish
end function

function rpTsRelayApplyPmtSections(state as object, sections as object) as boolean
    pmtSignature = rpTsRelayPmtContentSignature(sections)
    if pmtSignature = "" then return false
    selectedVideoPid = -1
    selectedPcrPid = -1
    selectedAudioPids = []
    selectedAudioSeen = {}
    selectedStreamTypes = {}
    programInfoSignature = invalid
    for section in sections
        total = section.count()
        if total < 16 then return false
        if (section[8] \ 32) <> 7 then return false
        sectionPcrPid = (section[8] mod 32) * 256 + section[9]
        if sectionPcrPid <> 8191 and (sectionPcrPid < 16 or sectionPcrPid > 8190) then return false
        if selectedPcrPid < 0
            selectedPcrPid = sectionPcrPid
        else if selectedPcrPid <> sectionPcrPid
            return false
        end if
        if (section[10] \\ 16) <> 15 then return false
        programInfoLength = (section[10] mod 16) * 256 + section[11]
        entry = 12 + programInfoLength
        if entry > total - 4 then return false
        if not rpTsRelayDescriptorLoopValid(section,12,programInfoLength) then return false
        currentProgramInfo = ""
        for descriptorIndex = 12 to entry - 1
            currentProgramInfo = currentProgramInfo + section[descriptorIndex].toStr() + ","
        end for
        if programInfoSignature = invalid
            programInfoSignature = currentProgramInfo
        else if programInfoSignature <> currentProgramInfo
            ' Program-level descriptors must agree across all PMT sections.
            return false
        end if
        while entry + 5 <= total - 4
            streamType = section[entry]
            if (section[entry+1] \\ 32) <> 7 then return false
            if (section[entry+3] \\ 16) <> 15 then return false
            elementaryPid = (section[entry+1] mod 32) * 256 + section[entry+2]
            esInfoLength = (section[entry+3] mod 16) * 256 + section[entry+4]
            if elementaryPid < 16 or elementaryPid > 8190 then return false
            if entry + 5 + esInfoLength > total - 4 then return false
            if not rpTsRelayDescriptorLoopValid(section,entry+5,esInfoLength) then return false
            streamKey = elementaryPid.toStr()
            ' An elementary PID may appear only once in the complete PMT.
            if selectedStreamTypes.doesExist(streamKey) then return false
            selectedStreamTypes[streamKey] = streamType
            if streamType = 27
                ' The relay clock inspector tracks one H.264 PID. Choose it
                ' deterministically if a PMT advertises multiple video streams.
                if selectedVideoPid < 0 or elementaryPid < selectedVideoPid
                    selectedVideoPid = elementaryPid
                end if
            else if streamType = 3 or streamType = 4 or streamType = 15 or streamType = 17 or streamType = 129 or streamType = 135
                if not selectedAudioSeen.doesExist(streamKey)
                    selectedAudioSeen[streamKey] = true
                    selectedAudioPids.push(elementaryPid)
                end if
            end if
            entry += 5 + esInfoLength
        end while
        if entry <> total - 4 then return false
    end for
    ' Stable ordering prevents a reordered multi-section PMT from looking like
    ' a changed audio PID set and unnecessarily clearing clock/PES baselines.
    for i = 0 to selectedAudioPids.count() - 2
        for j = i + 1 to selectedAudioPids.count() - 1
            if selectedAudioPids[j] < selectedAudioPids[i]
                swapPid = selectedAudioPids[i]
                selectedAudioPids[i] = selectedAudioPids[j]
                selectedAudioPids[j] = swapPid
            end if
        end for
    end for
    previousVideoPid = state.videoPid
    previousPcrPid = state.pcrPid
    previousAudioPids = state.audioPids
    if type(previousAudioPids) <> "roArray" then previousAudioPids = []
    audioPidsChanged = not rpTsRelayPidArraysEqual(previousAudioPids,selectedAudioPids)
    pcrPidChanged = previousPcrPid <> selectedPcrPid
    previousPmtSignature = state.pmtSignature
    pmtContentChanged = previousPmtSignature <> "" and previousPmtSignature <> pmtSignature
    if previousVideoPid <> selectedVideoPid or audioPidsChanged or pcrPidChanged or pmtContentChanged
        rpTsRelayResetPesClockState(state)
        if pcrPidChanged
            state.lastPcr = {}
            state.havePcr = {}
        end if
        print "[RokuPlus ts-audit] pmt_stream_pids_changed videoOld="; previousVideoPid; " videoNew="; selectedVideoPid; " audioOld="; previousAudioPids; " audioNew="; selectedAudioPids; " pcrOld="; previousPcrPid; " pcrNew="; selectedPcrPid; " contentChanged="; pmtContentChanged; " pes_clock_state_reset=true"
    end if
    state.pcrPid = selectedPcrPid
    state.pmtSignature = pmtSignature
    state.videoPid = selectedVideoPid
    state.audioPids = selectedAudioPids
    return true
end function

function rpTsRelayReadPtsArray(bytes as object, offset as integer, expectedPrefix as integer) as dynamic
    if type(bytes) <> "roArray" or offset < 0 or offset + 4 >= bytes.count() then return -1
    b0 = bytes[offset]
    b1 = bytes[offset+1]
    b2 = bytes[offset+2]
    b3 = bytes[offset+3]
    b4 = bytes[offset+4]
    if (b0 \\ 16) <> expectedPrefix then return -1
    if (b0 mod 2) <> 1 or (b2 mod 2) <> 1 or (b4 mod 2) <> 1 then return -1
    return ((b0 mod 16) \\ 2) * 1073741824 + b1 * 4194304 + (b2 \\ 2) * 32768 + b3 * 128 + (b4 \\ 2)
end function

function rpTsRelayAuditContinuity(payload as object, state as object) as object
    result = {checked:0,errors:0,duplicates:0,totalErrors:0,totalDuplicates:0}
    if type(payload) <> "roByteArray" then return result
    total = payload.Count()
    if total <= 0 or (total mod 188) <> 0 then return result
    if type(state) <> "roAssociativeArray" then return result
    lastCounters = state.lastCounters
    haveCounters = state.haveCounters
    if type(lastCounters) <> "roAssociativeArray" or type(haveCounters) <> "roAssociativeArray" then return result
    for offset = 0 to total - 188 step 188
        if payload[offset] = &H47
            pid = (payload[offset+1] mod 32) * 256 + payload[offset+2]
            header = payload[offset+3]
            adaptationControl = (header \ 16) mod 4
            hasPayload = adaptationControl = 1 or adaptationControl = 3
            discontinuity = false
            if adaptationControl = 2 or adaptationControl = 3
                adaptationLength = payload[offset+4]
                if adaptationLength > 0 and adaptationLength <= 183 and offset + 5 + adaptationLength <= offset + 188
                    adaptationFlags = payload[offset+5]
                    if adaptationFlags >= 128 then discontinuity = true
                end if
            end if
            if pid <> 8191
                key = pid.toStr()
                if discontinuity
                    if haveCounters.doesExist(key) then haveCounters.Delete(key)
                    if lastCounters.doesExist(key) then lastCounters.Delete(key)
                end if
                if hasPayload
                    if haveCounters.doesExist(key)
                        result.checked++
                        expected = (lastCounters[key] + 1) mod 16
                        if discontinuity
                            ' The declared discontinuity resets this PID baseline.
                        else if header mod 16 = lastCounters[key]
                            result.duplicates++
                        else if header mod 16 <> expected
                            result.errors++
                        end if
                    end if
                    lastCounters[key] = header mod 16
                    haveCounters[key] = true
                end if
            end if
        end if
    end for
    state.lastCounters = lastCounters
    state.haveCounters = haveCounters
    state.checked = state.checked + result.checked
    state.errors = state.errors + result.errors
    state.duplicates = state.duplicates + result.duplicates
    result.totalErrors = state.errors
    result.totalDuplicates = state.duplicates
    return result
end function

function rpTsRelayReadPts(payload as object, offset as integer, expectedPrefix as integer) as dynamic
    if offset < 0 or offset + 4 >= payload.Count() then return -1
    b0 = payload[offset]
    b1 = payload[offset+1]
    b2 = payload[offset+2]
    b3 = payload[offset+3]
    b4 = payload[offset+4]
    prefix = b0 \ 16
    if prefix <> expectedPrefix then return -1
    if (b0 mod 2) <> 1 or (b2 mod 2) <> 1 or (b4 mod 2) <> 1 then return -1
    ' MPEG-2 PTS/DTS is a 33-bit clock. Ignore marker bits and retain bit 1 of byte 2.
    return ((b0 mod 16) \ 2) * 1073741824 + b1 * 4194304 + (b2 \ 2) * 32768 + b3 * 128 + (b4 \ 2)
end function
