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
    startIndex = server.nextSegmentIndex
    if GetInterface(startIndex,"ifInt") = invalid or startIndex < 0 then startIndex = 0
    if requestedIndex >= 0 then startIndex = requestedIndex
    print "[RokuPlus ts-relay] stream_start segment="; startIndex
    for segmentIndex = startIndex to segments.count() - 1
        if server.stopRequested then exit for
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
        code = xfer.GetToFile(filePath)
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
        ' Deep packet inspection is diagnostic, not part of forwarding. Sample it
        ' periodically; always inspect a segment with an invalid TS packet length.
        auditDue = sentSegments < 3 or (sentSegments mod 25) = 0 or (payloadSize mod 188) <> 0
        if auditDue
            tsAudit = rpTsRelayAuditPayload(payload)
            if not tsAudit.aligned or tsAudit.syncErrors > 0 or tsAudit.patPackets = 0 or tsAudit.continuityErrors > 0 or tsAudit.pmtPackets > 0
                print "[RokuPlus ts-audit] segment="; segmentIndex; " bytes="; payloadSize; " packets="; tsAudit.packetCount; " aligned="; tsAudit.aligned; " syncErrors="; tsAudit.syncErrors; " firstBad="; tsAudit.firstBadOffset
                print "[RokuPlus ts-audit] pat="; tsAudit.patPackets; " null="; tsAudit.nullPackets; " ccChecked="; tsAudit.continuityChecked; " ccErrors="; tsAudit.continuityErrors
                print "[RokuPlus ts-audit] pmtPid="; tsAudit.pmtPid; " pmt="; tsAudit.pmtPackets; " videoPid="; tsAudit.videoPid; " h264="; tsAudit.h264; " audioPid="; tsAudit.audioPid; " aac="; tsAudit.aac
                print "[RokuPlus ts-audit] idr="; tsAudit.idrCount; " firstIdrPacket="; tsAudit.firstIdrPacket; " sps="; tsAudit.sps; " pps="; tsAudit.pps
                print "[RokuPlus ts-audit] ptsCount="; tsAudit.ptsCount; " firstPts90k="; tsAudit.firstPts; " lastPts90k="; tsAudit.lastPts
                print "[RokuPlus ts-clock] pcrCount="; tsAudit.pcrCount; " firstPcr90k="; tsAudit.firstPcr; " lastPcr90k="; tsAudit.lastPcr
                print "[RokuPlus ts-clock] dtsCount="; tsAudit.dtsCount; " firstDts90k="; tsAudit.firstDts; " lastDts90k="; tsAudit.lastDts
            else if sentSegments mod 25 = 0
                print "[RokuPlus ts-audit] segment="; segmentIndex; " bytes="; payloadSize; " packets="; tsAudit.packetCount; " pat="; tsAudit.patPackets; " null="; tsAudit.nullPackets; " ccChecked="; tsAudit.continuityChecked
                print "[RokuPlus ts-audit] ccErrors="; tsAudit.continuityErrors; " pmtPid="; tsAudit.pmtPid; " pmt="; tsAudit.pmtPackets; " videoPid="; tsAudit.videoPid; " h264="; tsAudit.h264; " audioPid="; tsAudit.audioPid; " aac="; tsAudit.aac
                print "[RokuPlus ts-audit] idr="; tsAudit.idrCount; " firstIdrPacket="; tsAudit.firstIdrPacket; " sps="; tsAudit.sps; " pps="; tsAudit.pps
                print "[RokuPlus ts-audit] ptsCount="; tsAudit.ptsCount; " firstPts90k="; tsAudit.firstPts; " lastPts90k="; tsAudit.lastPts
                print "[RokuPlus ts-clock] pcrCount="; tsAudit.pcrCount; " firstPcr90k="; tsAudit.firstPcr; " lastPcr90k="; tsAudit.lastPcr
                print "[RokuPlus ts-clock] dtsCount="; tsAudit.dtsCount; " firstDts90k="; tsAudit.firstDts; " lastDts90k="; tsAudit.lastDts
            end if
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

' Read-only MPEG-TS packet audit. The payload is forwarded unchanged.
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
    result.pmtPid = -1
    result.pmtPackets = 0
    result.videoPid = -1
    result.audioPid = -1
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
    result.firstPcr = -1
    result.lastPcr = -1
    result.dtsCount = 0
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
                    if adaptationFlags >= 128 then discontinuity = true
                    if adaptationLength >= 7 and (adaptationFlags mod 32) >= 16
                        pcrBase = payload[offset+6] * 33554432 + payload[offset+7] * 131072 + payload[offset+8] * 512 + payload[offset+9] * 2 + (payload[offset+10] \ 128)
                        pcrExtension = (payload[offset+10] mod 2) * 256 + payload[offset+11]
                        pcrValue = pcrBase + pcrExtension / 300.0
                        if result.pcrCount = 0 then result.firstPcr = pcrValue
                        result.lastPcr = pcrValue
                        result.pcrCount++
                    end if
                end if
            end if
            if hasPayload and pid <> 8191
                key = pid.toStr()
                if haveCounters[key] = true
                    result.continuityChecked++
                    expected = (lastCounters[key] + 1) mod 16
                    if continuity <> expected and not discontinuity
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
                    if pid = 0
                        pointer = payload[payloadStart]
                        sectionStart = payloadStart + 1 + pointer
                        if sectionStart + 12 <= offset + 188 and payload[sectionStart] = 0
                            sectionLength = (payload[sectionStart+1] mod 16) * 256 + payload[sectionStart+2]
                            sectionEnd = sectionStart + 3 + sectionLength
                            if sectionEnd <= offset + 188
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
                    else if pid = result.pmtPid
                        pointer = payload[payloadStart]
                        sectionStart = payloadStart + 1 + pointer
                        if sectionStart + 12 <= offset + 188 and payload[sectionStart] = 2
                            sectionLength = (payload[sectionStart+1] mod 16) * 256 + payload[sectionStart+2]
                            sectionEnd = sectionStart + 3 + sectionLength
                            if sectionEnd <= offset + 188
                                result.pmtPackets++
                                programInfoLength = (payload[sectionStart+10] mod 16) * 256 + payload[sectionStart+11]
                                entry = sectionStart + 12 + programInfoLength
                                while entry + 5 <= sectionEnd - 4
                                    streamType = payload[entry]
                                    elementaryPid = (payload[entry+1] mod 32) * 256 + payload[entry+2]
                                    esInfoLength = (payload[entry+3] mod 16) * 256 + payload[entry+4]
                                    if streamType = 27
                                        result.h264 = true
                                        result.videoPid = elementaryPid
                                    else if streamType = 15 or streamType = 17
                                        result.aac = true
                                        result.audioPid = elementaryPid
                                    end if
                                    entry += 5 + esInfoLength
                                end while
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
                                if (pesFlags = 2 or pesFlags = 3) and pesHeaderLength >= 5
                                    if payloadStart + 14 <= offset + 188
                                        pts = rpTsRelayReadPts(payload,payloadStart+9)
                                        if pts >= 0
                                            if result.ptsCount = 0 then result.firstPts = pts
                                            result.lastPts = pts
                                            result.ptsCount++
                                        end if
                                    end if
                                    if pesFlags = 3 and pesHeaderLength >= 10 and payloadStart + 19 <= offset + 188
                                        dts = rpTsRelayReadPts(payload,payloadStart+14)
                                        if dts >= 0
                                            if result.dtsCount = 0 then result.firstDts = dts
                                            result.lastDts = dts
                                            result.dtsCount++
                                        end if
                                    end if
                                end if
                                dataStart = payloadStart + 9 + pesHeaderLength
                            end if
                        end if
                    end if
                    if dataStart < offset + 188
                        for nalOffset = dataStart to offset + 183
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

function rpTsRelayReadPts(payload as object, offset as integer) as dynamic
    if offset < 0 or offset + 4 >= payload.Count() then return -1
    b0 = payload[offset]
    b1 = payload[offset+1]
    b2 = payload[offset+2]
    b3 = payload[offset+3]
    b4 = payload[offset+4]
    return (b0 mod 16) * 536870912 + b1 * 4194304 + (b2 \ 4) * 32768 + b3 * 128 + (b4 \ 2)
end function
