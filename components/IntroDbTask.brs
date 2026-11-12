' Read-only IntroDB lookup. Reads are anonymous; no shared API key is required.
sub init()
    m.top.functionName = "runIntroDbLookup"
end sub

sub runIntroDbLookup()
    answer = {ok:false,requestId:m.top.requestId,cacheKey:m.top.cacheKey,message:"No hay datos de créditos para este título."}
    imdbId = m.top.imdbId.trim()
    if not CreateObject("roRegex","^tt[0-9]{7,8}$","").isMatch(imdbId)
        answer.message = "El título no tiene un IMDb ID válido."
        m.top.result = answer
        return
    end if
    endpoint = "https://api.introdb.app/segments?imdb_id=" + imdbId
    if m.top.isMovie
        endpoint += "&is_movie=true"
    else
        season = m.top.season
        episode = m.top.episode
        if season < 1 or episode < 1
            answer.message = "Faltan temporada o episodio para consultar IntroDB."
            m.top.result = answer
            return
        end if
        endpoint += "&season=" + season.toStr() + "&episode=" + episode.toStr()
    end if
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.addHeader("Accept","application/json")
    transfer.setUrl(endpoint)
    if not transfer.asyncGetToString()
        answer.message = "No se pudo iniciar la consulta de IntroDB."
        m.top.result = answer
        return
    end if
    clock = CreateObject("roTimespan")
    clock.mark()
    responseEvent = invalid
    while clock.totalMilliseconds() < 8000
        if m.top.cancelRequested
            transfer.asyncCancel()
            return
        end if
        event = wait(100,port)
        if type(event) = "roUrlEvent"
            if event.getSourceIdentity() = transfer.getIdentity()
                responseEvent = event
                exit while
            end if
        end if
    end while
    if responseEvent = invalid
        transfer.asyncCancel()
        answer.message = "La consulta de IntroDB agotó el tiempo de espera."
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if
    if responseEvent.getInt() <> 200
        answer.message = "IntroDB respondió con HTTP " + responseEvent.getInt().toStr() + "."
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if
    parsed = ParseJson(responseEvent.getString())
    if type(parsed) <> "roAssociativeArray"
        answer.message = "IntroDB devolvió una respuesta no válida."
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if
    answer.ok = true
    answer.outro = parsed.outro
    answer.post_credits = parsed.post_credits
    answer.no_outro = parsed.no_outro
    answer.message = ""
    if not m.top.cancelRequested then m.top.result = answer
end sub