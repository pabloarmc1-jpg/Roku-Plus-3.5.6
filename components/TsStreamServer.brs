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
    if server.sendOk then rpTsRelaySendBytes(connection,payload,server,port)
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
