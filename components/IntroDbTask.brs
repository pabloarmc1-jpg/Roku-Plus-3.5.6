' Read-only metadata resolution through Cinemeta, followed by IntroDB segment lookup.
sub init()
    m.top.functionName = "runIntroDbLookup"
end sub

sub runIntroDbLookup()
    answer = {ok:false,requestId:m.top.requestId,cacheKey:m.top.cacheKey,message:"No hay datos de segmentos para este título."}
    imdbId = m.top.imdbId.trim()
    isMovie = m.top.isMovie
    season = m.top.season
    episode = m.top.episode

    if imdbId = "" or not CreateObject("roRegex","^tt[0-9]{7,}$","").isMatch(imdbId)
        title = m.top.title.trim()
        if title = ""
            answer.message = "Falta el título para buscarlo en Cinemeta."
            if not m.top.cancelRequested then m.top.result = answer
            return
        end if
        imdbId = introDbResolveCinemetaId(title,m.top.year,isMovie,season,episode)
        if m.top.cancelRequested then return
        if imdbId = ""
            answer.message = "Cinemeta no encontró una coincidencia segura para este título y episodio."
            if not m.top.cancelRequested then m.top.result = answer
            return
        end if
        print "[RokuPlus cinemeta] resolved imdb="; imdbId; " title="; title
    end if

    if not CreateObject("roRegex","^tt[0-9]{7,}$","").isMatch(imdbId)
        answer.message = "Cinemeta no devolvió un IMDb ID válido."
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if

    endpoint = "https://api.introdb.app/segments?imdb_id=" + imdbId
    if isMovie
        endpoint += "&is_movie=true"
        answer.cacheKey = imdbId + "|movie"
    else
        if season < 1 or episode < 1
            answer.message = "Faltan temporada o episodio para consultar IntroDB."
            if not m.top.cancelRequested then m.top.result = answer
            return
        end if
        endpoint += "&season=" + season.toStr() + "&episode=" + episode.toStr()
        answer.cacheKey = imdbId + "|s" + season.toStr() + "e" + episode.toStr()
    end if

    parsed = introDbGetJson(endpoint,8000)
    if m.top.cancelRequested then return
    if type(parsed) <> "roAssociativeArray"
        answer.message = "IntroDB no respondió con datos válidos."
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if

    answer.ok = true
    answer.imdbId = imdbId
    answer.intro = parsed.intro
    answer.recap = parsed.recap
    answer.outro = parsed.outro
    answer.post_credits = parsed.post_credits
    answer.no_intro = parsed.no_intro
    answer.no_recap = parsed.no_recap
    answer.no_outro = parsed.no_outro
    answer.message = ""
    if not m.top.cancelRequested then m.top.result = answer
end sub

' Resolve titles missing an IMDb identity. Search results must match title and,
' when available, year; episode metadata must contain the requested S/E pair.
function introDbResolveCinemetaId(title as string, year as string, isMovie as boolean, season as integer, episode as integer) as string
    if m.top.cancelRequested then return ""
    cleanTitle = introDbNormalizeTitle(title)
    if cleanTitle = "" then return ""

    mediaType = "series"
    if isMovie then mediaType = "movie"
    transfer = CreateObject("roUrlTransfer")
    searchTitle = CreateObject("roRegex","\s*[\(\[]((19|20)[0-9]{2})[\)\]]\s*$","").replace(title,"").trim()
    if searchTitle = "" then searchTitle = title
    searchUrl = "https://v3-cinemeta.strem.io/catalog/" + mediaType + "/top/search=" + transfer.Escape(searchTitle) + ".json"
    searchData = introDbGetJson(searchUrl,6000)
    if m.top.cancelRequested then return ""
    if type(searchData) <> "roAssociativeArray" then return ""
    if type(searchData.metas) <> "roArray" then return ""

    wantedYear = ""
    if len(year) >= 4 then wantedYear = left(year,4)
    matchedId = ""
    matchCount = 0
    for each candidate in searchData.metas
        if m.top.cancelRequested then return ""
        if type(candidate) = "roAssociativeArray"
            candidateTitle = introDbNormalizeTitle(candidate.name)
            candidateId = candidate.id
            if candidateTitle = cleanTitle and type(candidateId) = "String"
                validYear = true
                candidateYear = orbitYearText(candidate.releaseInfo)
                if candidateYear = "" then candidateYear = orbitYearText(candidate.year)
                if wantedYear <> "" and candidateYear <> "" and candidateYear <> wantedYear then validYear = false
                if validYear and CreateObject("roRegex","^tt[0-9]{7,}$","").isMatch(candidateId)
                    matchedId = candidateId
                    matchCount = matchCount + 1
                end if
            end if
        end if
    end for
    if matchCount <> 1 then return ""

    metaData = introDbGetJson("https://v3-cinemeta.strem.io/meta/" + mediaType + "/" + matchedId + ".json",6000)
    if m.top.cancelRequested then return ""
    if type(metaData) <> "roAssociativeArray" or type(metaData.meta) <> "roAssociativeArray" then return ""
    if introDbNormalizeTitle(metaData.meta.name) <> cleanTitle then return ""

    if not isMovie
        if type(metaData.meta.videos) <> "roArray" then return ""
        episodeFound = false
        for each video in metaData.meta.videos
            if m.top.cancelRequested then return ""
            if type(video) = "roAssociativeArray"
                if video.season = season and video.episode = episode then episodeFound = true
            end if
        end for
        if not episodeFound then return ""
    end if
    return matchedId
end function

function introDbGetJson(url as string, timeoutMs as integer) as dynamic
    if m.top.cancelRequested then return invalid
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.addHeader("Accept","application/json")
    transfer.setUrl(url)
    if not transfer.asyncGetToString() then return invalid

    clock = CreateObject("roTimespan")
    clock.mark()
    while clock.totalMilliseconds() < timeoutMs
        if m.top.cancelRequested
            transfer.asyncCancel()
            return invalid
        end if
        event = wait(100,port)
        if type(event) = "roUrlEvent" and event.getSourceIdentity() = transfer.getIdentity()
            if event.getResponseCode() <> 200 then return invalid
            return ParseJson(event.getString())
        end if
    end while
    transfer.asyncCancel()
    return invalid
end function

function introDbNormalizeTitle(value as dynamic) as string
    if type(value) <> "String" then return ""
    title = value.trim()
    title = CreateObject("roRegex","\s*[\(\[]((19|20)[0-9]{2})[\)\]]\s*$","").replace(title,"").trim()
    regex = CreateObject("roRegex","[^a-z0-9]","i")
    return regex.replaceAll(lcase(title),"")
end function

function orbitYearText(value as dynamic) as string
    yearValue = ""
    if type(value) = "String"
        yearValue = value
    else if type(value) = "Integer" or type(value) = "LongInteger" or type(value) = "Float" or type(value) = "Double"
        yearValue = value.toStr()
    else
        return ""
    end if
    match = CreateObject("roRegex","(19|20)[0-9]{2}","").match(yearValue)
    if match.count() < 1 then return ""
    return match[0]
end function
