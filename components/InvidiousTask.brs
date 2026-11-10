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
                    answer.message = "No se encontró una pista progresiva multiplexada compatible con los decodificadores de este Roku. Las pistas adaptativas separadas se registraron, pero no se pueden combinar sin multiplexación."
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
    invidiousLogDeviceInfo()
    invidiousLogAdaptiveFormats(parsed)

    chosenUrl = ""
    chosenFormat = ""
    chosenVideoCodec = ""
    chosenAudioCodec = ""
    bestScore = -999999
    chosenBitrate = 0
    streams = invalid
    if parsed.doesExist("formatStreams") and type(parsed.formatStreams) = "roArray" then streams = parsed.formatStreams

    if type(streams) = "roArray"
        for each stream in streams
            if type(stream) <> "roAssociativeArray" then continue for
            container = ""
            if stream.doesExist("container") and GetInterface(stream.container,"ifString") <> invalid
                container = lcase(stream.container)
            end if
            streamUrl = ""
            if stream.doesExist("url") and GetInterface(stream.url,"ifString") <> invalid then streamUrl = stream.url
            streamType = ""
            if stream.doesExist("type") and GetInterface(stream.type,"ifString") <> invalid
                streamType = lcase(stream.type)
            end if
            codecTokens = invidiousParseCodecTokens(streamType)
            if codecTokens = invalid
                print "[RokuPlus Invidious codecs] FORMAT_REJECT container="; container; " reason=missing_explicit_codecs type="; left(streamType,180)
                continue for
            end if
            if left(streamUrl,8) <> "https://"
                print "[RokuPlus Invidious codecs] FORMAT_REJECT container="; container; " reason=non_https_url"
                continue for
            end if
            if container <> "mp4" and container <> "webm" and container <> "mkv"
                print "[RokuPlus Invidious codecs] FORMAT_REJECT container="; container; " reason=unsupported_container"
                continue for
            end if

            videoInfo = invalid
            audioInfo = invalid
            for each token in codecTokens
                parsedVideo = invidiousClassifyVideoCodec(token)
                if parsedVideo <> invalid then videoInfo = parsedVideo
                parsedAudio = invidiousClassifyAudioCodec(token)
                if parsedAudio <> invalid then audioInfo = parsedAudio
            end for
            if videoInfo = invalid or audioInfo = invalid
                print "[RokuPlus Invidious codecs] FORMAT_REJECT container="; container; " codecs="; invidiousJoin(codecTokens); " reason=not_a_muxed_supported_av_pair"
                continue for
            end if

            videoAllowed = invidiousContainerAllowsVideo(container,videoInfo.name)
            audioAllowed = invidiousContainerAllowsAudio(container,audioInfo.name)
            videoOk = false
            audioOk = false
            if videoInfo.name = "av1"
                videoOk = invidiousDeviceSupportsVideo(videoInfo)
            else if videoAllowed
                videoOk = invidiousDeviceSupportsVideo(videoInfo)
            end if
            if audioAllowed then audioOk = invidiousDeviceSupportsAudio(audioInfo)
            print "[RokuPlus Invidious codecs] FORMAT container="; container; " video="; videoInfo.name; " videoDevice="; videoOk; " audio="; audioInfo.name; " audioDevice="; audioOk

            if not videoAllowed or not audioAllowed or not videoOk or not audioOk
                print "[RokuPlus Invidious codecs] FORMAT_REJECT reason=container_or_device_capability"
                continue for
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
            if bitrateKbps <= 0
                print "[RokuPlus Invidious codecs] FORMAT_REJECT reason=missing_bitrate"
                continue for
            end if

            score = 100
            qualityText = ""
            if stream.doesExist("qualityLabel") and GetInterface(stream.qualityLabel,"ifString") <> invalid then qualityText = stream.qualityLabel
            if qualityText = "" and stream.doesExist("quality") and GetInterface(stream.quality,"ifString") <> invalid then qualityText = stream.quality
            height = val(qualityText)
            if height = 0 and stream.doesExist("resolution") and GetInterface(stream.resolution,"ifString") <> invalid
                dimensions = stream.resolution.split("x")
                if dimensions.count() = 2 then height = val(dimensions[1])
            end if
            if height > 0
                if height > 1080 then score = score - ((height - 1080) / 10)
                else score = score + (height / 10)
            end if
            if score > bestScore
                bestScore = score
                chosenUrl = streamUrl
                chosenFormat = container
                chosenBitrate = bitrateKbps
                chosenVideoCodec = videoInfo.name
                chosenAudioCodec = audioInfo.name
            end if
        end for
    end if

    if chosenUrl <> ""
        print "[RokuPlus Invidious codecs] SELECTED container="; chosenFormat; " video="; chosenVideoCodec; " audio="; chosenAudioCodec; " bitrateKbps="; chosenBitrate
        return {url:chosenUrl,streamFormat:chosenFormat,bitrate:chosenBitrate,videoCodec:chosenVideoCodec,audioCodec:chosenAudioCodec}
    end if
    print "[RokuPlus Invidious codecs] RESULT no_compatible_progressive_muxed_stream"
    return invalid
end function

function invidiousParseCodecTokens(streamType as string) as dynamic
    codecPos = instr(1,streamType,"codecs=")
    if codecPos = 0 then return invalid
    codecText = mid(streamType,codecPos+7)
    if left(codecText,1) = chr(34) then codecText = mid(codecText,2)
    quotePos = instr(1,codecText,chr(34))
    if quotePos > 0 then codecText = left(codecText,quotePos-1)
    tokens = codecText.split(",")
    if tokens.count() < 1 then return invalid
    clean = []
    for each token in tokens
        value = lcase(token.trim())
        if value = "" then return invalid
        clean.push(value)
    end for
    return clean
end function

function invidiousClassifyVideoCodec(token as string) as dynamic
    if left(token,5) = "avc1." or left(token,5) = "avc3."
        if len(token) <> 11 then return invalid
        profileId = invidiousHexValue(mid(token,6,2))
        levelId = invidiousHexValue(right(token,2))
        if profileId = 66
            profile = "baseline"
        else if profileId = 77
            profile = "main"
        else if profileId = 100
            profile = "high"
        else
            return invalid
        end if
        level = invidiousAvcLevelName(levelId)
        if level = "" then return invalid
        return {name:"avc",codec:"mpeg4 avc",profile:profile,level:level}
    end if
    if left(token,5) = "hvc1." or left(token,5) = "hev1."
        parts = token.split(".")
        if parts.count() < 4 then return invalid
        profileId = val(parts[1])
        if profileId = 1
            profile = "main"
        else if profileId = 2
            profile = "main 10"
        else
            return invalid
        end if
        levelToken = parts[3]
        if left(levelToken,1) <> "l" and left(levelToken,1) <> "h" then return invalid
        levelCode = val(mid(levelToken,2))
        level = invidiousHevcLevelName(levelCode)
        if level = "" then return invalid
        return {name:"hevc",codec:"hevc",profile:profile,level:level}
    end if
    if left(token,5) = "av01."
        return {name:"av1",codec:"av1",profile:"main",level:"5.1",dashOnly:true}
    end if
    if left(token,4) = "vp09" or left(token,3) = "vp8" then return {name:"vp9",codec:"vp9",unsupported:true}
    return invalid
end function

function invidiousClassifyAudioCodec(token as string) as dynamic
    if left(token,6) = "mp4a.4" then return {name:"aac",codec:"aac"}
    if token = "ac-3" or token = "dac3" then return {name:"ac3",codec:"ac3"}
    if token = "ec-3" or token = "dec3" then return {name:"eac3",codec:"eac3"}
    if token = "ac-4" then return {name:"ac4",codec:"ac4"}
    if token = "alac" then return {name:"alac",codec:"alac"}
    if token = "mp3" or token = "mp4a.69" or token = "mp4a.6b" then return {name:"mp3",codec:"mp3"}
    if token = "lpcm" or token = "sowt" or token = "twos" or token = "pcm" then return {name:"pcm",codec:"pcm"}
    if token = "opus" then return {name:"opus",codec:"opus"}
    if token = "vorbis" then return {name:"vorbis",codec:"vorbis"}
    if token = "flac" then return {name:"flac",codec:"flac"}
    if token = "dts" then return {name:"dts",codec:"dts"}
    if token = "dtse" then return {name:"dtse",codec:"dtse"}
    return invalid
end function

function invidiousContainerAllowsVideo(container as string, codecName as string) as boolean
    if container <> "mp4" and container <> "mkv" and container <> "webm" then return false
    return codecName = "avc" or codecName = "hevc"
end function

function invidiousContainerAllowsAudio(container as string, codecName as string) as boolean
    if container = "mp4"
        return codecName = "aac" or codecName = "ac3" or codecName = "eac3" or codecName = "ac4" or codecName = "alac" or codecName = "mp3" or codecName = "pcm"
    end if
    if container = "mkv" or container = "webm"
        return codecName = "aac" or codecName = "ac3" or codecName = "eac3" or codecName = "alac" or codecName = "mp3" or codecName = "pcm" or codecName = "opus" or codecName = "vorbis" or codecName = "flac" or codecName = "dts" or codecName = "dtse"
    end if
    return false
end function

function invidiousDeviceSupportsVideo(info as object) as boolean
    deviceInfo = CreateObject("roDeviceInfo")
    capability = deviceInfo.CanDecodeVideo({codec:info.codec,profile:info.profile,level:info.level})
    if type(capability) = "roAssociativeArray" and capability.doesExist("result")
        return capability.result = true
    end if
    return false
end function

function invidiousDeviceSupportsAudio(info as object) as boolean
    deviceInfo = CreateObject("roDeviceInfo")
    capability = deviceInfo.CanDecodeAudio({codec:info.codec})
    if type(capability) = "roAssociativeArray" and capability.doesExist("result")
        return capability.result = true
    end if
    return false
end function

function invidiousHevcLevelName(levelCode as integer) as string
    if levelCode = 30 then return "1.0"
    if levelCode = 60 then return "2.0"
    if levelCode = 63 then return "2.1"
    if levelCode = 90 then return "3.0"
    if levelCode = 93 then return "3.1"
    if levelCode = 120 then return "4.0"
    if levelCode = 123 then return "4.1"
    if levelCode = 150 then return "5.0"
    if levelCode = 153 then return "5.1"
    if levelCode = 156 then return "5.2"
    if levelCode = 180 then return "6.0"
    if levelCode = 183 then return "6.1"
    if levelCode = 186 then return "6.2"
    return ""
end function

function invidiousLogDeviceInfo()
    deviceInfo = CreateObject("roDeviceInfo")
    model = deviceInfo.GetModel()
    osVersion = deviceInfo.GetOSVersion()
    osText = ""
    if type(osVersion) = "roAssociativeArray"
        if osVersion.doesExist("major") then osText = osVersion.major.toStr()
        if osVersion.doesExist("minor") then osText = osText + "." + osVersion.minor.toStr()
    end if
    print "[RokuPlus Invidious codecs] DEVICE model="; model; " os="; osText
    candidates = [
        {name:"avc-main",codec:"mpeg4 avc",profile:"main",level:"4.2"},
        {name:"avc-high",codec:"mpeg4 avc",profile:"high",level:"4.2"},
        {name:"hevc-main",codec:"hevc",profile:"main",level:"5.1"},
        {name:"hevc-main10",codec:"hevc",profile:"main 10",level:"5.1"},
        {name:"av1-main",codec:"av1",profile:"main",level:"5.1"}
    ]
    for each candidate in candidates
        result = deviceInfo.CanDecodeVideo({codec:candidate.codec,profile:candidate.profile,level:candidate.level})
        supported = type(result) = "roAssociativeArray" and result.doesExist("result") and result.result = true
        print "[RokuPlus Invidious codecs] PROBE_VIDEO name="; candidate.name; " supported="; supported
    end for
    audioCandidates = ["aac","ac3","eac3","ac4","alac","mp3","pcm","opus","vorbis","flac","dts","dtse"]
    for each audioCodec in audioCandidates
        result = deviceInfo.CanDecodeAudio({codec:audioCodec})
        supported = type(result) = "roAssociativeArray" and result.doesExist("result") and result.result = true
        print "[RokuPlus Invidious codecs] PROBE_AUDIO codec="; audioCodec; " supported="; supported
    end for
end function

sub invidiousLogAdaptiveFormats(parsed as object)
    if not parsed.doesExist("adaptiveFormats") or type(parsed.adaptiveFormats) <> "roArray" then return
    for each stream in parsed.adaptiveFormats
        if type(stream) <> "roAssociativeArray" then continue for
        container = ""
        if stream.doesExist("container") then container = lcase(invidiousTextValue(stream.container,24))
        streamType = ""
        if stream.doesExist("type") then streamType = lcase(invidiousTextValue(stream.type,200))
        tokens = invidiousParseCodecTokens(streamType)
        codecLabel = "unknown"
        if tokens <> invalid
            codecLabel = invidiousJoin(tokens)
            for each token in tokens
                videoInfo = invidiousClassifyVideoCodec(token)
                if videoInfo <> invalid
                    deviceOk = invidiousDeviceSupportsVideo(videoInfo)
                    transport = "PROGRESSIVE_CAPABILITY_ONLY"
                    if videoInfo.name = "av1" then transport = "DASH_ONLY"
                    if videoInfo.name = "vp9" then transport = "NOT_LISTED_BY_ROKU"
                    print "[RokuPlus Invidious codecs] ADAPTIVE_VIDEO codec="; videoInfo.name; " deviceCanDecode="; deviceOk; " transport="; transport
                end if
                audioInfo = invidiousClassifyAudioCodec(token)
                if audioInfo <> invalid
                    audioOk = invidiousDeviceSupportsAudio(audioInfo)
                    print "[RokuPlus Invidious codecs] ADAPTIVE_AUDIO codec="; audioInfo.name; " deviceCanDecode="; audioOk
                end if
            end for
        end if
        print "[RokuPlus Invidious codecs] ADAPTIVE_TRACK container="; container; " codecs="; codecLabel; " action=separate_track_not_muxed"
    end for
end sub

function invidiousJoin(values as object) as string
    result = ""
    for each value in values
        if result <> "" then result = result + ","
        result = result + value
    end for
    return result
end function

function invidiousTextValue(value as dynamic, limit as integer) as string
    if value = invalid then return ""
    if GetInterface(value,"ifString") <> invalid then return left(value,limit)
    return left(value.toStr(),limit)
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
