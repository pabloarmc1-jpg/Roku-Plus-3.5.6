' CineHax orchestration shares the HD task deadline, transfer guards and AVC/AAC resolver.
' Imported into HdCatalogTask; never runs a separate task or browser runtime.
function rpHdCinehaxTask(request as object, answer as object, fetcher as dynamic, decoderAccept as dynamic) as object
    item = rpHdCinehaxInputItem(request.item)
    if item = invalid
        answer.message = "El título de CineHax no tiene un identificador válido."
        return answer
    end if
    operation = orbitText(request.operation,20)
    if operation = "episodes"
        if item.kind <> "series" then return answer
        season = orbitInteger(request.season,999,-1)
        if season < 0 then return answer
        loaded = rpHdCinehaxLoadEpisodes(item,season,fetcher,[])
        if not loaded.ok then return rpHdTaskFailure(answer,loaded)
        answer.seasons = loaded.seasons
        answer.seasonNumbers = loaded.seasonNumbers
        answer.ok = true
        answer.message = ""
        return answer
    end if
    if operation <> "meta" and operation <> "resolve" then return answer
    if operation = "meta" and item.kind = "episode" then return answer
    if operation = "resolve" and item.kind = "series" then return answer

    parent = rpHdCinehaxParent(item)
    rpHdTaskBeginSlice(3)
    endpoint = rpHdCinehaxEndpoint("meta",{kind:parent.kind,sourceKind:parent.providerKind,slug:parent.providerSlug})
    response = rpHdTaskFetchJson(endpoint,fetcher)
    m.hdProviderDeadline = 0
    if not response.ok then return rpHdTaskFailure(answer,response)
    normalized = rpHdCinehaxMetadata(response.data,parent)
    if normalized = invalid
        answer.message = "No se encontraron los detalles de este título en CineHax."
        return answer
    end if
    if operation = "meta"
        if normalized.kind = "series"
            first = 1
            if normalized.seasonNumbers.count() > 0
                first = normalized.seasonNumbers[0]
                for each number in normalized.seasonNumbers
                    if number > 0
                        first = number
                        exit for
                    end if
                end for
            end if
            loaded = rpHdCinehaxLoadEpisodes(normalized,first,fetcher,normalized.seasonNumbers)
            if not loaded.ok then return rpHdTaskFailure(answer,loaded)
            normalized.seasons = loaded.seasons
            normalized.seasonNumbers = loaded.seasonNumbers
        end if
        answer.item = normalized
        answer.ok = true
        answer.message = ""
        return answer
    end if

    if item.kind = "episode"
        normalized.kind = "episode"
        normalized.season = item.season
        normalized.episode = item.episode
    end if
    player = rpHdCinehaxPlayer(normalized)
    if player = "" then return answer
    rpHdTaskBeginSlice(2)
    response = fetcher(player,"player","https://cinehax.org/")
    m.hdProviderDeadline = 0
    if not response.ok then return rpHdTaskFailure(answer,response)
    iframe = rpHdCinehaxIframe(response.body)
    if iframe = ""
        answer.message = "CineHax no tiene un servidor compatible disponible. Prueba otra opción de esta película."
        return answer
    end if
    embeds = [{url:iframe,language:"Español latino",quality:""}]
    retry = orbitInteger(request.attempt,999)
    return rpHdTaskResolveEmbeds(embeds,"cinehax",answer,fetcher,decoderAccept,retry,"https://videoapp.mov/")
end function

function rpHdCinehaxInputItem(value as dynamic) as dynamic
    if type(value) <> "roAssociativeArray" then return invalid
    if value.provider <> "cinehax" then return invalid
    number = rpHdCinehaxId(value.providerId)
    tmdb = rpHdCinehaxId(value.providerTmdbId)
    sourceKind = orbitText(value.providerKind,16)
    kind = orbitText(value.kind,10)
    if number = "" or tmdb = "" then return invalid
    if kind = "movie"
        if sourceKind <> "movie" then return invalid
    else if kind = "series" or kind = "episode"
        if sourceKind <> "serie" and sourceKind <> "anime" and sourceKind <> "novel" then return invalid
    else
        return invalid
    end if
    slug = orbitText(value.providerSlug,200)
    if not CreateObject("roRegex","^[a-z0-9áéíóúüñàèìòùâêîôûãõçªº-]{1,200}$","").isMatch(slug) then return invalid
    id = "hdo-cinehax-"+number
    season = orbitInteger(value.season,999,-1)
    episode = orbitInteger(value.episode,9999)
    if kind = "episode"
        if season < 0 or episode < 1 then return invalid
        id += "-s"+season.toStr()+"-e"+episode.toStr()
    end if
    if value.id <> id then return invalid
    return {
        id:id,kind:kind,imdbId:orbitImdb(value.imdbId),library:"hd-online",provider:"cinehax",providerId:number
        providerTmdbId:tmdb,providerKind:sourceKind,providerSlug:slug
        title:orbitText(value.title,200),description:orbitText(value.description)
        poster:orbitHttpsUrl(value.poster),background:orbitHttpsUrl(value.background)
        year:orbitText(value.year,4),runtime:orbitInteger(value.runtime,86400),language:"",seasons:[]
        season:season,episode:episode,seriesTitle:orbitText(value.seriesTitle,200)
    }
end function

function rpHdCinehaxParent(item as object) as object
    parent = {}
    for each key in item
        parent[key] = item[key]
    end for
    if item.kind = "episode"
        parent.id = "hdo-cinehax-"+item.providerId
        parent.kind = "series"
        parent.title = item.seriesTitle
    end if
    return parent
end function

function rpHdCinehaxLoadEpisodes(parent as object, season as integer, fetcher as dynamic, declared as object) as object
    answer = {ok:false,cancelled:false,message:"No se pudieron cargar los episodios de CineHax.",seasons:[],seasonNumbers:[]}
    pages = []
    page = 1
    complete = false
    for attempt = 1 to 12
        endpoint = rpHdCinehaxEndpoint("episodes",{kind:"series",sourceKind:parent.providerKind,id:parent.providerId,season:season,page:page})
        response = rpHdTaskFetchJson(endpoint,fetcher)
        if not response.ok then return rpHdTaskFailure(answer,response)
        normalized = rpHdCinehaxEpisodes(response.data,parent,season,page)
        if not normalized.ok
            answer.message = "CineHax devolvió episodios que no corresponden a esta temporada."
            return answer
        end if
        pages.push(normalized.seasons)
        if not normalized.hasMore
            complete = true
            exit for
        end if
        if normalized.nextPage <= page then exit for
        page = normalized.nextPage
    end for
    if not complete
        answer.message = "Esta temporada es demasiado extensa para cargarla ahora. Vuelve a intentar."
        return answer
    end if
    merged = rpHdTaskMergeSeasons(pages,declared,season,false)
    answer.seasons = merged.seasons
    answer.seasonNumbers = merged.seasonNumbers
    answer.ok = answer.seasons.count() > 0
    if answer.ok then answer.message = ""
    return answer
end function
