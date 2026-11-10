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
        print "[RokuPlus ts-relay diag] client_request_incomplete bytes="; len(request); " socketStatus="; connection.status()
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
    if GetInterface(accessKey,"ifString") = invalid or len(accessKey) < 16 or requestPath <> "/stream.ts?key="+accessKey
        rpTsRelaySendString(connection,"HTTP/1.1 403 Forbidden"+chr(13)+chr(10)+"Connection: close"+chr(13)+chr(10)+chr(13)+chr(10),server,connectionPort)
        connection.close()
        print "[RokuPlus ts-relay] rejected_client"
        return
    end if
    sessionTimer = CreateObject("roTimespan")
    sessionTimer.Mark()
    print "[RokuPlus ts-relay diag] client_connected socketStatus="; connection.status()
    header = "HTTP/1.1 200 OK"+chr(13)+chr(10)
    header += "Content-Type: video/mp2t"+chr(13)+chr(10)
    header += "Transfer-Encoding: chunked"+chr(13)+chr(10)
    header += "Cache-Control: no-store"+chr(13)+chr(10)
    header += "Connection: close"+chr(13)+chr(10)+chr(13)+chr(10)
    rpTsRelaySendString(connection,header,server,connectionPort)
    if not server.sendOk
        print "[RokuPlus ts-relay diag] client_disconnected stage=response_header elapsedMs="; sessionTimer.TotalMilliseconds(); " socketStatus="; connection.status()
        connection.close()
        return
    end if
    print "[RokuPlus ts-relay diag] response_header_sent elapsedMs="; sessionTimer.TotalMilliseconds()
    segments = server.segments
    headers = server.mediaHeaders
    sentSegments = 0
    sentBytes = 0
    startIndex = server.nextSegmentIndex
    if GetInterface(startIndex,"ifInt") = invalid or startIndex < 0 then startIndex = 0
    endReason = "all_segments_sent"
    failedStage = ""
    for segmentIndex = startIndex to segments.count() - 1
        if server.stopRequested
            endReason = "stop_requested"
            exit for
        end if
        segmentUrl = segments[segmentIndex]
        if GetInterface(segmentUrl,"ifString") = invalid
            endReason = "invalid_segment_url"
            exit for
        end if
        if left(segmentUrl,8) <> "https://"
            endReason = "unsupported_segment_scheme"
            exit for
        end if
        segmentTimer = CreateObject("roTimespan")
        segmentTimer.Mark()
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
        downloadMs = segmentTimer.TotalMilliseconds()
        if code < 200 or code >= 300
            endReason = "upstream_http_error"
            failedStage = "download"
            print "[RokuPlus ts-relay] upstream_failed index="; segmentIndex+1; " status="; code; " downloadMs="; downloadMs
            DeleteFile(filePath)
            exit for
        end if
        payload = CreateObject("roByteArray")
        if not payload.ReadFile(filePath)
            endReason = "segment_file_read_failed"
            failedStage = "file_read"
            print "[RokuPlus ts-relay] file_read_failed index="; segmentIndex+1; " downloadMs="; downloadMs
            DeleteFile(filePath)
            exit for
        end if
        payloadSize = payload.Count()
        if payloadSize <= 0
            endReason = "empty_segment"
            failedStage = "file_read"
            print "[RokuPlus ts-relay diag] empty_segment index="; segmentIndex+1; " downloadMs="; downloadMs
            DeleteFile(filePath)
            exit for
        end if
        print "[RokuPlus ts-relay diag] segment_ready index="; segmentIndex+1; " bytes="; payloadSize; " downloadMs="; downloadMs
        failedStage = "chunk_size"
        rpTsRelaySendString(connection,rpTsRelayHex(payloadSize)+chr(13)+chr(10),server,connectionPort)
        if not server.sendOk
            endReason = "client_send_failed"
            DeleteFile(filePath)
            exit for
        end if
        failedStage = "segment_payload"
        rpTsRelaySendBytes(connection,payload,server,connectionPort)
        if not server.sendOk
            endReason = "client_send_failed"
            DeleteFile(filePath)
            exit for
        end if
        failedStage = "chunk_terminator"
        rpTsRelaySendString(connection,chr(13)+chr(10),server,connectionPort)
        if not server.sendOk
            endReason = "client_send_failed"
            DeleteFile(filePath)
            exit for
        end if
        sentSegments++
        sentBytes += payloadSize
        server.nextSegmentIndex = segmentIndex + 1
        server.segmentsSent = server.nextSegmentIndex
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
    print "[RokuPlus ts-relay diag] session_end reason="; endReason; " stage="; failedStage; " sentSegments="; sentSegments; " nextIndex="; server.nextSegmentIndex; " totalSegments="; segments.count(); " sentBytes="; sentBytes; " elapsedMs="; sessionTimer.TotalMilliseconds(); " socketStatus="; connection.status()
    connection.close()
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
