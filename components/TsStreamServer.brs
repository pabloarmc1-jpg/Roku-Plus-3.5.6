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
    while not m.top.stopRequested
        event = wait(250,port)
        if type(event) = "roSocketEvent"
            if event.getSocketID() = listener.getID() and listener.isReadable()
                connection = listener.accept()
                if connection <> invalid then rpTsRelayServe(connection,m.top)
            end if
        end if
    end while
    listener.close()
    m.top.status = "stopped"
    print "[RokuPlus ts-relay] stopped"
end sub

sub rpTsRelayServe(connection as object, server as object)
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
    firstLine = request.split(chr(10))[0].trim()
    parts = firstLine.split(" ")
    if left(firstLine,4) <> "GET "
        rpTsRelaySendString(connection,"HTTP/1.1 405 Method Not Allowed"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10))
        connection.close()
        return
    end if
    accessKey = server.accessKey
    requestPath = ""
    if parts.count() >= 2 then requestPath = parts[1]
    if GetInterface(accessKey,"ifString") = invalid or len(accessKey) < 16 or requestPath <> "/stream.ts?key="+accessKey
        rpTsRelaySendString(connection,"HTTP/1.1 403 Forbidden"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10))
        connection.close()
        print "[RokuPlus ts-relay] rejected_client"
        return
    end if
    print "[RokuPlus ts-relay] client_connected"
    header = "HTTP/1.1 200 OK"+chr(13)+chr(10)
    header += "Content-Type: video/mp2t"+chr(13)+chr(10)
    header += "Transfer-Encoding: chunked"+chr(13)+chr(10)
    header += "Cache-Control: no-store"+chr(13)+chr(10)
    header += "Connection: close"+chr(13)+chr(10)+chr(13)+chr(10)
    if not rpTsRelaySendString(connection,header)
        connection.close()
        return
    segments = server.segments
    headers = server.mediaHeaders
    sentSegments = 0
    sentBytes = 0
    for each segmentUrl in segments
        if server.stopRequested then exit for
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
        code = xfer.GetToFile(filePath)
        server.lastHttpStatus = code
        if code < 200 or code >= 300
            print "[RokuPlus ts-relay] upstream_failed index="; sentSegments+1; " status="; code
            DeleteFile(filePath)
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
        if not rpTsRelaySendString(connection,rpTsRelayHex(payloadSize)+chr(13)+chr(10))
            DeleteFile(filePath)
            exit for
        end if
        if not rpTsRelaySendBytes(connection,payload)
            DeleteFile(filePath)
            exit for
        end if
        if not rpTsRelaySendString(connection,chr(13)+chr(10))
            DeleteFile(filePath)
            exit for
        end if
        sentSegments++
        sentBytes += payloadSize
        server.segmentsSent = sentSegments
        server.bytesSent = sentBytes
        if sentSegments = 1 or sentSegments mod 25 = 0
            print "[RokuPlus ts-relay] forwarded segments="; sentSegments; " bytes="; sentBytes
        end if
        DeleteFile(filePath)
    end for
    if sentSegments = segments.count()
        rpTsRelaySendString(connection,"0"+chr(13)+chr(10)+chr(13)+chr(10))
        print "[RokuPlus ts-relay] stream_complete segments="; sentSegments; " bytes="; sentBytes
    else
        print "[RokuPlus ts-relay] stream_incomplete segments="; sentSegments; " total="; segments.count()
    end if
    connection.close()
end sub

function rpTsRelaySendString(connection as object, value as string) as Boolean
    offset = 0
    success = true
    while offset < len(value)
        count = connection.sendStr(mid(value,offset+1))
        if count <= 0
            success = false
            exit while
        end if
        offset += count
    end while
    return success
end function

function rpTsRelaySendBytes(connection, value)
    offset = 0
    total = value.Count()
    success = true
    while offset < total
        count = connection.send(value,offset,total-offset)
        if count <= 0
            success = false
            exit while
        end if
        offset += count
    end while
    return success
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
