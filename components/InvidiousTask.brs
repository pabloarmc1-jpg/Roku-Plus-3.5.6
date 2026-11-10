' Invidious public API adapter. Network and JSON work run on a Task thread.
sub init()
    m.top.functionName = "runInvidiousRequest"
end sub

sub runInvidiousRequest()
    answer = {ok:false,requestId:m.top.requestId,items:[],message:"No se pudo consultar Invidious."}
    base = "https://yt.chocolatemoo53.com"
    if m.top.operation = "search"
        query = left(m.top.query.trim(),100)
        if query = ""
            answer.message = "Escribe algo para buscar."
        else
            endpoint = base + "/api/v1/search?q=" + CreateObject("roUrlTransfer").escape(query) + "&type=video&page=1&region=MX&hl=es"
            response = invidiousDownload(endpoint)
            if response.ok
                parsed = ParseJson(response.body)
                if type(parsed) = "roArray"
                    for each row in parsed
                        if type(row) = "roAssociativeArray" and row.doesExist("videoId")
                            id = row.videoId
                            title = row.title
                            author = ""
                            if row.doesExist("author") then author = row.author
                            if GetInterface(id,"ifString") <> invalid and id <> "" and GetInterface(title,"ifString") <> invalid
                                answer.items.push({id:id,title:left(title,180),author:left(author,100),kind:"movie",provider:"invidious",poster:"",background:""})
                            end if
                        end if
                        if answer.items.count() >= 10 then exit for
                    end for
                    answer.ok = true
                    answer.message = ""
                else
                    answer.message = "La instancia devolvió una respuesta de búsqueda no válida."
                end if
            else
                answer.message = response.message
            end if
        end if
    else if m.top.operation = "resolve"
        videoId = m.top.videoId
        if GetInterface(videoId,"ifString") = invalid or videoId = "" or len(videoId) > 20
            answer.message = "El identificador del video no es válido."
        else
            endpoint = base + "/api/v1/videos/" + videoId + "?local=true&region=MX&hl=es"
            response = invidiousDownload(endpoint)
            if response.ok
                parsed = ParseJson(response.body)
                selected = invidiousSelectStream(parsed)
                if selected <> invalid
                    answer.url = selected.url
                    answer.streamFormat = selected.streamFormat
                    if selected.doesExist("bitrate") then answer.bitrate = selected.bitrate
                    answer.ok = true
                    answer.message = ""
                else
                    answer.message = "Este video no ofrece un MP4 progresivo compatible con este Roku (H.264 AVC + AAC-LC). HLS, pistas separadas y códecs no identificados están deshabilitados."
                end if
            else
                answer.message = response.message
            end if
        end if
    end if
    if not m.top.cancelRequested then m.top.result = answer
end sub

function invidiousSelectStream(parsed as dynamic) as dynamic
    if type(parsed) <> "roAssociativeArray" then return invalid
    chosenUrl = ""
    chosenFormat = ""
    bestScore = -999999
    chosenBitrate = 0
    streams = invalid
    if parsed.doesExist("formatStreams") and type(parsed.formatStreams) = "roArray" then streams = parsed.formatStreams
    if type(streams) = "roArray"
        for each stream in streams
            if type(stream) <> "roAssociativeArray" then continue for
            if not stream.doesExist("url") or not stream.doesExist("container") then continue for
            streamUrl = stream.url
            if GetInterface(streamUrl,"ifString") = invalid or left(streamUrl,8) <> "https://" then continue for
            if lcase(stream.container) <> "mp4" then continue for
            streamType = ""
            if not stream.doesExist("type") then continue for
            if GetInterface(stream.type,"ifString") = invalid then continue for
            streamType = lcase(stream.type)
            ' Require explicit MP4 codecs: AVC Main/High + AAC-LC only.
            if instr(1,streamType,"video/mp4") = 0 then continue for
            codecInfo = invidiousParseMp4Codecs(streamType)
            if codecInfo = invalid then continue for
            ' Check the exact AVC profile/level against this Roku device.
            if not invidiousDeviceSupportsAvc(codecInfo.profile,codecInfo.level) then continue for
            score = 100
            qualityText = ""
            if stream.doesExist("qualityLabel") then qualityText = stream.qualityLabel
            if qualityText = "" and stream.doesExist("quality") then qualityText = stream.quality
            height = val(qualityText)
            if height = 0 and stream.doesExist("resolution")
                dimensions = stream.resolution.split("x")
                if dimensions.count() = 2 then height = val(dimensions[1])
            end if
            if height > 0
                if height > 720 then score = score - ((height - 720) / 10)
                else score = score + (height / 10)
            end if
            bitrateKbps = 0
            if stream.doesExist("bitrate") and stream.bitrate <> invalid
                rawBitrate = val(stream.bitrate.toStr())
                if rawBitrate > 0
                    if rawBitrate > 10000
                        bitrateKbps = int((rawBitrate + 999) / 1000)
                    else
                        bitrateKbps = int(rawBitrate)
                    end if
                end if
            end if
            ' Do not invent bitrate values: Roku requires a valid progressive stream bitrate.
            if bitrateKbps <= 0 then continue for
            if score > bestScore
                bestScore = score
                chosenUrl = streamUrl
                chosenFormat = "mp4"
                chosenBitrate = bitrateKbps
            end if
        end for
    end if
    if chosenUrl <> "" then return {url:chosenUrl,streamFormat:chosenFormat,bitrate:chosenBitrate}
    ' HLS is intentionally disabled. Only explicitly identified MP4 H.264 + AAC is accepted.
    return invalid
end function

' Parse only a progressive MP4 with an explicit AVC codec string and AAC-LC.
' AVC profile_idc and level_idc are read from the six hexadecimal digits in avc1.PPCCLL.
function invidiousParseMp4Codecs(streamType as string) as dynamic
    codecPos = instr(1,streamType,"codecs=")
    if codecPos = 0 then return invalid
    codecText = mid(streamType,codecPos+7)
    if left(codecText,1) = chr(34) then codecText = mid(codecText,2)
    quotePos = instr(1,codecText,chr(34))
    if quotePos > 0 then codecText = left(codecText,quotePos-1)
    codecList = codecText.split(",")
    if codecList.count() <> 2 then return invalid

    avcCodec = ""
    hasAacLc = false
    for each codecToken in codecList
        token = lcase(codecToken.trim())
        if left(token,5) = "avc1."
            if avcCodec <> "" then return invalid
            avcCodec = token
        else if token = "mp4a.40.2"
            if hasAacLc then return invalid
            hasAacLc = true
        else
            ' Reject HEVC, AV1, VP9, HE-AAC, Opus and every unknown codec.
            return invalid
        end if
    end for
    if avcCodec = "" or not hasAacLc then return invalid
    if len(avcCodec) <> 11 then return invalid

    profileId = invidiousHexValue(mid(avcCodec,6,2))
    levelId = invidiousHexValue(right(avcCodec,2))
    if profileId = 77
        profile = "main"
    else if profileId = 100
        profile = "high"
    else
        ' Roku's published AVC streaming profiles are Main and High.
        return invalid
    end if

    if levelId = 0 or levelId > 42 then return invalid
    level = invidiousAvcLevelName(levelId)
    if level = "" then return invalid
    return {profile:profile,level:level}
end function

function invidiousHexValue(value as string) as integer
    digits = "0123456789abcdef"
    result = 0
    for index = 1 to len(value)
        digit = instr(1,digits,lcase(mid(value,index,1))) - 1
        if digit < 0 then return -1
        result = (result * 16) + digit
    end for
    return result
end function

function invidiousAvcLevelName(levelId as integer) as string
    if levelId = 10 then return "1.0"
    if levelId = 11 then return "1.1"
    if levelId = 12 then return "1.2"
    if levelId = 13 then return "1.3"
    if levelId = 20 then return "2.0"
    if levelId = 21 then return "2.1"
    if levelId = 22 then return "2.2"
    if levelId = 30 then return "3.0"
    if levelId = 31 then return "3.1"
    if levelId = 32 then return "3.2"
    if levelId = 40 then return "4.0"
    if levelId = 41 then return "4.1"
    if levelId = 42 then return "4.2"
    return ""
end function

function invidiousDeviceSupportsAvc(profile as string, level as string) as boolean
    deviceInfo = CreateObject("roDeviceInfo")
    capability = deviceInfo.CanDecodeVideo({codec:"h264",profile:profile,level:level})
    if type(capability) = "roAssociativeArray" and capability.doesExist("result")
        if capability.result = true then return true
    end if
    ' Some Roku firmware reports AVC under the MPEG-4 AVC codec name.
    capability = deviceInfo.CanDecodeVideo({codec:"mpeg4 avc",profile:profile,level:level})
    if type(capability) = "roAssociativeArray" and capability.doesExist("result")
        if capability.result = true then return true
    end if
    return false
end function

function invidiousDownload(endpoint as string) as object
    reply = {ok:false,body:"",message:"No se pudo conectar con la instancia Invidious."}
    if m.top.cancelRequested then return reply
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.addHeader("User-Agent","RokuPlus/1.0")
    transfer.enableEncodings(true)
    transfer.setUrl(endpoint)
    fileSystem = CreateObject("roFileSystem")
    filename = "tmp:/rokuplus-invidious-" + CreateObject("roDeviceInfo").getRandomUUID() + ".json"
    if not transfer.asyncGetToFile(filename) then return reply
    elapsed = CreateObject("roTimespan")
    elapsed.mark()
    finished = false
    code = 0
    while not finished
        if m.top.cancelRequested then exit while
        if elapsed.totalMilliseconds() >= 20000 then exit while
        info = fileSystem.stat(filename)
        if type(info) = "roAssociativeArray" and info.doesExist("size")
            if info.size > 2097152 then exit while
        end if
        event = wait(50,port)
        if type(event) = "roUrlEvent" and event.getSourceIdentity() = transfer.getIdentity() and event.getInt() = 1
            code = event.getResponseCode()
            finished = true
        end if
    end while
    if not finished then transfer.asyncCancel()
    if finished and code = 200 and not m.top.cancelRequested
        info = fileSystem.stat(filename)
        if type(info) = "roAssociativeArray" and info.doesExist("size") and info.size > 0 and info.size <= 2097152
            reply.body = ReadAsciiFile(filename)
            if reply.body <> "" then reply.ok = true
        else
            reply.message = "La respuesta de Invidious está vacía o supera el límite permitido."
        end if
    else if finished
        reply.message = "Invidious respondió con HTTP " + code.toStr() + "."
    else
        reply.message = "La instancia Invidious tardó demasiado."
    end if
    fileSystem.delete(filename)
    return reply
end function
