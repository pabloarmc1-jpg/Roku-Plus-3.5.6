' Called by HdCatalogTask with its bounded, cancellable transfer implementation.
function rpHdSeriesmetroCatalogRequest(request as object, fetcher as dynamic) as object
    page = (orbitInteger(request.skip,200000) \ 20)+1
    operation = "catalog"
    query = orbitText(request.query,120).trim()
    if query <> "" then operation = "search"
    answer = {ok:false,cancelled:false,requestId:orbitText(request.requestId,120),operation:"catalog",kind:request.kind,provider:"seriesmetro",items:[],hasMore:false,nextSkip:page*20,total:0,message:"No se pudo consultar SeriesMetro."}
    endpoint = rpHdSeriesmetroEndpoint(operation,{kind:request.kind,page:page,query:query})
    if endpoint = "" then return answer
    response = fetcher(endpoint,"seriesmetro-page","https://www3.seriesmetro.net/")
    if not response.ok then return rpHdTaskFailure(answer,response)
    catalog = rpHdSeriesmetroCatalog(response.body,request.kind,page)
    if not catalog.valid then return answer
    answer.items = catalog.items
    answer.hasMore = catalog.hasMore
    answer.ok = true
    answer.message = ""
    return answer
end function

function rpHdSeriesmetroTask(request as object, answer as object, fetcher as dynamic, decoderAccept as dynamic) as object
    operation = orbitText(request.operation,20)
    if operation = "catalog" then return rpHdSeriesmetroCatalogRequest(request,fetcher)
    item = rpHdSeriesmetroInputItem(request.item)
    if item = invalid
        answer.message = "Este título de SeriesMetro no tiene un identificador válido."
        return answer
    end if
    if operation = "meta"
        endpoint = rpHdSeriesmetroEndpoint("meta",{slug:item.providerSlug})
        response = fetcher(endpoint,"seriesmetro-page","https://www3.seriesmetro.net/")
        if not response.ok then return rpHdTaskFailure(answer,response)
        item = rpHdSeriesmetroMetadata(response.body,item)
        if item = invalid
            answer.message = "No se encontraron los detalles de SeriesMetro."
            return answer
        end if
        if item.kind = "series"
            if item.seasons.count() = 0
                answer.message = "Esta serie todavía no tiene temporadas disponibles."
                return answer
            end if
            seasonIndex = 0
            for i = 0 to item.seasons.count()-1
                if item.seasons[i].number = 1 then seasonIndex = i
            end for
            loaded = rpHdSeriesmetroLoadSeason(item,item.seasons[seasonIndex].number,fetcher)
            if not loaded.ok then return rpHdTaskFailure(answer,loaded)
            item.seasons[seasonIndex] = loaded.season
        end if
        answer.item = item
        answer.ok = true
        answer.message = ""
        return answer
    else if operation = "episodes"
        if item.kind <> "series" then return answer
        number = orbitInteger(request.season,999,-1)
        if number < 0 then return answer
        loaded = rpHdSeriesmetroLoadSeason(item,number,fetcher)
        if not loaded.ok then return rpHdTaskFailure(answer,loaded)
        answer.seasons = [loaded.season]
        answer.seasonNumbers = [number]
        answer.season = number
        answer.ok = true
        answer.message = ""
        return answer
    else if operation = "resolve"
        if item.kind <> "movie" and item.kind <> "episode" then return answer
        endpoint = rpHdSeriesmetroEndpoint("player",{slug:item.providerSlug})
        response = fetcher(endpoint,"seriesmetro-page","https://www3.seriesmetro.net/")
        if not response.ok then return rpHdTaskFailure(answer,response)
        options = rpHdSeriesmetroEmbedOptions(response.body)
        embeds = []
        for i = 0 to options.count()-1
            option = options[i]
            rpHdTaskBeginSlice(options.count()-i+1)
            response = fetcher(option.url,"seriesmetro-page",endpoint)
            if response.cancelled then return rpHdTaskFailure(answer,response)
            if response.ok
                url = rpHdSeriesmetroFastream(response.body)
                if url <> "" then embeds.push({url:url,language:option.language})
            end if
        end for
        m.hdProviderDeadline = 0
        if embeds.count() = 0
            answer.message = "No hay una opción en español de SeriesMetro disponible ahora. Prueba otra fuente."
            return answer
        end if
        return rpHdTaskResolveEmbeds(embeds,"seriesmetro",answer,fetcher,decoderAccept,orbitInteger(request.attempt,999),"https://www3.seriesmetro.net/","https://fastream.to/")
    end if
    return answer
end function

function rpHdSeriesmetroLoadSeason(parent as object, number as integer, fetcher as dynamic) as object
    answer = {ok:false,cancelled:false,message:"No se pudieron cargar los episodios de SeriesMetro."}
    endpoint = rpHdSeriesmetroEndpoint("episodes",{id:parent.providerId,season:number})
    response = fetcher(endpoint,"seriesmetro-season","https://www3.seriesmetro.net"+parent.providerSlug)
    if not response.ok then return rpHdTaskFailure(answer,response)
    season = rpHdSeriesmetroEpisodes(response.body,parent,number)
    ' An empty HTTP200 body/WordPress zero is not a valid loaded season.
    if season.episodes.count() = 0 then return answer
    answer.season = season
    answer.ok = true
    answer.message = ""
    return answer
end function
