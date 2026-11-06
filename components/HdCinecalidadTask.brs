' CineCalidad movie-only public pages reuse the common transfer deadline and HLS guards.
function rpHdCinecalidadCatalogRequest(request as object, fetcher as dynamic) as object
    skip = orbitInteger(request.skip,200000)
    page = (skip \ 20)+1
    answer = {ok:true,cancelled:false,items:[],hasMore:false,nextPage:page+1,nextSkip:page*20,total:0,message:""}
    if request.kind = "series" then return answer
    if request.kind <> "movie"
        answer.ok = false
        return answer
    end if
    query = orbitText(request.query,120).trim()
    operation = "catalog"
    if query <> "" then operation = "search"
    endpoint = rpHdCinecalidadEndpoint(operation,{kind:"movie",query:query,page:page})
    response = fetcher(endpoint,"cinecalidad-page","https://www.cinecalidad.vg/")
    if not response.ok then return rpHdTaskFailure(answer,response)
    if not rpHdCinecalidadPage(response.body)
        answer.ok = false
        answer.message = "CineCalidad no devolvió una página de películas disponible."
        return answer
    end if
    catalog = rpHdCinecalidadCatalog(response.body,"movie",page)
    answer.items = catalog.items
    answer.hasMore = catalog.hasMore
    return answer
end function

function rpHdCinecalidadPage(raw as dynamic) as boolean
    text = orbitText(raw,2097153)
    if len(text) > 2097152 then return false
    if not CreateObject("roRegex","<html\b","i").isMatch(text) then return false
    if CreateObject("roRegex","cf-chl-|hcaptcha|g-recaptcha|verify you are human","i").isMatch(text) then return false
    return CreateObject("roRegex","<title>[^<]*cinecalidad","i").isMatch(text)
end function

function rpHdCinecalidadTask(request as object, answer as object, fetcher as dynamic, decoderAccept as dynamic) as object
    item = rpHdCinecalidadInputItem(request.item)
    if item = invalid
        answer.message = "El título de CineCalidad no tiene un identificador válido."
        return answer
    end if
    if request.operation <> "meta" and request.operation <> "resolve" then return answer
    endpoint = rpHdCinecalidadEndpoint("meta",{slug:item.providerSlug})
    rpHdTaskBeginSlice(2)
    response = fetcher(endpoint,"cinecalidad-page","https://www.cinecalidad.vg/")
    m.hdProviderDeadline = 0
    if not response.ok then return rpHdTaskFailure(answer,response)
    if not rpHdCinecalidadPage(response.body)
        answer.message = "La página de esta película en CineCalidad no está disponible."
        return answer
    end if
    normalized = rpHdCinecalidadMetadata(response.body,item)
    if normalized = invalid
        answer.message = "La página de CineCalidad no corresponde a esta película."
        return answer
    end if
    if request.operation = "meta"
        answer.item = normalized
        answer.ok = true
        answer.message = ""
        return answer
    end if
    embeds = rpHdCinecalidadEmbeds(response.body)
    if embeds.count() = 0
        answer.message = "CineCalidad no tiene una opción H.264 en español disponible para esta película."
        return answer
    end if
    return rpHdTaskResolveEmbeds(embeds,"cinecalidad",answer,fetcher,decoderAccept,orbitInteger(request.attempt,999),"https://www.cinecalidad.vg/")
end function

function rpHdCinecalidadInputItem(value as dynamic) as dynamic
    if type(value) <> "roAssociativeArray" then return invalid
    if value.provider <> "cinecalidad" or value.kind <> "movie" then return invalid
    slug = rpHdCinecalidadSlug(value.providerSlug)
    if slug = "" or value.providerId <> slug or value.id <> "hdo-cinecalidad-"+slug then return invalid
    return {
        id:value.id,kind:"movie",imdbId:"",library:"hd-online",provider:"cinecalidad",providerId:slug,providerSlug:slug
        title:orbitText(value.title,200),description:orbitText(value.description),poster:orbitHttpsUrl(value.poster),background:orbitHttpsUrl(value.background)
        year:orbitText(value.year,4),runtime:0,language:"",seasons:[]
    }
end function
