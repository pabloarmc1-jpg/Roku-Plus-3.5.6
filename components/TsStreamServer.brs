' Experimental single-connection MPEG-TS relay. One HTTP response carries all source segments.
sub init()
    m.top.functionName = "runTsStreamServer"
end sub

sub runTsStreamServer()
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
    connections = {}
    requests = {}
    while not m.top.stopRequested
        event = wait(250,port)
        if type(event) = "roSocketEvent"
            changedId = event.getSocketID()
            if changedId = listener.getID()
                if listener.isReadable()
                    connection = listener.accept()
                    if connection <> invalid
                        connection.setMessagePort(port)
                        connection.notifyReadable(true)
                        connection.notifyException(true)
                        key = connection.getID().toStr()
                        connections[key] = connection
                        requests[key] = ""
                        print "[RokuPlus ts-relay diag] client_accepted socketId="; key
                    end if
                end if
            else
                key = changedId.toStr()
                if connections.DoesExist(key)
                    connection = connections[key]
                    if connection.isException()
                        print "[RokuPlus ts-relay diag] client_request_exception bytes="; len(requests[key]); " socketStatus="; connection.status()
                        connection.close()
                        connections.Delete(key)
                        requests.Delete(key)
                    else if connection.isReadable()
                        part = connection.receiveStr(4096)
                        if part <> ""
                            requests[key] += part
                            print "[RokuPlus hls-relay diag] request_bytes socketId="; key; " accumulated="; len(requests[key])
                            if len(requests[key]) > 8192
                                print "[RokuPlus ts-relay diag] client_request_too_large socketId="; key
                                connection.close()
                                connections.Delete(key)
                                requests.Delete(key)
                            else if instr(1,requests[key],chr(13)+chr(10)+chr(13)+chr(10)) > 0
                                request = requests[key]
                                connections.Delete(key)
                                requests.Delete(key)
                                rpTsRelayServe(connection,m.top,request)
                            end if
                        else if not connection.eOK()
                            print "[RokuPlus ts-relay diag] client_request_closed bytes="; len(requests[key]); " socketStatus="; connection.status()
                            connection.close()
                            connections.Delete(key)
                            requests.Delete(key)
                        end if
                    end if
                end if
            end if
        end if
    end while
    for each key in connections
        connections[key].close()
    end for
    listener.close()
    m.top.status = "stopped"
    print "[RokuPlus ts-relay] stopped"
end sub

sub rpTsRelayServe(connection as object, server as object, request as string)
    connectionPort = CreateObject("roMessagePort")
    connection.setMessagePort(connectionPort)
    connection.notifyWritable(true)
    connection.notifyException(true)
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
    keySuffix = "?key="+accessKey
    if GetInterface(accessKey,"ifString") = invalid or len(accessKey) < 16 or right(requestPath,len(keySuffix)) <> keySuffix
        rpTsRelaySendString(connection,"HTTP/1.1 403 Forbidden"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
        connection.close()
        print "[RokuPlus ts-relay] rejected_client"
        return
    end if
    if requestPath = "/playlist.m3u8"+keySuffix
        print "[RokuPlus hls-relay diag] request_complete route=playlist"
        playlist = rpTsRelayBuildPlaylist(server)
        rpTsRelaySendHttpBody(connection,server,connectionPort,"200 OK","application/vnd.apple.mpegurl",playlist)
        connection.close()
        print "[RokuPlus hls-relay] playlist_sent segments="; server.timeline.count(); " bytes="; len(playlist)
        return
    end if
    prefix = "/segment/"
    if left(requestPath,len(prefix)) = prefix
        route = mid(requestPath,len(prefix)+1)
        route = left(route,len(route)-len(keySuffix))
        if right(route,3) <> ".ts"
            rpTsRelaySendString(connection,"HTTP/1.1 404 Not Found"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
            connection.close()
            return
        end if
        indexText = left(route,len(route)-3)
        if indexText = "" or not CreateObject("roRegex","^[0-9]{1,4}$","").isMatch(indexText)
            rpTsRelaySendString(connection,"HTTP/1.1 404 Not Found"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
            connection.close()
            return
        end if
        segmentIndex = indexText.toInt()
        print "[RokuPlus hls-relay diag] request_complete route=segment index="; segmentIndex
        if segmentIndex < 0 or segmentIndex >= server.segments.count() or segmentIndex >= server.timeline.count()
            rpTsRelaySendString(connection,"HTTP/1.1 404 Not Found"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
            connection.close()
            return
        end if
        rpTsRelayServeSegment(connection,server,connectionPort,segmentIndex)
        connection.close()
        return
    end if
    rpTsRelaySendString(connection,"HTTP/1.1 404 Not Found"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
    connection.close()
end sub

function rpTsRelayBuildPlaylist(server as object) as string
    timeline = server.timeline
    if type(timeline) <> "roArray" or timeline.count() = 0 then return ""
    targetDuration = 1
    for each entry in timeline
        rounded = int(entry.duration)
        if entry.duration > rounded then rounded++
        if rounded > targetDuration then targetDuration = rounded
    end for
    firstSequence = timeline[0].sequence
    firstDiscontinuity = timeline[0].discontinuitySequence
    if timeline[0].discontinuity then firstDiscontinuity--
    if firstDiscontinuity < 0 then firstDiscontinuity = 0
    body = "#EXTM3U"+chr(10)
    body += "#EXT-X-VERSION:3"+chr(10)
    body += "#EXT-X-PLAYLIST-TYPE:VOD"+chr(10)
    body += "#EXT-X-TARGETDURATION:"+targetDuration.toStr()+chr(10)
    body += "#EXT-X-MEDIA-SEQUENCE:"+firstSequence.toStr()+chr(10)
    if firstDiscontinuity > 0 then body += "#EXT-X-DISCONTINUITY-SEQUENCE:"+firstDiscontinuity.toStr()+chr(10)
    for each entry in timeline
        if entry.discontinuity then body += "#EXT-X-DISCONTINUITY"+chr(10)
        body += "#EXTINF:"+entry.duration.toStr()+","+chr(10)
        body += "segment/"+entry.index.toStr()+".ts?key="+server.accessKey+chr(10)
    end for
    body += "#EXT-X-ENDLIST"+chr(10)
    return body
end function

sub rpTsRelayServeSegment(connection as object, server as object, port as object, segmentIndex as integer)
    segmentUrl = server.segments[segmentIndex]
    if GetInterface(segmentUrl,"ifString") = invalid or left(segmentUrl,8) <> "https://"
        rpTsRelaySendString(connection,"HTTP/1.1 502 Bad Gateway"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,port)
        print "[RokuPlus hls-relay] invalid_segment_url index="; segmentIndex
        return
    end if
    print "[RokuPlus hls-relay diag] segment_fetch_start index="; segmentIndex
    timer = CreateObject("roTimespan")
    timer.Mark()
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.enablePeerVerification(true)
    xfer.enableHostVerification(true)
    xfer.SetUrl(segmentUrl)
    headers = server.mediaHeaders
    if type(headers) = "roAssociativeArray"
        agent = headers["User-Agent"]
        referer = headers["Referer"]
        if GetInterface(agent,"ifString") <> invalid and len(agent) > 0 then xfer.AddHeader("User-Agent",agent)
        if GetInterface(referer,"ifString") <> invalid and len(referer) > 0 then xfer.AddHeader("Referer",referer)
    end if
    filePath = "tmp:/rp_hls_relay_"+CreateObject("roDeviceInfo").getRandomUUID()+".ts"
    code = xfer.GetToFile(filePath)
    downloadMs = timer.TotalMilliseconds()
    print "[RokuPlus hls-relay diag] segment_fetch_done index="; segmentIndex; " http="; code; " ms="; downloadMs
    if code < 200 or code >= 300
        DeleteFile(filePath)
        rpTsRelaySendString(connection,"HTTP/1.1 502 Bad Gateway"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,port)
        print "[RokuPlus hls-relay] upstream_failed index="; segmentIndex; " status="; code; " ms="; downloadMs
        return
    end if
    payload = CreateObject("roByteArray")
    if not payload.ReadFile(filePath)
        DeleteFile(filePath)
        rpTsRelaySendString(connection,"HTTP/1.1 502 Bad Gateway"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,port)
        print "[RokuPlus hls-relay] file_read_failed index="; segmentIndex
        return
    end if
    payloadSize = payload.Count()
    if payloadSize > 0
        syncErrors = 0
        packetCount = 0
        for offset = 0 to payloadSize - 1 step 188
            if offset + 187 < payloadSize
                packetCount++
                if payload[offset] <> &h47 then syncErrors++
            end if
        end for
        firstHex = ""
        for byteIndex = 0 to 15
            if byteIndex < payloadSize
                hexByte = rpTsRelayHex(payload[byteIndex])
                if len(hexByte) = 1 then hexByte = "0" + hexByte
                firstHex += hexByte
            end if
        end for
        print "[RokuPlus hls-relay diag] ts_check index="; segmentIndex; " bytes="; payloadSize; " remainder188="; payloadSize mod 188; " packets="; packetCount; " syncErrors="; syncErrors; " first16="; firstHex
        analysisTimer = CreateObject("roTimespan")
        analysisTimer.Mark()
        rpTsRelayAnalyzeTs(payload,segmentIndex)
        print "[RokuPlus hls-relay diag] ts_analysis_done index="; segmentIndex; " ms="; analysisTimer.TotalMilliseconds()
    end if
    if payloadSize <= 0
        DeleteFile(filePath)
        rpTsRelaySendString(connection,"HTTP/1.1 502 Bad Gateway"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,port)
        print "[RokuPlus hls-relay] empty_segment index="; segmentIndex
        return
    end if
    response = "HTTP/1.1 200 OK"+chr(13)+chr(10)
    response += "Content-Type: video/mp2t"+chr(13)+chr(10)
    response += "Content-Length: "+payloadSize.toStr()+chr(13)+chr(10)
    response += "Cache-Control: no-store"+chr(13)+chr(10)
    response += "Connection: close"+chr(13)+chr(10)+chr(13)+chr(10)
    rpTsRelaySendString(connection,response,server,port)
    sendTimer = CreateObject("roTimespan")
    sendTimer.Mark()
    if server.sendOk then rpTsRelaySendBytes(connection,payload,server,port)
    print "[RokuPlus hls-relay diag] segment_send_done index="; segmentIndex; " ok="; server.sendOk; " ms="; sendTimer.TotalMilliseconds()
    if server.sendOk
        server.segmentsSent = server.segmentsSent + 1
        server.bytesSent = server.bytesSent + payloadSize
        print "[RokuPlus hls-relay] segment_sent index="; segmentIndex; " bytes="; payloadSize; " downloadMs="; downloadMs
    else
        print "[RokuPlus hls-relay] segment_send_failed index="; segmentIndex; " bytes="; payloadSize
    end if
    DeleteFile(filePath)
end sub

sub rpTsRelaySendHttpBody(connection as object, server as object, port as object, status as string, contentType as string, body as string)
    response = "HTTP/1.1 "+status+chr(13)+chr(10)
    response += "Content-Type: "+contentType+chr(13)+chr(10)
    response += "Content-Length: "+len(body).toStr()+chr(13)+chr(10)
    response += "Cache-Control: no-store"+chr(13)+chr(10)
    response += "Connection: close"+chr(13)+chr(10)+chr(13)+chr(10)
    rpTsRelaySendString(connection,response,server,port)
    if server.sendOk then rpTsRelaySendString(connection,body,server,port)
end sub

sub rpTsRelaySendString(connection as object, value as string, server as object, port as object)
    offset = 0
    server.sendOk = true
    while offset < len(value)
        count = connection.sendStr(mid(value,offset+1))
        if count > 0
            offset += count
        else if count < 0 and (connection.eAgain() or connection.eWouldBlock())
            if not rpTsRelayWaitWritable(connection,port)
                print "[RokuPlus ts-relay] send_wait_failed kind=string offset="; offset; " status="; connection.status()
                server.sendOk = false
                exit while
            end if
        else
            print "[RokuPlus ts-relay] send_failed kind=string count="; count; " offset="; offset; " status="; connection.status(); " eAgain="; connection.eAgain(); " eWouldBlock="; connection.eWouldBlock()
            server.sendOk = false
            exit while
        end if
    end while
end sub

sub rpTsRelaySendBytes(connection as object, value as object, server as object, port as object)
    offset = 0
    total = value.Count()
    server.sendOk = true
    chunkLimit = 65536
    while offset < total
        chunkSize = total - offset
        if chunkSize > chunkLimit then chunkSize = chunkLimit
        count = connection.send(value,offset,chunkSize)
        if count > 0
            offset += count
        else if count < 0 and (connection.eAgain() or connection.eWouldBlock())
            if not rpTsRelayWaitWritable(connection,port)
                print "[RokuPlus ts-relay] send_wait_failed kind=bytes offset="; offset; " total="; total; " status="; connection.status()
                server.sendOk = false
                exit while
            end if
        else
            print "[RokuPlus ts-relay] send_failed kind=bytes count="; count; " offset="; offset; " total="; total; " status="; connection.status(); " eAgain="; connection.eAgain(); " eWouldBlock="; connection.eWouldBlock()
            server.sendOk = false
            exit while
        end if
    end while
end sub

function rpTsRelayWaitWritable(connection as object, port as object) as boolean
    ' Wait for the socket's writable notification instead of polling blindly.
    ' A slow decoder can temporarily apply TCP backpressure while consuming a
    ' large TS segment; allow that pause without abandoning a valid connection.
    timer = CreateObject("roTimespan")
    timer.Mark()
    while timer.TotalMilliseconds() < 30000
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


' Diagnostic-only MPEG-TS inspection. Does not alter or rewrite media bytes.
sub rpTsRelayAnalyzeTs(payload as object, segmentIndex as integer)
    size = payload.Count()
    pidCounts = {}
    continuity = {}
    continuityErrors = 0
    pmtPid = -1
    videoPid = -1
    audioPid = -1
    patFound = false
    pmtFound = false
    videoPes = 0
    audioPes = 0
    ptsCount = 0
    dtsCount = 0
    firstPts = -1
    firstDts = -1
    nal7 = 0
    nal8 = 0
    nal5 = 0
    firstIdrPacket = -1

    for offset = 0 to size - 188 step 188
        if payload[offset] <> &h47 then continue for
        b1 = payload[offset+1]
        b2 = payload[offset+2]
        b3 = payload[offset+3]
        pid = (b1 mod 32) * 256 + b2
        pidKey = pid.toStr()
        if pidCounts.DoesExist(pidKey)
            pidCounts[pidKey] = pidCounts[pidKey] + 1
        else
            pidCounts[pidKey] = 1
        end if

        adaptationControl = int(b3 / 16) mod 4
        cc = b3 mod 16
        hasPayload = adaptationControl = 1 or adaptationControl = 3
        if hasPayload
            if continuity.DoesExist(pidKey)
                expected = (continuity[pidKey] + 1) mod 16
                if cc <> expected then continuityErrors++
            end if
            continuity[pidKey] = cc
        end if

        payloadOffset = offset + 4
        if adaptationControl = 2 or adaptationControl = 0 then payloadOffset = offset + 188
        if adaptationControl = 3 and payloadOffset < offset + 188
            payloadOffset += 1 + payload[payloadOffset]
        end if
        if payloadOffset >= offset + 188 then continue for

        unitStart = (int(b1 / 64) mod 2) = 1
        if pid = 0 and unitStart and not patFound
            pointer = payload[payloadOffset]
            section = payloadOffset + 1 + pointer
            if section + 11 < offset + 188 and payload[section] = 0
                sectionLength = (payload[section+1] mod 16) * 256 + payload[section+2]
                sectionEnd = section + 3 + sectionLength
                if sectionEnd <= offset + 188
                    entry = section + 8
                    while entry + 3 < sectionEnd - 4
                        programNumber = payload[entry] * 256 + payload[entry+1]
                        candidatePid = (payload[entry+2] mod 32) * 256 + payload[entry+3]
                        if programNumber > 0 then pmtPid = candidatePid
                        entry += 4
                    end while
                    patFound = pmtPid >= 0
                end if
            end if
        else if pid = pmtPid and pmtPid >= 0 and unitStart and not pmtFound
            pointer = payload[payloadOffset]
            section = payloadOffset + 1 + pointer
            if section + 12 < offset + 188 and payload[section] = 2
                sectionLength = (payload[section+1] mod 16) * 256 + payload[section+2]
                sectionEnd = section + 3 + sectionLength
                if sectionEnd <= offset + 188
                    programInfoLength = (payload[section+10] mod 16) * 256 + payload[section+11]
                    entry = section + 12 + programInfoLength
                    while entry + 4 < sectionEnd - 4
                        streamType = payload[entry]
                        elementaryPid = (payload[entry+1] mod 32) * 256 + payload[entry+2]
                        esInfoLength = (payload[entry+3] mod 16) * 256 + payload[entry+4]
                        if streamType = &h1B or streamType = &h24 then videoPid = elementaryPid
                        if streamType = &h0F or streamType = &h11 then audioPid = elementaryPid
                        entry += 5 + esInfoLength
                    end while
                    pmtFound = true
                end if
            end if
        end if

        scanStart = payloadOffset
        if unitStart and (pid = videoPid or pid = audioPid)
            if payloadOffset + 8 < offset + 188 and payload[payloadOffset] = 0 and payload[payloadOffset+1] = 0 and payload[payloadOffset+2] = 1
                if pid = videoPid then videoPes++
                if pid = audioPid then audioPes++
                flags = int(payload[payloadOffset+7] / 64) mod 4
                headerLength = payload[payloadOffset+8]
                scanStart = payloadOffset + 9 + headerLength
                if flags = 2 or flags = 3
                    if payloadOffset + 13 < offset + 188
                        ptsValue = rpTsRelayReadTimestamp(payload,payloadOffset+9)
                        ptsCount++
                        if firstPts < 0 then firstPts = ptsValue
                    end if
                end if
                if flags = 3
                    if payloadOffset + 18 < offset + 188
                        dtsValue = rpTsRelayReadTimestamp(payload,payloadOffset+14)
                        dtsCount++
                        if firstDts < 0 then firstDts = dtsValue
                    end if
                end if
            end if
        end if

        if pid = videoPid and scanStart < offset + 188
            for i = scanStart to offset + 183
                nalType = -1
                if i + 3 < offset + 188 and payload[i] = 0 and payload[i+1] = 0 and payload[i+2] = 1
                    nalType = payload[i+3] mod 32
                else if i + 4 < offset + 188 and payload[i] = 0 and payload[i+1] = 0 and payload[i+2] = 0 and payload[i+3] = 1
                    nalType = payload[i+4] mod 32
                end if
                if nalType = 7 then nal7++
                if nalType = 8 then nal8++
                if nalType = 5
                    nal5++
                    if firstIdrPacket < 0 then firstIdrPacket = int(offset / 188)
                end if
            end for
        end if
    end for

    pidSummary = ""
    for each key in pidCounts
        if pidSummary <> "" then pidSummary += ","
        pidSummary += key + ":" + pidCounts[key].toStr()
    end for
    print "[RokuPlus hls-relay diag] ts_map index="; segmentIndex; " pids="; pidSummary; " pat="; patFound; " pmtPid="; pmtPid; " pmt="; pmtFound
    print "[RokuPlus hls-relay diag] ts_streams videoPid="; videoPid; " audioPid="; audioPid; " ccErrors="; continuityErrors; " videoPes="; videoPes; " audioPes="; audioPes
    print "[RokuPlus hls-relay diag] ts_timestamps ptsCount="; ptsCount; " dtsCount="; dtsCount; " firstPts90k="; firstPts; " firstDts90k="; firstDts
    print "[RokuPlus hls-relay diag] ts_h264 videoPid="; videoPid; " annexB_sps="; nal7; " annexB_pps="; nal8; " annexB_idr="; nal5; " firstIdrPacket="; firstIdrPacket
end sub

function rpTsRelayReadTimestamp(payload as object, offset as integer)
    a = payload[offset]
    b = payload[offset+1]
    c = payload[offset+2]
    d = payload[offset+3]
    e = payload[offset+4]
    value = (int(a / 2) mod 8) * 536870912
    value += b * 4194304
    value += int(c / 2) * 16384
    value += d * 128
    value += int(e / 2)
    return value
end function
