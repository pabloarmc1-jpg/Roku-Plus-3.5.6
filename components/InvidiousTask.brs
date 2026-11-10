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
                    answer.ok = true
                    answer.message = ""
                else
                    answer.message = "La instancia no entregó un MP4 o HLS reproducible para este video. Prueba otro resultado."
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
            if stream.doesExist("type") then streamType = lcase(stream.type)
            if streamType <> "" and instr(1,streamType,"video/mp4") = 0 then continue for
            score = 100
            if instr(1,streamType,"avc1") > 0 then score = score + 35
            if instr(1,streamType,"mp4a") > 0 then score = score + 30
            if instr(1,streamType,"av01") > 0 or instr(1,streamType,"vp09") > 0 then score = score - 100
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
            if stream.doesExist("bitrate")
                rawBitrate = val(stream.bitrate)
                if rawBitrate > 0
                    if rawBitrate > 10000
                        bitrateKbps = int((rawBitrate + 999) / 1000)
                    else
                        bitrateKbps = int(rawBitrate)
                    end if
                end if
            end if
            ' Roku needs a positive bitrate for progressive MP4 metadata.
            if bitrateKbps <= 0
                if height >= 720
                    bitrateKbps = 2500
                else if height >= 480
                    bitrateKbps = 1400
                else
                    bitrateKbps = 800
                end if
            end if
            if score > bestScore
                bestScore = score
                chosenUrl = streamUrl
                chosenFormat = "mp4"
                chosenBitrate = bitrateKbps
            end if
        end for
    end if
    if chosenUrl <> "" then return {url:chosenUrl,streamFormat:chosenFormat,bitrate:chosenBitrate}
    ' HLS is a useful fallback for live streams when the instance exposes it.
    if parsed.doesExist("hlsUrl")
        hlsUrl = parsed.hlsUrl
        if GetInterface(hlsUrl,"ifString") <> invalid and left(hlsUrl,8) = "https://"
            return {url:hlsUrl,streamFormat:"hls"}
        end if
    end if
    return invalid
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
