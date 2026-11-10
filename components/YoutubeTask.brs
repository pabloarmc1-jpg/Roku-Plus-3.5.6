' Roku Plus YouTube catalog task.
' Uses the official YouTube Data API v3 for public video metadata only.
' It does not extract media URLs or attempt to bypass YouTube playback.
sub init()
    m.top.functionName = "runYoutubeRequest"
end sub

sub runYoutubeRequest()
    answer = {ok:false, operation:m.top.operation, items:[], message:"No se pudo consultar YouTube."}
    if m.top.cancelRequested then return
    if m.top.operation <> "search"
        answer.message = "La operación de YouTube no es válida."
        m.top.result = answer
        return
    end if

    query = ""
    if GetInterface(m.top.query,"ifString") <> invalid then query = m.top.query.trim()
    if query = "" or len(query) > 160
        answer.message = "Escribe un término de búsqueda."
        m.top.result = answer
        return
    end if

    apiKey = ""
    if GetInterface(m.top.apiKey,"ifString") <> invalid then apiKey = m.top.apiKey.trim()
    if apiKey = "" or len(apiKey) > 512
        answer.message = "Configura primero tu YouTube Data API v3 Key en Ajustes."
        m.top.result = answer
        return
    end if

    maxResults = m.top.maxResults
    if GetInterface(maxResults,"ifInt") = invalid then maxResults = 20
    if maxResults < 1 then maxResults = 1
    if maxResults > 25 then maxResults = 25

    encoder = CreateObject("roUrlTransfer")
    endpoint = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&safeSearch=none&maxResults=" + maxResults.toStr()
    endpoint += "&q=" + encoder.escape(query) + "&key=" + encoder.escape(apiKey)

    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.setUrl(endpoint)
    transfer.setTimeout(20000)
    transfer.addHeader("User-Agent","RokuPlus/YouTubeCatalog")
    transfer.addHeader("Accept","application/json")
    print "[RokuPlus YouTube] request_start"

    if m.top.cancelRequested then return
    started = transfer.asyncGetToString()
    if not started
        print "[RokuPlus YouTube] request_start_failed"
        answer.message = "No se pudo iniciar la conexión con YouTube."
        m.top.result = answer
        return
    end if

    body = ""
    code = 0
    finished = false
    elapsed = CreateObject("roTimespan")
    elapsed.mark()
    while not finished
        if m.top.cancelRequested
            transfer.asyncCancel()
            print "[RokuPlus YouTube] request_cancelled"
            return
        end if
        if elapsed.totalMilliseconds() >= 20000
            print "[RokuPlus YouTube] request_timeout"
            exit while
        end if
        event = wait(50,port)
        if type(event) = "roUrlEvent"
            if event.getSourceIdentity() = transfer.getIdentity()
                code = event.getResponseCode()
                body = event.getString()
                finished = true
            end if
        end if
    end while
    if not finished
        transfer.asyncCancel()
        answer.message = "La búsqueda de YouTube tardó demasiado. Comprueba Internet e inténtalo de nuevo."
        m.top.result = answer
        return
    end if
    print "[RokuPlus YouTube] response status="; code; " ms="; elapsed.totalMilliseconds(); " bytes="; len(body)
    if code <> 200 or GetInterface(body,"ifString") = invalid or body = ""
        answer.message = youtubeApiError(body,code)
        m.top.result = answer
        return
    end if
    if len(body) > 2097152
        answer.message = "La respuesta de YouTube supera el límite permitido."
        m.top.result = answer
        return
    end if

    print "[RokuPlus YouTube] parse_start"
    payload = ParseJson(body)
    if type(payload) <> "roAssociativeArray" or type(payload.items) <> "roArray"
        answer.message = "YouTube devolvió una respuesta que no se puede leer."
        m.top.result = answer
        return
    end if

    for each entry in payload.items
        if m.top.cancelRequested then return
        if type(entry) <> "roAssociativeArray" then continue for
        if type(entry.id) <> "roAssociativeArray" or type(entry.snippet) <> "roAssociativeArray" then continue for
        videoId = youtubeText(entry.id.videoId,32)
        if videoId = "" then continue for
        snippet = entry.snippet
        title = youtubeText(snippet.title,300)
        if title = "" then title = "Video de YouTube"
        channel = youtubeText(snippet.channelTitle,160)
        description = youtubeText(snippet.description,600)
        thumbnail = ""
        if type(snippet.thumbnails) = "roAssociativeArray"
            if type(snippet.thumbnails.high) = "roAssociativeArray" then thumbnail = youtubeText(snippet.thumbnails.high.url,1024)
            if thumbnail = "" and type(snippet.thumbnails.medium) = "roAssociativeArray" then thumbnail = youtubeText(snippet.thumbnails.medium.url,1024)
            if thumbnail = "" and type(snippet.thumbnails.default) = "roAssociativeArray" then thumbnail = youtubeText(snippet.thumbnails.default.url,1024)
        end if
        publishedAt = youtubeText(snippet.publishedAt,40)
        answer.items.push({
            id:videoId,
            title:title,
            channelTitle:channel,
            description:description,
            thumbnail:thumbnail,
            publishedAt:publishedAt,
            watchUrl:"https://www.youtube.com/watch?v=" + videoId
        })
    end for

    print "[RokuPlus YouTube] parsed_items="; answer.items.count()
    answer.ok = true
    answer.message = ""
    if answer.items.count() = 0 then answer.message = "No se encontraron videos para esa búsqueda."
    m.top.result = answer
    print "[RokuPlus YouTube] result_sent ok="; answer.ok
end sub

function youtubeText(value as dynamic, limit as integer) as string
    if GetInterface(value,"ifString") = invalid then return ""
    clean = value.trim()
    if len(clean) > limit then clean = left(clean,limit)
    return clean
end function

function youtubeApiError(body as dynamic, code as integer) as string
    if code = 403 then return "YouTube rechazó la consulta. Revisa la API Key, la cuota y que YouTube Data API v3 esté habilitada."
    if code = 400 then return "YouTube no aceptó la búsqueda. Comprueba la configuración de la API."
    if code = 404 then return "No se encontró el servicio de YouTube."
    if code = 0 then return "No hubo conexión con YouTube. Comprueba Internet."
    if GetInterface(body,"ifString") <> invalid
        parsed = ParseJson(body)
        if type(parsed) = "roAssociativeArray" and type(parsed.error) = "roAssociativeArray"
            if GetInterface(parsed.error.message,"ifString") <> invalid then return left(parsed.error.message,220)
        end if
    end if
    return "YouTube respondió con el código " + code.toStr() + "."
end function
