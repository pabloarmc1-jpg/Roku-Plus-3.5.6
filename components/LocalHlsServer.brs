' Local-only HTTP endpoint for one rewritten VOD HLS media playlist.
' The native Video node still downloads the original HTTPS TS segments.
sub init()
    m.top.functionName = "runLocalHlsServer"
end sub

sub runLocalHlsServer()
    port = CreateObject("roMessagePort")
    listener = CreateObject("roStreamSocket")
    listener.setMessagePort(port)
    address = CreateObject("roSocketAddress")
    if not address.setAddress("127.0.0.1:49321")
        m.top.status = "address_error"
        print "[RokuPlus local-hls] server_failed stage=address"
        return
    end if
    if not listener.setAddress(address)
        m.top.status = "bind_error"
        print "[RokuPlus local-hls] server_failed stage=bind"
        return
    end if
    listener.notifyReadable(true)
    if not listener.listen(4)
        m.top.status = "listen_error"
        print "[RokuPlus local-hls] server_failed stage=listen"
        listener.close()
        return
    end if
    m.top.status = "listening"
    print "[RokuPlus local-hls] listen address=127.0.0.1:49321"
    while true
        event = wait(0,port)
        if type(event) = "roSocketEvent"
            if event.getSocketID() = listener.getID() and listener.isReadable()
                connection = listener.accept()
                if connection <> invalid then rpLocalHlsServeConnection(connection,m.top)
            end if
        end if
    end while
end sub

sub rpLocalHlsServeConnection(connection as object, server as object)
    request = ""
    requestComplete = false
    while len(request) < 8192 and not requestComplete
        chunk = connection.receiveStr(2048)
        if chunk = "" then exit while
        request += chunk
        if instr(1,request,chr(13)+chr(10)+chr(13)+chr(10)) > 0 then requestComplete = true
    end while
    if not requestComplete
        connection.close()
        return
    end if
    firstLine = request.split(chr(10))[0].trim()
    parts = firstLine.split(" ")
    path = ""
    if parts.count() >= 2
        path = parts[1]
        queryAt = instr(1,path,"?")
        if queryAt > 0 then path = left(path,queryAt-1)
    end if
    print "[RokuPlus local-hls] request path="; path
    body = ""
    statusLine = "200 OK"
    contentType = "application/vnd.apple.mpegurl"
    if path = "/index.m3u8"
        body = server.playlist
        if GetInterface(body,"ifString") = invalid or len(body) = 0
            statusLine = "503 Service Unavailable"
            body = "Playlist not ready" + chr(10)
            contentType = "text/plain"
        end if
    else
        statusLine = "404 Not Found"
        body = "Not found" + chr(10)
        contentType = "text/plain"
    end if
    response = "HTTP/1.1 " + statusLine + chr(13)+chr(10)
    response += "Content-Type: " + contentType + chr(13)+chr(10)
    response += "Content-Length: " + len(body).toStr() + chr(13)+chr(10)
    response += "Cache-Control: no-store" + chr(13)+chr(10)
    response += "Connection: close" + chr(13)+chr(10)+chr(13)+chr(10)
    response += body
    sent = 0
    while sent < len(response)
        count = connection.sendStr(mid(response,sent+1))
        if count <= 0 then exit while
        sent += count
    end while
    print "[RokuPlus local-hls] served status="; statusLine; " bytes="; len(body); " sent="; sent
    connection.close()
end sub
