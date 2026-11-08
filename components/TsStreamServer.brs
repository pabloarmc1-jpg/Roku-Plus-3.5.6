' Experimental local HLS proxy. Roku requests the manifest and each TS segment independently.
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
    if not listener.listen(4)
        m.top.status = "listen_error"
        print "[RokuPlus ts-relay] server_failed stage=listen"
        listener.close()
        return
    end if
    m.top.status = "listening"
    print "[RokuPlus ts-relay] listening port=49322 segments="; m.top.segments.count()
    while not m.top.stopRequested
        event = wait(250,port)
        if type(event) = "roSocketEvent"
            if event.getSocketID() = listener.getID() and listener.isReadable()
                connection = listener.accept()
                if connection <> invalid then rpTsRelayServe(connection,m.top,port)
            end if
        end if
    end while
    listener.close()
    m.top.status = "stopped"
    print "[RokuPlus ts-relay] stopped"
end sub

sub rpTsRelayServe(connection as object, server as object, listenerPort as object)
    ' Install the event port before reading. The accepted socket may deliver the
    ' request in multiple chunks; never assume the first receive contains headers.
    connectionPort = CreateObject("roMessagePort")
    connection.setMessagePort(connectionPort)
    connection.notifyReadable(true)
    connection.notifyWritable(true)
    connection.notifyException(true)

    request = ""
    complete = false
    timer = CreateObject("roTimespan")
    timer.Mark()
    while len(request) < 8192 and not complete and timer.TotalMilliseconds() < 5000
        if connection.isException() then exit while
        if connection.isReadable()
            part = connection.receiveStr(2048)
            if part <> "" then request += part
            if instr(1,request,chr(13)+chr(10)+chr(13)+chr(10)) > 0 then complete = true
        else
            wait(100,connectionPort)
        end if
    end while
    if not complete
        print "[RokuPlus ts-relay] request_incomplete bytes="; len(request); " timeoutMs="; timer.TotalMilliseconds()
        connection.close()
        return
    end if

    firstLine = request.split(chr(10))[0].trim()
    parts = firstLine.split(" ")
    method = ""
    requestPath = ""
    if parts.count() >= 1 then method = ucase(parts[0])
    if parts.count() >= 2 then requestPath = parts[1]
    print "[RokuPlus ts-relay] http_request method="; method; " path="; requestPath

    if method <> "GET" and method <> "HEAD"
        rpTsRelayReply(connection,"405 Method Not Allowed","text/plain","Método no permitido",server,connectionPort)
        print "[RokuPlus ts-relay] http_response status=405 method="; method
        connection.close()
        return
    end if
    headOnly = method = "HEAD"

    accessKey = server.accessKey
    if GetInterface(accessKey,"ifString") = invalid or len(accessKey) < 16
        rpTsRelayReply(connection,"403 Forbidden","text/plain","Acceso denegado",server,connectionPort)
        print "[RokuPlus ts-relay] http_response status=403"
        connection.close()
        return
    end if
    if requestPath = "/index.m3u8?key="+accessKey
        manifest = rpTsRelayManifest(server)
        if manifest = ""
            rpTsRelayReply(connection,"500 Internal Server Error","text/plain","Manifiesto no disponible",server,connectionPort)
            print "[RokuPlus ts-relay] http_response status=500 resource=manifest"
        else
            rpTsRelaySendHeader(connection,"200 OK","application/vnd.apple.mpegurl",len(manifest),server,connectionPort)
            if server.sendOk and not headOnly then rpTsRelaySendString(connection,manifest,server,connectionPort)
            print "[RokuPlus ts-relay] http_response status=200 resource=manifest bytes="; len(manifest); " head="; headOnly; " sendOk="; server.sendOk
            if not headOnly then print "[RokuPlus ts-relay] manifest_requested segments="; server.segments.count()
        end if
        connection.close()
        return
    end if

    segments = server.segments
    segmentIndex = -1
    for i = 0 to segments.count()-1
        if requestPath = "/segment/"+i.toStr()+".ts?key="+accessKey
            segmentIndex = i
            exit for
        end if
    end for
    if segmentIndex < 0
        rpTsRelayReply(connection,"404 Not Found","text/plain","No encontrado",server,connectionPort)
        print "[RokuPlus ts-relay] http_response status=404 path="; requestPath
        connection.close()
        return
    end if

    segmentUrl = segments[segmentIndex]
    if GetInterface(segmentUrl,"ifString") = invalid or left(segmentUrl,8) <> "https://"
        rpTsRelayReply(connection,"502 Bad Gateway","text/plain","Segmento no válido",server,connectionPort)
        print "[RokuPlus ts-relay] http_response status=502 resource=segment index="; segmentIndex
        connection.close()
        return
    end if
    headers = server.mediaHeaders
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
    code = xfer.GetToFile(filePath)
    if code < 200 or code >= 300
        print "[RokuPlus ts-relay] upstream_failed index="; segmentIndex; " status="; code
        DeleteFile(filePath)
        rpTsRelayReply(connection,"502 Bad Gateway","text/plain","No se pudo obtener el segmento",server,connectionPort)
        connection.close()
        return
    end if
    payload = CreateObject("roByteArray")
    if not payload.ReadFile(filePath) or payload.Count() <= 0
        DeleteFile(filePath)
        rpTsRelayReply(connection,"502 Bad Gateway","text/plain","Segmento vacío",server,connectionPort)
        print "[RokuPlus ts-relay] http_response status=502 resource=segment index="; segmentIndex
        connection.close()
        return
    end if

    if segmentIndex = 0 then rpTsRelayInspectTransport(payload)

    range = rpTsRelayParseRange(request,payload.Count())
    if range.invalid
        rpTsRelaySendHeader(connection,"416 Range Not Satisfiable","video/mp2t",0,server,connectionPort)
        print "[RokuPlus ts-relay] http_response status=416 resource=segment index="; segmentIndex
        DeleteFile(filePath)
        connection.close()
        return
    end if
    responseStatus = "200 OK"
    responseLength = payload.Count()
    responseStart = 0
    responseEnd = payload.Count()-1
    if range.present
        responseStart = range.start
        responseEnd = range.end
        responseLength = responseEnd-responseStart+1
        responseStatus = "206 Partial Content"
    end if
    if range.present
        header = "HTTP/1.1 206 Partial Content"+chr(13)+chr(10)
        header += "Content-Type: video/mp2t"+chr(13)+chr(10)
        header += "Content-Length: "+responseLength.toStr()+chr(13)+chr(10)
        header += "Content-Range: bytes "+responseStart.toStr()+"-"+responseEnd.toStr()+"/"+payload.Count().toStr()+chr(13)+chr(10)
        header += "Accept-Ranges: bytes"+chr(13)+chr(10)
        header += "Cache-Control: no-store"+chr(13)+chr(10)
        header += "Connection: close"+chr(13)+chr(10)+chr(13)+chr(10)
        rpTsRelaySendString(connection,header,server,connectionPort)
        print "[RokuPlus ts-relay] range_requested start="; responseStart; " end="; responseEnd
    else
        rpTsRelaySendHeader(connection,responseStatus,"video/mp2t",responseLength,server,connectionPort)
    end if
    if server.sendOk and not headOnly
        if range.present
            rangedPayload = CreateObject("roByteArray")
            for byteIndex = responseStart to responseEnd
                rangedPayload.push(payload[byteIndex])
            end for
            rpTsRelaySendBytes(connection,rangedPayload,server,connectionPort)
        else
            rpTsRelaySendBytes(connection,payload,server,connectionPort)
        end if
    end if
    if server.sendOk
        if not headOnly
            server.segmentsSent = server.segmentsSent + 1
            server.bytesSent = server.bytesSent + responseLength
            if segmentIndex+1 > server.nextSegmentIndex then server.nextSegmentIndex = segmentIndex+1
        end if
        print "[RokuPlus ts-relay] http_response status="; responseStatus; " resource=segment index="; segmentIndex; " bytes="; responseLength; " head="; headOnly; " sendOk=true"
    else
        print "[RokuPlus ts-relay] http_response_failed resource=segment index="; segmentIndex
    end if
    DeleteFile(filePath)
    connection.close()
end sub

' Inspect the first downloaded TS segment without changing its bytes or playback path.
sub rpTsRelayInspectTransport(data as object)
    if type(data) <> "roByteArray" or data.Count() < 188 then return
    packetCount = int(data.Count()/188)
    syncErrors = 0
    pidCounts = {}
    pmtPid = -1
    videoPid = -1
    audioPid = -1
    videoType = -1
    audioType = -1
    patFound = false
    pmtFound = false

    for packetIndex = 0 to packetCount-1
        base = packetIndex*188
        if data[base] <> 71
            syncErrors++
            continue for
        end if
        pid = ((data[base+1] and 31)*256)+data[base+2]
        key = pid.toStr()
        if pidCounts[key] = invalid then pidCounts[key] = 0
        pidCounts[key] = pidCounts[key]+1

        adaptation = (data[base+3] and 48)/16
        if adaptation = 0 or adaptation = 2 then continue for
        payloadAt = base+4
        if adaptation = 3
            payloadAt = payloadAt+1+data[base+4]
        end if
        if payloadAt >= base+188 then continue for

        if pid = 0 and not patFound and (data[base+1] and 64) <> 0
            pointer = data[payloadAt]
            sectionAt = payloadAt+1+pointer
            if sectionAt+12 < base+188 and data[sectionAt] = 0
                sectionLength = ((data[sectionAt+1] and 15)*256)+data[sectionAt+2]
                loopAt = sectionAt+8
                loopEnd = sectionAt+3+sectionLength-4
                while loopAt+3 <= loopEnd and loopAt+3 < base+188
                    programNumber = data[loopAt]*256+data[loopAt+1]
                    candidatePid = (data[loopAt+2] and 31)*256+data[loopAt+3]
                    if programNumber > 0
                        pmtPid = candidatePid
                        patFound = true
                        exit while
                    end if
                    loopAt += 4
                end while
            end if
        end if

        if pmtPid >= 0 and pid = pmtPid and not pmtFound and (data[base+1] and 64) <> 0
            pointer = data[payloadAt]
            sectionAt = payloadAt+1+pointer
            if sectionAt+16 < base+188 and data[sectionAt] = 2
                sectionLength = ((data[sectionAt+1] and 15)*256)+data[sectionAt+2]
                programInfoLength = (data[sectionAt+10] and 15)*256+data[sectionAt+11]
                streamAt = sectionAt+12+programInfoLength
                sectionEnd = sectionAt+3+sectionLength-4
                while streamAt+4 <= sectionEnd and streamAt+4 < base+188
                    streamType = data[streamAt]
                    elementaryPid = (data[streamAt+1] and 31)*256+data[streamAt+2]
                    esInfoLength = (data[streamAt+3] and 15)*256+data[streamAt+4]
                    if streamType = 27 or streamType = 36 or streamType = 2
                        if videoPid < 0
                            videoPid = elementaryPid
                            videoType = streamType
                        end if
                    else if streamType = 15 or streamType = 17 or streamType = 3 or streamType = 4 or streamType = 129 or streamType = 135
                        if audioPid < 0
                            audioPid = elementaryPid
                            audioType = streamType
                        end if
                    end if
                    streamAt += 5+esInfoLength
                end while
                pmtFound = true
            end if
        end if
    end for

    print "[RokuPlus ts-inspect] bytes="; data.Count(); " packets="; packetCount; " syncErrors="; syncErrors; " pat="; patFound; " pmtPid="; pmtPid; " pmt="; pmtFound; " videoPid="; videoPid; " videoType="; videoType; " audioPid="; audioPid; " audioType="; audioType
    print "[RokuPlus ts-inspect] pidPacketCounts="; FormatJson(pidCounts)
end sub

function rpTsRelayParseRange(request as string, total as integer) as object
    result = {present:false,invalid:false,start:0,end:total-1}
    for each raw in request.split(chr(10))
        line = raw.trim()
        if lcase(left(line,6)) = "range:"
            value = line
            colon = instr(1,value,":")
            value = mid(value,colon+1).trim()
            if left(lcase(value),6) <> "bytes=" then return {present:false,invalid:true,start:0,end:0}
            spec = mid(value,7)
            if instr(1,spec,",") > 0 then return {present:false,invalid:true,start:0,end:0}
            pair = spec.split("-")
            if pair.count() <> 2 or pair[0] = "" then return {present:false,invalid:true,start:0,end:0}
            if not CreateObject("roRegex","^[0-9]+$","").isMatch(pair[0]) then return {present:false,invalid:true,start:0,end:0}
            first = pair[0].toInt()
            last = total-1
            if pair[1] <> ""
                if not CreateObject("roRegex","^[0-9]+$","").isMatch(pair[1]) then return {present:false,invalid:true,start:0,end:0}
                last = pair[1].toInt()
            end if
            if first < 0 or first >= total or last < first then return {present:false,invalid:true,start:0,end:0}
            if last >= total then last = total-1
            result.present = true
            result.start = first
            result.end = last
            return result
        end if
    end for
    return result
end function

sub rpTsRelaySendHeader(connection as object, status as string, contentType as string, length as integer, server as object, port as object)
    header = "HTTP/1.1 "+status+chr(13)+chr(10)
    header += "Content-Type: "+contentType+chr(13)+chr(10)
    header += "Content-Length: "+length.toStr()+chr(13)+chr(10)
    header += "Accept-Ranges: bytes"+chr(13)+chr(10)
    header += "Cache-Control: no-store"+chr(13)+chr(10)
    header += "Connection: close"+chr(13)+chr(10)+chr(13)+chr(10)
    rpTsRelaySendString(connection,header,server,port)
end sub

function rpTsRelayManifest(server as object) as string
    segments = server.segments
    durations = server.segmentDurations
    if type(segments) <> "roArray" or type(durations) <> "roArray" then return ""
    if segments.count() < 2 or durations.count() <> segments.count() then return ""
    targetDuration = 1
    for each duration in durations
        if duration <= 0 then return ""
        rounded = int(duration)
        if duration > rounded then rounded++
        if rounded > targetDuration then targetDuration = rounded
    end for
    crlf = chr(13)+chr(10)
    manifest = "#EXTM3U"+crlf
    manifest += "#EXT-X-VERSION:3"+crlf
    manifest += "#EXT-X-PLAYLIST-TYPE:VOD"+crlf
    manifest += "#EXT-X-MEDIA-SEQUENCE:0"+crlf
    manifest += "#EXT-X-TARGETDURATION:"+targetDuration.toStr()+crlf
    for i = 0 to segments.count()-1
        manifest += "#EXTINF:"+durations[i].toStr()+","+crlf
        manifest += "/segment/"+i.toStr()+".ts?key="+server.accessKey+crlf
    end for
    manifest += "#EXT-X-ENDLIST"+crlf
    return manifest
end function

sub rpTsRelayReply(connection as object, status as string, contentType as string, body as string, server as object, port as object)
    header = "HTTP/1.1 "+status+chr(13)+chr(10)
    header += "Content-Type: "+contentType+chr(13)+chr(10)
    header += "Content-Length: "+len(body).toStr()+chr(13)+chr(10)
    header += "Cache-Control: no-store"+chr(13)+chr(10)
    header += "Connection: close"+chr(13)+chr(10)+chr(13)+chr(10)
    rpTsRelaySendString(connection,header+body,server,port)
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
    while offset < total
        count = connection.send(value,offset,total-offset)
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
    timer = CreateObject("roTimespan")
    timer.Mark()
    while timer.TotalMilliseconds() < 10000
        if connection.isException() then return false
        if connection.isWritable() then return true
        wait(250,port)
    end while
    return false
end function
