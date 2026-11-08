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
    request = ""
    complete = false
    while len(request) < 8192 and not complete
        part = connection.receiveStr(2048)
        if part = "" then exit while
        request += part
        if instr(1,request,chr(13)+chr(10)+chr(13)+chr(10)) > 0 then complete = true
    end while
    if not complete
        connection.close()
        return
    end if
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
    if GetInterface(accessKey,"ifString") = invalid or len(accessKey) < 16
        rpTsRelayReply(connection,"403 Forbidden","text/plain","Acceso denegado",server,connectionPort)
        connection.close()
        return
    end if
    if requestPath = "/index.m3u8?key="+accessKey
        manifest = rpTsRelayManifest(server)
        if manifest = ""
            rpTsRelayReply(connection,"500 Internal Server Error","text/plain","Manifiesto no disponible",server,connectionPort)
        else
            rpTsRelayReply(connection,"200 OK","application/vnd.apple.mpegurl",manifest,server,connectionPort)
            print "[RokuPlus ts-relay] manifest_requested segments="; server.segments.count()
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
        connection.close()
        print "[RokuPlus ts-relay] rejected_path"
        return
    end if

    segmentUrl = segments[segmentIndex]
    if GetInterface(segmentUrl,"ifString") = invalid or left(segmentUrl,8) <> "https://"
        rpTsRelayReply(connection,"502 Bad Gateway","text/plain","Segmento no válido",server,connectionPort)
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
        connection.close()
        return
    end if
    header = "HTTP/1.1 200 OK"+chr(13)+chr(10)
    header += "Content-Type: video/mp2t"+chr(13)+chr(10)
    header += "Content-Length: "+payload.Count().toStr()+chr(13)+chr(10)
    header += "Cache-Control: no-store"+chr(13)+chr(10)
    header += "Connection: close"+chr(13)+chr(10)+chr(13)+chr(10)
    rpTsRelaySendString(connection,header,server,connectionPort)
    if server.sendOk then rpTsRelaySendBytes(connection,payload,server,connectionPort)
    if server.sendOk
        server.segmentsSent = server.segmentsSent + 1
        server.bytesSent = server.bytesSent + payload.Count()
        if segmentIndex+1 > server.nextSegmentIndex then server.nextSegmentIndex = segmentIndex+1
        print "[RokuPlus ts-relay] segment_sent index="; segmentIndex; " bytes="; payload.Count()
    else
        print "[RokuPlus ts-relay] segment_send_failed index="; segmentIndex
    end if
    DeleteFile(filePath)
    connection.close()
end sub

function rpTsRelayManifest(server as object) as string
    segments = server.segments
    durations = server.segmentDurations
    if type(segments) <> "roArray" or type(durations) <> "roArray" then return ""
    if segments.count() < 2 or durations.count() <> segments.count() then return ""
    targetDuration = 1
    for each duration in durations
        if GetInterface(duration,"ifFloat") = invalid and GetInterface(duration,"ifDouble") = invalid and GetInterface(duration,"ifInt") = invalid then return ""
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
