' Public HD source requests. No JavaScript evaluation, proxy or PC helper.
' Every operation has one 40-second deadline; response files are bounded/deleted.
sub init()
    m.top.functionName = "runHdCatalogRequest"
end sub

sub runHdCatalogRequest()
    m.hdElapsed = CreateObject("roTimespan")
    m.hdElapsed.mark()
    request = {
        operation:m.top.operation, kind:m.top.kind, provider:m.top.provider
        query:m.top.query, skip:m.top.skip, item:m.top.item, season:m.top.season
        requestId:m.top.requestId, attempt:m.top.attempt
    }
    answer = rpHdTaskExecute(request)
    if not m.top.cancelRequested then m.top.result = answer
end sub

' Fetch/decoder/source injection exercises this exact orchestration offline.
function rpHdTaskExecute(request as object, fetcher = invalid as dynamic, decoderAccept = invalid as dynamic, catalogSources = invalid as dynamic) as object
    if fetcher = invalid then fetcher = rpHdTaskDownloadText
    if decoderAccept = invalid then decoderAccept = rpHdTaskCanDecode
    operation = orbitText(request.operation,20)
    kind = orbitText(request.kind,10)
    provider = rpHdOnlineProvider(request.provider)
    answer = {ok:false, cancelled:false, requestId:orbitText(request.requestId,120), operation:operation, kind:kind, provider:provider, message:"No se pudo completar la consulta HD."}
    m.hdProviderDeadline = 0
    if provider = ""
        answer.message = "Elige una fuente HD válida."
        return answer
    end if
    if operation = "catalog"
        if kind <> "movie" and kind <> "series" then return answer
        if provider = "all" then return rpHdTaskCombinedCatalog(request,answer,fetcher,catalogSources)
        skip = orbitInteger(request.skip,200000)
        page = (skip \ 20)+1
        query = rpHdOnlineSearchQuery(request.query)
        catalog = rpHdTaskCatalogPage(provider,kind,page,query,fetcher)
        if not catalog.ok then return rpHdTaskFailure(answer,catalog)
        answer.items = catalog.items
        answer.hasMore = catalog.hasMore
        answer.nextSkip = catalog.nextSkip
        answer.total = catalog.total
        answer.totalKnown = catalog.totalKnown
        answer.ok = true
        answer.message = ""
        return answer
    end if
    ' A combined result keeps its own source identity for details and playback.
    ' Never resolve a title against whichever catalog happens to be selected.
    if provider = "all" and type(request.item) = "roAssociativeArray"
        provider = rpHdOnlineProvider(request.item.provider)
        if provider = "all" then provider = ""
    end if
    if provider = "cinehax" then return rpHdCinehaxTask(request,answer,fetcher,decoderAccept)
    if provider = "seriesmetro" then return rpHdSeriesmetroTask(request,answer,fetcher,decoderAccept)
    if provider = "cinecalidad" then return rpHdCinecalidadTask(request,answer,fetcher,decoderAccept)
    item = rpHdTaskInputItem(request.item,provider)
    if item = invalid
        answer.message = "El título HD no tiene un identificador válido."
        return answer
    end if
    if operation = "meta"
        if item.kind <> "movie" and item.kind <> "series" then return answer
        if provider = "lamovie"
            endpoint = rpHdOnlineEndpoint(provider,"meta",{kind:item.kind,slug:item.providerSlug})
            response = rpHdTaskFetchJson(endpoint,fetcher)
            if not response.ok then return rpHdTaskFailure(answer,response)
            normalized = rpHdOnlineMetadata(response.data,provider,item.kind,item.id)
            if normalized = invalid
                answer.message = "No se encontraron los detalles de este título HD."
                return answer
            end if
            item = normalized
        end if
        if item.kind = "series"
            loaded = rpHdTaskLoadEpisodes(item,1,fetcher)
            if not loaded.ok then return rpHdTaskFailure(answer,loaded)
            item.seasons = loaded.seasons
            item.seasonNumbers = loaded.seasonNumbers
        end if
        answer.item = item
        answer.ok = true
        answer.message = ""
        return answer
    else if operation = "episodes"
        if item.kind <> "series" then return answer
        season = orbitInteger(request.season,999,1)
        if season < 0 then season = 1
        loaded = rpHdTaskLoadEpisodes(item,season,fetcher)
        if not loaded.ok then return rpHdTaskFailure(answer,loaded)
        answer.seasons = []
        for each loadedSeason in loaded.seasons
            if loadedSeason.loaded then answer.seasons.push(loadedSeason)
        end for
        answer.seasonNumbers = loaded.seasonNumbers
        answer.season = season
        answer.ok = true
        answer.message = ""
        return answer
    else if operation = "resolve"
        if item.kind <> "movie" and item.kind <> "episode" then return answer
        return rpHdTaskResolveItem(item,provider,answer,fetcher,decoderAccept,orbitInteger(request.attempt,999))
    end if
    answer.message = "La consulta HD no es válida."
    return answer
end function

function rpHdTaskResolveItem(item as object, provider as string, answer as object, fetcher as dynamic, decoderAccept as dynamic, retry as integer) as object
    ' Bound the initial player API so it cannot consume the whole operation.
    rpHdTaskBeginSlice(4)
    endpoint = rpHdOnlineEndpoint(provider,"player",{id:item.providerId})
    response = rpHdTaskFetchJson(endpoint,fetcher)
    m.hdProviderDeadline = 0
    if not response.ok then return rpHdTaskFailure(answer,response)
    embeds = rpHdOnlineEmbeds(response.data)
    return rpHdTaskResolveEmbeds(embeds,provider,answer,fetcher,decoderAccept,retry)
end function

' Adapters may discover Vimeos links differently but share media validation.
function rpHdTaskResolveEmbeds(embeds as object, provider as string, answer as object, fetcher as dynamic, decoderAccept as dynamic, retry = 0 as integer, embedReferer = "" as string, mediaReferer = "https://vimeos.net/" as string) as object
    count = embeds.count()
    if count > 6 then count = 6
    answer.embedAttempts = 0
    answer.variantAttempts = 0
    embedOffset = 0
    if count > 0 then embedOffset = retry mod count
    if embedReferer = "" then embedReferer = rpHdTaskProviderReferer(provider)
    for i = 0 to count-1
        embedIndex = (i+embedOffset) mod count
        embed = embeds[embedIndex]
        answer.embedAttempts++
        rpHdTaskBeginSlice(count-i)
        response = fetcher(embed.url,"embed",embedReferer)
        if response.cancelled then return rpHdTaskFailure(answer,response)
        if response.ok
            masterUrl = rpHdOnlineMediaUrl(response.body)
            if masterUrl <> ""
                response = fetcher(masterUrl,"media",mediaReferer)
                if response.cancelled then return rpHdTaskFailure(answer,response)
                if response.ok
                    master = rpHdOnlineMaster(response.body,masterUrl)
                    candidates = {variants:[],audioTracks:master.audioTracks,encrypted:master.encrypted}
                    for each variant in master.variants
                        if rpHdTaskSpanishAudio(master,variant) then candidates.variants.push(variant)
                    end for
                    choices = rpHdTaskStableVariants(candidates,decoderAccept)
                    variantOffset = 0
                    if choices.count() > 0 then variantOffset = (retry \ count) mod choices.count()
                    for qualityAttempt = 0 to choices.count()-1
                        if rpHdTaskSliceExpired() then exit for
                        variantIndex = (qualityAttempt+variantOffset) mod choices.count()
                        selected = choices[variantIndex]
                        answer.variantAttempts++
                        child = fetcher(selected.url,"media",mediaReferer)
                        if child.cancelled then return rpHdTaskFailure(answer,child)
                        playable = child.ok and rpHdTaskMediaManifest(child.body,selected.url)
                        if playable
                            segmentUrl = rpHdTaskFirstSegment(child.body,selected.url)
                            ' Only this tested TS path has an AVC/AAC byte validator.
                            ' Codec labels alone must not send a dead or silent stream to Video.
                            playable = rpHdTaskTsSegment(segmentUrl)
                            if playable
                                sample = fetcher(segmentUrl,"sample",mediaReferer)
                                if sample.cancelled then return rpHdTaskFailure(answer,sample)
                                playable = sample.ok and rpHdOnlineMuxedAvcAac(sample.bytes)
                            end if
                        end if
                        if playable
                            answer.url = selected.url
                            answer.streamFormat = "hls"
                            answer.mediaHeaders = {Referer:mediaReferer, "User-Agent":rpHdTaskUserAgent()}
                            answer.description = "Español · H.264 · "+selected.height.toStr()+"p"
                            answer.language = embed.language
                            answer.width = selected.width
                            answer.height = selected.height
                            answer.codecs = selected.codecs
                            answer.seekSupport = "native-hls"
                            answer.attemptUsed = embedIndex+variantIndex*count
                            answer.ok = true
                            answer.message = ""
                            m.hdProviderDeadline = 0
                            return answer
                        end if
                    end for
                end if
            end if
        end if
    end for
    m.hdProviderDeadline = 0
    answer.message = "No hay una fuente H.264 en español compatible disponible para este título. Prueba otra opción de la misma película."
    return answer
end function

function rpHdTaskStableVariants(master as object, decoderAccept as dynamic) as object
    choices = []
    candidates = {variants:master.variants,encrypted:master.encrypted}
    for attempt = 1 to 4
        selected = rpHdTaskSelectStableVariant(candidates,decoderAccept)
        if selected = invalid then exit for
        choices.push(selected)
        remaining = []
        for each variant in candidates.variants
            if variant.url <> selected.url then remaining.push(variant)
        end for
        candidates.variants = remaining
    end for
    return choices
end function

' Prefer a reasonable HD stream before trying more demanding resolutions.
' Every choice still passes the common AVC/AAC and native decoder guards.
function rpHdTaskSelectStableVariant(master as object, decoderAccept as dynamic) as dynamic
    preferred = {variants:[],encrypted:master.encrypted}
    for each variant in master.variants
        height = orbitInteger(variant.height,1080)
        bandwidth = orbitInteger(variant.bandwidth,100000000)
        if height <= 720 and (bandwidth <= 4000000 or bandwidth = 0)
            preferred.variants.push(variant)
        end if
    end for
    selected = rpHdOnlineSelectVariant(preferred,decoderAccept)
    if selected <> invalid then return selected
    lower = {variants:[],encrypted:master.encrypted}
    for each variant in master.variants
        if variant.height <= 720 then lower.variants.push(variant)
    end for
    selected = rpHdOnlineSelectVariant(lower,decoderAccept)
    if selected <> invalid then return selected
    return rpHdOnlineSelectVariant(master,decoderAccept)
end function

function rpHdTaskTsSegment(url as string) as boolean
    return rpHdOnlineCdn(url) <> "" and CreateObject("roRegex","\.ts(\?[^#]*)?$","i").isMatch(url)
end function

' skip encodes source-page rounds in steps of twenty, not displayed-card count.
' JSON providers request twenty records; SSR pages may contain more cards.
' Round-robin output preserves duplicate titles belonging to different sources.
function rpHdTaskCombinedCatalog(request as object, answer as object, fetcher as dynamic, sources = invalid as dynamic) as object
    skip = orbitInteger(request.skip,200000)
    page = (skip \ 20)+1
    query = rpHdOnlineSearchQuery(request.query)
    if type(sources) <> "roArray" then sources = rpHdOnlineProviderIds()
    applicable = []
    for each value in sources
        source = rpHdOnlineProvider(value)
        if source <> "" and source <> "all"
            ' A movies-only adapter must not mask failures of every series source.
            if source <> "cinecalidad" or answer.kind <> "series" then applicable.push(source)
        end if
    end for
    sources = applicable
    pages = []
    failures = []
    successes = []
    total = 0
    totalKnown = true
    more = false
    rows = 0
    count = sources.count()
    if count > 8 then count = 8
    for i = 0 to count-1
        source = rpHdOnlineProvider(sources[i])
        if source <> "" and source <> "all"
            rpHdTaskBeginSlice(count-i)
            response = rpHdTaskCatalogPage(source,answer.kind,page,query,fetcher)
            m.hdProviderDeadline = 0
            if response.cancelled then return rpHdTaskFailure(answer,response)
            if response.ok
                catalog = response
                pages.push(catalog.items)
                if catalog.items.count() > rows then rows = catalog.items.count()
                successes.push(source)
                total += catalog.total
                if catalog.totalKnown = false then totalKnown = false
                if catalog.total = 0 and (catalog.items.count() > 0 or catalog.hasMore) then totalKnown = false
                if catalog.hasMore then more = true
            else
                failures.push(source)
            end if
        end if
    end for
    answer.items = []
    seen = {}
    if rows > 200 then rows = 200
    for row = 0 to rows-1
        for each entries in pages
            if row < entries.count()
                item = entries[row]
                if not seen.doesExist(item.id)
                    answer.items.push(item)
                    seen[item.id] = true
                end if
            end if
        end for
    end for
    answer.sourceFailures = failures
    answer.sourcesSearched = successes
    answer.partial = failures.count() > 0
    if failures.count() > 0 then totalKnown = false
    answer.totalKnown = totalKnown
    answer.total = 0
    if totalKnown then answer.total = total
    answer.hasMore = more
    answer.nextSkip = page*20
    answer.ok = successes.count() > 0
    if answer.ok
        answer.message = ""
        if answer.partial then answer.message = "Algunas fuentes no respondieron. Se muestran las opciones disponibles."
    else
        answer.message = "Ninguna fuente HD respondió. Vuelve a intentar la búsqueda."
    end if
    return answer
end function

function rpHdTaskCatalogPage(provider as string, kind as string, page as integer, query as string, fetcher as dynamic) as object
    if provider = "seriesmetro"
        response = rpHdSeriesmetroCatalogRequest({operation:"catalog",provider:provider,kind:kind,skip:(page-1)*20,query:query},fetcher)
        response.totalKnown = false
        if response.ok then response.totalKnown = response.items.count() = 0 and not response.hasMore
        return response
    end if
    if provider = "cinecalidad"
        response = rpHdCinecalidadCatalogRequest({operation:"catalog",provider:provider,kind:kind,skip:(page-1)*20,query:query},fetcher)
        response.totalKnown = false
        if response.ok then response.totalKnown = response.items.count() = 0 and not response.hasMore
        return response
    end if
    action = "catalog"
    if query <> "" then action = "search"
    endpoint = rpHdOnlineEndpoint(provider,action,{kind:kind,page:page,query:query})
    response = rpHdTaskFetchCatalog(endpoint,provider,fetcher)
    if not response.ok then return response
    catalog = rpHdOnlineCatalog(response.data,provider,kind,page)
    totalKnown = true
    if catalog.total = 0 and (catalog.items.count() > 0 or catalog.hasMore) then totalKnown = false
    ' CineHax search paginates a mixed movie/series response before filtering.
    if provider = "cinehax" and query <> "" then totalKnown = false
    total = 0
    if totalKnown then total = catalog.total
    return {ok:true,cancelled:false,message:"",items:catalog.items,hasMore:catalog.hasMore,nextSkip:(catalog.nextPage-1)*20,total:total,totalKnown:totalKnown}
end function

' Reserve a fair share of the remaining operation deadline for each source.
' The injected offline fetcher has no clock; only real network requests use it.
sub rpHdTaskBeginSlice(remaining as integer)
    m.hdProviderDeadline = 0
    if remaining < 1 then remaining = 1
    if m.hdElapsed <> invalid
        now = m.hdElapsed.totalMilliseconds()
        budget = (40000-now) \ remaining
        if budget < 0 then budget = 0
        m.hdProviderDeadline = now+budget
    end if
end sub

function rpHdTaskSliceExpired() as boolean
    if m.hdElapsed = invalid then return false
    now = m.hdElapsed.totalMilliseconds()
    if now >= 40000 then return true
    if GetInterface(m.hdProviderDeadline,"ifInt") <> invalid
        if m.hdProviderDeadline > 0 and now >= m.hdProviderDeadline then return true
    end if
    return false
end function

function rpHdTaskLoadEpisodes(parent as object, season as integer, fetcher as dynamic) as object
    answer = {ok:false,cancelled:false,message:"No se pudieron cargar los episodios HD.",seasons:[],seasonNumbers:[]}
    provider = parent.provider
    pages = []
    declared = []
    page = 1
    complete = false
    for attempt = 1 to 12
        endpoint = rpHdOnlineEndpoint(provider,"episodes",{id:parent.providerId,season:season,page:page})
        response = rpHdTaskFetchJson(endpoint,fetcher)
        if not response.ok then return rpHdTaskFailure(answer,response)
        normalized = rpHdOnlineEpisodes(response.data,provider,parent)
        pages.push(normalized.seasons)
        for each number in normalized.seasonNumbers
            if not rpHdTaskHasNumber(declared,number) then declared.push(number)
        end for
        if not normalized.hasMore or provider = "allcalidad"
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
    merged = rpHdTaskMergeSeasons(pages,declared,season,provider = "allcalidad")
    answer.seasons = merged.seasons
    answer.seasonNumbers = merged.seasonNumbers
    answer.ok = answer.seasons.count() > 0
    if answer.ok then answer.message = ""
    return answer
end function

function rpHdTaskMergeSeasons(pages as object, declared as object, requested as integer, allLoaded as boolean) as object
    map = {}
    seen = {}
    for each page in pages
        for each season in page
            key = season.number.toStr()
            if not map.doesExist(key) then map[key] = {number:season.number,episodes:[],loaded:true}
            for each item in season.episodes
                if not seen.doesExist(item.id)
                    map[key].episodes.push(item)
                    seen[item.id] = true
                end if
            end for
        end for
    end for
    for each number in declared
        key = number.toStr()
        if not map.doesExist(key) then map[key] = {number:number,episodes:[],loaded:allLoaded or number = requested}
    end for
    answer = {seasons:[],seasonNumbers:[]}
    for number = 0 to 999
        key = number.toStr()
        if map.doesExist(key)
            map[key].episodes.sortBy("episode")
            answer.seasons.push(map[key])
            answer.seasonNumbers.push(number)
        end if
    end for
    return answer
end function

function rpHdTaskHasNumber(numbers as object, value as integer) as boolean
    for each number in numbers
        if number = value then return true
    end for
    return false
end function

function rpHdTaskInputItem(value as dynamic, provider as string) as dynamic
    if type(value) <> "roAssociativeArray" or provider = "" or provider = "all" then return invalid
    number = orbitInteger(value.providerId,999999999)
    kind = orbitText(value.kind,10)
    if number < 1 or rpHdOnlineProvider(value.provider) <> provider then return invalid
    if kind <> "movie" and kind <> "series" and kind <> "episode" then return invalid
    id = "hdo-"+provider+"-"+number.toStr()
    if value.id <> id then return invalid
    return {
        id:id,imdbId:"",kind:kind,library:"hd-online",provider:provider,providerId:number
        providerSlug:orbitText(value.providerSlug,200),title:orbitText(value.title,200)
        poster:orbitHttpsUrl(value.poster),background:orbitHttpsUrl(value.background)
        description:orbitText(value.description),year:orbitText(value.year,4)
        runtime:orbitInteger(value.runtime,86400),language:"",seasons:[]
        season:orbitInteger(value.season,999),episode:orbitInteger(value.episode,9999)
        seriesTitle:orbitText(value.seriesTitle,200)
    }
end function

function rpHdTaskFetchJson(endpoint as string, fetcher as dynamic) as object
    response = fetcher(endpoint,"api","")
    if not response.ok then return response
    body = response.body
    if instr(1,endpoint,"https://cinehax.org/api/rest/v1/") = 1 then body = rpHdCinehaxJsonText(body)
    data = ParseJson(body)
    if type(data) <> "roAssociativeArray"
        response.ok = false
        response.message = "La fuente HD devolvió datos que no se pueden leer."
        return response
    end if
    response.data = data
    return response
end function

function rpHdTaskFetchCatalog(endpoint as string, provider as string, fetcher as dynamic) as object
    response = rpHdTaskFetchJson(endpoint,fetcher)
    if not response.ok then return response
    valid = false
    if provider = "cinehax"
        valid = type(response.data.items) = "roArray"
    else if type(response.data.data) = "roAssociativeArray"
        valid = type(response.data.data.posts) = "roArray"
    end if
    if not valid
        response.ok = false
        response.message = "La fuente HD no devolvió un catálogo válido."
    end if
    return response
end function

function rpHdTaskFailure(answer as object, response as object) as object
    answer.ok = false
    answer.cancelled = response.cancelled = true
    message = orbitText(response.message,200)
    if message <> "" then answer.message = message
    return answer
end function

' The sampled Vimeos variants mux Spanish AAC; when external audio is declared,
' require a Spanish default for the selected group as an additional guard.
function rpHdTaskSpanishAudio(master as object, variant as object) as boolean
    if variant.audioGroup = "" then return true
    for each track in master.audioTracks
        if track.group = variant.audioGroup
            if track.default
                language = lcase(track.language)
                name = lcase(track.name)
                if language <> "" then return language = "es" or language = "spa" or left(language,3) = "es-"
                return instr(1,name,"español") > 0 or instr(1,name,"spanish") > 0 or instr(1,name,"latino") > 0 or instr(1,name,"castellano") > 0
            end if
        end if
    end for
    return false
end function

function rpHdTaskMediaManifest(body as dynamic, baseUrl as string) as boolean
    text = orbitText(body,2097153)
    if len(text) > 2097152 or left(text,7) <> "#EXTM3U" then return false
    if rpHdOnlineCdn(baseUrl) = "" then return false
    segments = 0
    for each raw in text.split(chr(10))
        line = raw.trim()
        if left(line,11) = "#EXT-X-KEY:"
            attrs = rpHdOnlineAttributes(line)
            if attrs.METHOD <> "NONE" then return false
        else if left(line,18) = "#EXT-X-STREAM-INF:"
            return false
        else if left(line,11) = "#EXT-X-MAP:"
            attrs = rpHdOnlineAttributes(line)
            if rpHdOnlineJoin(baseUrl,orbitText(attrs.URI,4096)) = "" then return false
        else if line <> "" and left(line,1) <> "#"
            if rpHdOnlineJoin(baseUrl,line) = "" then return false
            segments++
        end if
    end for
    return segments > 0
end function

function rpHdTaskExternalAudio(master as object, variant as object) as boolean
    for each track in master.audioTracks
        if track.group = variant.audioGroup and track.url <> "" then return true
    end for
    return false
end function

function rpHdTaskFirstSegment(body as string, baseUrl as string) as string
    for each raw in body.split(chr(10))
        line = raw.trim()
        if line <> "" and left(line,1) <> "#" then return rpHdOnlineJoin(baseUrl,line)
    end for
    return ""
end function

function rpHdTaskCanDecode(variant as object) as boolean
    format = rpHdTaskDecodeFormat(variant)
    if format = invalid then return false
    device = CreateObject("roDeviceInfo")
    for each codec in ["mpeg4 avc","h264"]
        response = device.canDecodeVideo({"codec":codec,"profile":format.profile,"level":format.capabilityLevel})
        if type(response) = "roAssociativeArray"
            if GetInterface(response.result,"ifBoolean") <> invalid
                if response.result then return true
            end if
        end if
    end for
    return false
end function

' CanDecodeVideo reports supported capability ceilings, not every source level.
' The JVC reports AVC high 4.1=true but 3.2/4.0=false with updated level=[4.1,4.2].
' Require the confirmed 4.1 ceiling only after validating an AVC <=4.1 source.
function rpHdTaskDecodeFormat(variant as dynamic) as dynamic
    if type(variant) <> "roAssociativeArray" then return invalid
    codecs = lcase(orbitText(variant.codecs,200))
    match = CreateObject("roRegex","(^|,)\s*avc1\.([0-9a-f]{6})(\s*,|$)","").match(codecs)
    aac = CreateObject("roRegex","(^|,)\s*mp4a\.40\.2(\s*,|$)","").isMatch(codecs)
    if match.count() < 3 or not aac or codecs.split(",").count() <> 2 then return invalid
    profileNumber = rpHdOnlineHex(left(match[2],2))
    levelNumber = rpHdOnlineHex(right(match[2],2))
    profile = ""
    if profileNumber = 66 then profile = "baseline"
    if profileNumber = 77 then profile = "main"
    if profileNumber = 100 then profile = "high"
    if profile = "" or levelNumber < 10 or levelNumber > 41 then return invalid
    validLevel = false
    for each level in [10,11,12,13,20,21,22,30,31,32,40,41]
        if levelNumber = level then validLevel = true
    end for
    if not validLevel then return invalid
    return {profile:profile,capabilityLevel:"4.1",sourceLevel:levelNumber}
end function

function rpHdTaskUserAgent() as string
    return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
end function

function rpHdTaskProviderReferer(provider as string) as string
    if provider = "lamovie" then return "https://lamovie.org/"
    if provider = "allcalidad" then return "https://allcalidad.re/"
    if provider = "cinehax" then return "https://cinehax.org/"
    return ""
end function

function rpHdTaskAllowedUrl(endpoint as string, role as string) as boolean
    if len(endpoint) > 4096 then return false
    if CreateObject("roRegex","[\x00-\x20\x7F\\]","").isMatch(endpoint) then return false
    if role = "api" then return CreateObject("roRegex","^https://(lamovie\.org/wp-api/v1/|allcalidad\.re/api/rest/|cinehax\.org/api/rest/v1/)[^#]*$","").isMatch(endpoint)
    if role = "player" then return CreateObject("roRegex","^https://videoapp\.mov/e/(movie/[0-9]+|tv/[0-9]+/[0-9]+/[0-9]+)$","").isMatch(endpoint)
    if role = "seriesmetro-season" then return rpHdTaskSeasonPost(endpoint) <> invalid
    if role = "seriesmetro-page"
        return CreateObject("roRegex","^https://www3\.seriesmetro\.net/(cartelera-(peliculas|series)/(page/[0-9]+/)?|(pelicula|serie|capitulo)/[a-z0-9-]+/|(page/[0-9]+/)?\?s=[^#]*|\?trembed=[0-9]+&trid=[0-9]+&trtype=[0-9]+)$","").isMatch(endpoint)
    end if
    if role = "cinecalidad-page"
        return CreateObject("roRegex","^https://www\.cinecalidad\.vg/(page/[0-9]+/|pelicula/[a-z0-9-]+/)?(\?s=[^#]*)?$","").isMatch(endpoint)
    end if
    if role = "embed"
        if CreateObject("roRegex","^https://fastream\.to/(embed-)?[a-zA-Z0-9_-]+(\.html)?$","").isMatch(endpoint) then return true
        return CreateObject("roRegex","^https://vimeos\.net/embed-[a-zA-Z0-9_-]+(\.html)?(\?[^#]*)?$","").isMatch(endpoint)
    end if
    if role = "media" or role = "sample" then return rpHdOnlineCdn(endpoint) <> ""
    return false
end function

' A read-only episode listing uses one fixed WordPress action and numeric IDs.
' The browser-shaped query is never forwarded as an arbitrary POST payload.
function rpHdTaskSeasonPost(endpoint as string) as dynamic
    parts = CreateObject("roRegex","^https://www3\.seriesmetro\.net/wp-admin/admin-ajax\.php\?post=([0-9]{1,9})&season=([0-9]{1,3})$","").match(endpoint)
    if parts.count() < 3 then return invalid
    postId = orbitInteger(parts[1],999999999)
    season = orbitInteger(parts[2],999,-1)
    if postId < 1 or season < 0 then return invalid
    return {url:"https://www3.seriesmetro.net/wp-admin/admin-ajax.php",body:"action=action_select_season&post="+postId.toStr()+"&season="+season.toStr()}
end function

function rpHdTaskDownloadText(endpoint as string, role as string, referer as string) as object
    answer = {ok:false,cancelled:false,body:"",bytes:invalid,message:"No se pudo conectar con la fuente HD."}
    if not rpHdTaskAllowedUrl(endpoint,role) then return answer
    if m.top.cancelRequested
        answer.cancelled = true
        answer.message = "Consulta cancelada."
        return answer
    end if
    if rpHdTaskSliceExpired()
        answer.message = "La fuente HD tardó demasiado. Vuelve a intentar."
        return answer
    end if
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.addHeader("User-Agent",rpHdTaskUserAgent())
    if role = "api"
        transfer.addHeader("Accept","application/json")
        if referer = "" and instr(1,endpoint,"https://cinehax.org/api/rest/v1/") = 1 then referer = "https://cinehax.org/"
    end if
    if referer <> "" then transfer.addHeader("Referer",referer)
    limit = 2097152
    if role = "sample"
        transfer.addHeader("Range","bytes=0-65535")
        limit = 131072
    end if
    transfer.enableEncodings(true)
    transfer.setUrl(endpoint)
    files = CreateObject("roFileSystem")
    filename = "tmp:/rokuplus-hd-"+CreateObject("roDeviceInfo").getRandomUUID()+".txt"
    requestFile = ""
    if role = "seriesmetro-season"
        post = rpHdTaskSeasonPost(endpoint)
        transfer.setUrl(post.url)
        transfer.addHeader("Content-Type","application/x-www-form-urlencoded")
        requestFile = filename+".request"
        if not WriteAsciiFile(requestFile,post.body)
            files.delete(requestFile)
            return answer
        end if
        started = transfer.asyncPostFromFileToFile(requestFile,filename)
    else
        started = transfer.asyncGetToFile(filename)
    end if
    if not started
        files.delete(filename)
        if requestFile <> "" then files.delete(requestFile)
        return answer
    end if
    elapsed = CreateObject("roTimespan")
    elapsed.mark()
    finished = false
    code = 0
    responseHeaders = {}
    while not finished
        if m.top.cancelRequested
            answer.cancelled = true
            answer.message = "Consulta cancelada."
            exit while
        end if
        if rpHdTaskSliceExpired() or elapsed.totalMilliseconds() >= 20000
            answer.message = "La fuente HD tardó demasiado. Vuelve a intentar."
            exit while
        end if
        if rpHdTaskFileSize(files.stat(filename)) > limit
            answer.message = "La respuesta HD supera el límite permitido."
            exit while
        end if
        event = wait(50,port)
        if type(event) = "roUrlEvent"
            if event.getSourceIdentity() = transfer.getIdentity() and event.getInt() = 1
                code = event.getResponseCode()
                responseHeaders = event.getResponseHeaders()
                finished = true
            end if
        end if
    end while
    if not finished then transfer.asyncCancel()
    successCode = code = 200
    if role = "sample" then successCode = code = 206
    if finished and successCode and not m.top.cancelRequested
        bytes = rpHdTaskFileSize(files.stat(filename))
        if bytes > 0 and bytes <= limit
            if role = "sample"
                if rpHdTaskRangeResponse(responseHeaders,bytes)
                    binary = CreateObject("roByteArray")
                    if binary.readFile(filename)
                        answer.bytes = binary
                        answer.ok = binary.count() > 0 and binary.count() <= limit
                    end if
                end if
            else
                answer.body = ReadAsciiFile(filename)
                answer.ok = len(answer.body) > 0 and len(answer.body) <= limit
            end if
            if answer.ok then answer.message = ""
        end if
    end if
    files.delete(filename)
    if requestFile <> "" then files.delete(requestFile)
    return answer
end function

function rpHdTaskRangeResponse(headers as dynamic, bytes as integer) as boolean
    if type(headers) <> "roAssociativeArray" then return false
    value = ""
    for each name in headers
        if lcase(name) = "content-range" then value = orbitText(headers[name],120)
    end for
    range = CreateObject("roRegex","^bytes 0-([0-9]+)/([0-9]+|\*)$","i").match(value.trim())
    if range.count() < 3 then return false
    lastByte = orbitInteger(range[1],65535,-1)
    if lastByte < 0 or bytes <> lastByte+1 then return false
    return bytes > 0 and bytes <= 65536
end function

function rpHdTaskFileSize(info as dynamic) as integer
    if type(info) <> "roAssociativeArray" then return -1
    if not info.doesExist("size") then return -1
    size = info.size
    numeric = GetInterface(size,"ifInt") <> invalid or GetInterface(size,"ifLongInt") <> invalid or GetInterface(size,"ifFloat") <> invalid or GetInterface(size,"ifDouble") <> invalid
    if not numeric then return -1
    if size < 0 then return -1
    if size > 2097152 then return 2097153
    return int(size)
end function
