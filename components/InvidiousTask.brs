' Roku Plus Invidious API task.
' Uses the public Invidious API for search and supported MP4 stream metadata.
' Only progressive MP4 formats are passed to the native Roku Video node.
sub init()
    m.top.functionName = "runInvidiousRequest"
end sub

sub runInvidiousRequest()
    answer = {ok:false,operation:m.top.operation,items:[],message:"No se pudo consultar Invidious."}
    if m.top.cancelRequested then return

    base = invidiousText(m.top.instance,256)
    if base = "" then base = "https://yt.chocolatemoo53.com"
    while right(base,1) = "/"
        base = left(base,len(base)-1)
    end while
    if left(lcase(base),8) <> "https://"
        answer.message = "El servidor Invidious debe usar HTTPS."
        m.top.result = answer
        return
    end if

    operation = m.top.operation
    endpoint = ""
    if operation = "search"
        query = invidiousText(m.top.query,160)
        if query = ""
            answer.message = "Escribe un término de búsqueda."
            m.top.result = answer
            return
        end if
        maxResults = m.top.maxResults
        if GetInterface(maxResults,"ifInt") = invalid then maxResults = 10
        if maxResults < 1 then maxResults = 1
        if maxResults > 20 then maxResults = 20
        encoder = CreateObject("roUrlTransfer")
        endpoint = base + "/api/v1/search?q=" + encoder.escape(query) + "&type=video&page=1&region=MX&hl=es"
    else if operation = "video"
        videoId = invidiousText(m.top.videoId,32)
        if videoId = "" or len(videoId) < 6
            answer.message = "El identificador del video no es válido."
            m.top.result = answer
            return
        end if
        for i = 1 to len(videoId)
            ch = mid(videoId,i,1)
            if instr(1,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-",ch) = 0
                answer.message = "El identificador del video no es válido."
                m.top.result = answer
                return
            end if
        end for
        ' local=true asks Invidious to proxy the media URL through its instance.
        endpoint = base + "/api/v1/videos/" + videoId + "?local=true&region=MX&hl=es"
    else
        answer.message = "La operación de Invidious no es válida."
        m.top.result = answer
        return
    end if

    print "[RokuPlus Invidious] request_start operation="; operation
    response = invidiousGet(endpoint)
    if response.cancelled then return
    if not response.ok
        answer.message = response.message
        m.top.result = answer
        print "[RokuPlus Invidious] request_failed operation="; operation; " code="; response.code
        return
    end if
    body = response.body
    print "[RokuPlus Invidious] response operation="; operation; " status="; response.code; " ms="; response.elapsed; " bytes="; len(body)
    if len(body) > 4194304
        answer.message = "La respuesta de Invidious supera el límite permitido."
        m.top.result = answer
        return
    end if

    payload = ParseJson(body)
    if operation = "search"
        if type(payload) <> "roArray"
            answer.message = "Invidious devolvió una respuesta de búsqueda no válida."
            m.top.result = answer
            return
        end if
        for each entry in payload
            if m.top.cancelRequested then return
            if type(entry) <> "roAssociativeArray" then continue for
            if GetInterface(entry.type,"ifString") <> invalid
                if entry.type <> "video" then continue for
            end if
            videoId = invidiousText(entry.videoId,32)
            title = invidiousText(entry.title,300)
            if videoId = "" or title = "" then continue for
            thumbnail = invidiousThumbnail(entry.videoThumbnails)
            author = invidiousText(entry.author,160)
            description = invidiousText(entry.description,600)
            published = invidiousText(entry.publishedText,80)
            duration = 0
            if GetInterface(entry.lengthSeconds,"ifInt") <> invalid then duration = entry.lengthSeconds
            answer.items.push({
                id:videoId,
                title:title,
                channelTitle:author,
                description:description,
                thumbnail:thumbnail,
                publishedAt:published,
                duration:duration,
                watchUrl:base+"/watch?v="+videoId,
                streamUrl:"",
                streamFormat:"",
                playbackMessage:""
            })
            if answer.items.count() >= maxResults then exit for
        end for
        answer.ok = true
        if answer.items.count() = 0 then answer.message = "No se encontraron videos para esa búsqueda." else answer.message = ""
        m.top.result = answer
        print "[RokuPlus Invidious] search_items="; answer.items.count()
        return
    end if

    if type(payload) <> "roAssociativeArray"
        answer.message = "Invidious devolvió detalles de video no válidos."
        m.top.result = answer
        return
    end if
    videoId = invidiousText(payload.videoId,32)
    if videoId = "" then videoId = invidiousText(m.top.videoId,32)
    title = invidiousText(payload.title,300)
    if title = "" then title = "Video de YouTube"
    item = {
        id:videoId,
        title:title,
        channelTitle:invidiousText(payload.author,160),
        description:invidiousText(payload.description,1200),
        thumbnail:invidiousThumbnail(payload.videoThumbnails),
        publishedAt:invidiousText(payload.publishedText,80),
        duration:0,
        watchUrl:base+"/watch?v="+videoId,
        streamUrl:"",
        streamFormat:"",
        playbackMessage:""
    }
    if GetInterface(payload.lengthSeconds,"ifInt") <> invalid then item.duration = payload.lengthSeconds

    bestUrl = ""
    bestHeight = -1
    if type(payload.formatStreams) = "roArray"
        for each stream in payload.formatStreams
            if m.top.cancelRequested then return
            if type(stream) <> "roAssociativeArray" then continue for
            container = lcase(invidiousText(stream.container,16))
            mime = lcase(invidiousText(stream.type,120))
            if container <> "mp4" and left(mime,9) <> "video/mp4" then continue for
            if GetInterface(stream.url,"ifString") = invalid then continue for
            streamUrl = stream.url.trim()
            if left(lcase(streamUrl),8) <> "https://" and left(lcase(streamUrl),7) <> "http://" then continue for
            height = 0
            resolution = invidiousText(stream.resolution,32)
            separator = instr(1,resolution,"x")
            if separator > 0 then height = val(mid(resolution,separator+1))
            qualityLabel = invidiousText(stream.qualityLabel,24)
            if height = 0
                p = instr(1,lcase(qualityLabel),"p")
                if p > 1 then height = val(left(qualityLabel,p-1))
            end if
            if height > 1080 then continue for
            if height > bestHeight
                bestHeight = height
                bestUrl = streamUrl
            end if
        end for
    end if
    if bestUrl <> ""
        item.streamUrl = bestUrl
        item.streamFormat = "mp4"
        item.playbackMessage = "MP4 compatible disponible · pulsa OK para reproducir."
    else
        item.playbackMessage = "El servidor no ofreció un formato MP4 compatible. Prueba otro video o servidor."
    end if
    answer.item = item
    answer.ok = true
    answer.message = item.playbackMessage
    m.top.result = answer
    print "[RokuPlus Invidious] video_ready id="; videoId; " mp4="; (bestUrl <> "")
end sub

function invidiousGet(url as string) as object
    result = {ok:false,cancelled:false,code:0,body:"",elapsed:0,message:"No hubo conexión con Invidious."}
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.setUrl(url)
    transfer.setTimeout(20000)
    transfer.addHeader("User-Agent","RokuPlus/Invidious")
    transfer.addHeader("Accept","application/json")
    if m.top.cancelRequested
        result.cancelled = true
        return result
    end if
    started = transfer.asyncGetToString()
    if not started
        result.message = "No se pudo iniciar la conexión con Invidious."
        return result
    end if
    finished = false
    elapsed = CreateObject("roTimespan")
    elapsed.mark()
    while not finished
        if m.top.cancelRequested
            transfer.asyncCancel()
            result.cancelled = true
            return result
        end if
        if elapsed.totalMilliseconds() >= 20000 then exit while
        event = wait(50,port)
        if type(event) = "roUrlEvent"
            if event.getSourceIdentity() = transfer.getIdentity()
                result.code = event.getResponseCode()
                result.body = event.getString()
                finished = true
            end if
        end if
    end while
    result.elapsed = elapsed.totalMilliseconds()
    if not finished
        transfer.asyncCancel()
        result.message = "Invidious tardó demasiado en responder. Inténtalo de nuevo."
        return result
    end if
    if result.code <> 200
        if result.code = 403 or result.code = 429
            result.message = "Invidious limitó la solicitud. Espera un momento o cambia de instancia."
        else if result.code = 404
            result.message = "El video o el endpoint no está disponible en esta instancia."
        else
            result.message = "Invidious respondió con el código " + result.code.toStr() + "."
        end if
        return result
    end if
    if result.body = ""
        result.message = "Invidious devolvió una respuesta vacía."
        return result
    end if
    result.ok = true
    result.message = ""
    return result
end function

function invidiousText(value as dynamic, limit as integer) as string
    if GetInterface(value,"ifString") = invalid then return ""
    clean = value.trim()
    if len(clean) > limit then clean = left(clean,limit)
    return clean
end function

function invidiousThumbnail(thumbnails as dynamic) as string
    if type(thumbnails) <> "roArray" then return ""
    chosen = ""
    chosenRank = -1
    for each thumb in thumbnails
        if type(thumb) <> "roAssociativeArray" then continue for
        uri = invidiousText(thumb.url,1024)
        if uri = "" then continue for
        quality = lcase(invidiousText(thumb.quality,40))
        rank = 1
        if instr(1,quality,"maxres") > 0 then rank = 5
        if instr(1,quality,"high") > 0 or instr(1,quality,"sddefault") > 0 then rank = 4
        if instr(1,quality,"medium") > 0 or instr(1,quality,"mqdefault") > 0 then rank = 3
        if instr(1,quality,"default") > 0 then rank = 2
        if rank > chosenRank
            chosenRank = rank
            chosen = uri
        end if
    end for
    return chosen
end function
