' Public HD source requests. No JavaScript evaluation, proxy or PC helper.
' Catalog aggregation keeps a 40-second total deadline and caps each provider slice at 9 seconds.
sub init()
    m.top.functionName = "runHdCatalogRequest"
end sub

sub runHdCatalogRequest()
    m.hdElapsed = CreateObject("roTimespan")
    m.hdElapsed.mark()
    m.hdTotalBudgetMs = 40000
    if m.top.operation = "resolve" or m.top.operation = "find-source" then m.hdTotalBudgetMs = 70000
    request = {
        operation:m.top.operation, kind:m.top.kind, provider:m.top.provider
        query:m.top.query, skip:m.top.skip, item:m.top.item, season:m.top.season
        requestId:m.top.requestId, attempt:m.top.attempt, tvmazeCache:m.top.tvmazeCache
    }
    answer = rpHdTaskExecute(request)
    if not m.top.cancelRequested then m.top.result = answer
end sub

' Fill missing catalog artwork and descriptive fields from Cinemeta, with TVmaze as a series fallback.
' Process every candidate until the shared 40-second task deadline or cancellation.
sub rpHdTaskEnrichCatalogMetadata(items as object, kind as string, fetcher as dynamic)
    if type(items) <> "roArray" or items.count() = 0 then return
    if kind <> "movie" and kind <> "series" then return
    candidates = []
    for each item in items
        if type(item) = "roAssociativeArray"
            title = orbitText(item.title,200).trim()
            poster = orbitText(item.poster,2048)
            background = orbitText(item.background,2048)
            description = orbitText(item.description,12000)
            year = orbitText(item.year,16)
            hasGenres = type(item.genres) = "roArray" and item.genres.count() > 0
            if title <> "" and (poster = "" or background = "" or description = "" or year = "" or not hasGenres)
                candidates.push(item)
            end if
        end if
    end for
    if candidates.count() = 0
        print "[RokuPlus cinemeta-catalog] kind="; kind; " candidates=0 reason=already_complete"
        return
    end if
    ' Process the full page candidate list until cancellation or the shared task deadline.
    ' Each candidate receives a fair slice of the remaining time; there is no fixed 14-card cap.
    candidateCount = candidates.count()
    cinemetaEnriched = 0
    tvmazeFallbacks = 0
    attempted = 0
    stopReason = "complete"
    for i = 0 to candidateCount-1
        if m.top.cancelRequested
            stopReason = "cancelled"
            exit for
        end if
        if rpHdTaskSliceExpired()
            stopReason = "deadline"
            exit for
        end if
        remaining = candidateCount-i
        rpHdTaskBeginSlice(remaining)
        item = candidates[i]
        attempted++
        answer = {ok:true,item:item}
        metadataRequest = {operation:"meta"}
        answer = rpHdCinemetaEnrichAnswer(answer,metadataRequest,fetcher)
        if orbitText(answer.metadataSource,32) = "Cinemeta"
            cinemetaEnriched++
        else if kind = "series"
            tvmazeFallbacks++
            rpHdTaskEnrichItemFromTvmaze(item,fetcher)
        else
            print "[RokuPlus cinemeta-catalog] candidate_failed kind="; kind; " title="; left(orbitText(item.title,200),100); " fallback=none"
        end if
    end for
    if m.top.cancelRequested then stopReason = "cancelled"
    if stopReason = "complete" and rpHdTaskSliceExpired() then stopReason = "deadline"
    skipped = candidateCount-attempted
    print "[RokuPlus cinemeta-catalog] kind="; kind; " candidates="; candidateCount; " attempted="; attempted; " enriched="; cinemetaEnriched; " tvmaze_fallback="; tvmazeFallbacks; " skipped_unattempted="; skipped; " stopped="; stopReason
end sub

function rpHdTaskEnrichItemFromTvmaze(item as object, fetcher as dynamic) as boolean
    title = orbitText(item.title,200).trim()
    if title = "" then return false
    searchTitle = rpHdTaskTvmazeSearchTitle(title)
    transfer = CreateObject("roUrlTransfer")
    endpoint = "https://api.tvmaze.com/search/shows?q="+transfer.escape(searchTitle)
    response = fetcher(endpoint,"tvmaze","https://www.tvmaze.com/")
    if response.cancelled then return false
    if not response.ok
        print "[RokuPlus tvmaze-catalog] result=search_failed title="; left(title,100); " status="; orbitInteger(response.httpStatus,9999)
        return false
    end if
    if rpHdTaskSliceExpired() then return false
    matches = ParseJson(response.body)
    if type(matches) <> "roArray"
        print "[RokuPlus tvmaze-catalog] result=invalid_search_json title="; left(title,100)
        return false
    end if
    targetKey = rpHdTaskCinemetaTitleKey(searchTitle)
    selected = invalid
    exactCount = 0
    for each match in matches
        if type(match) = "roAssociativeArray" and type(match.show) = "roAssociativeArray"
            candidate = match.show
            if rpHdTaskCinemetaTitleKey(candidate.name) = targetKey
                selected = candidate
                exactCount++
            end if
        end if
    end for
    if exactCount <> 1
        reason = "title_not_found"
        if exactCount > 1 then reason = "ambiguous_match"
        print "[RokuPlus tvmaze-catalog] result="; reason; " exact_match_count="; exactCount; " title="; left(title,100); " results="; matches.count()
        return false
    end if
    if type(selected.genres) <> "roArray"
        print "[RokuPlus tvmaze-catalog] result=genres_missing title="; left(title,100); " show="; orbitText(selected.name,100)
        return false
    end if
    if type(item.genres) <> "roArray" then item.genres = []
    beforeCount = item.genres.count()
    for each genre in selected.genres
        if GetInterface(genre,"ifString") <> invalid
            genreName = lcase(genre.trim())
            if genreName <> ""
                found = false
                for each savedGenre in item.genres
                    if GetInterface(savedGenre,"ifString") <> invalid and lcase(savedGenre.trim()) = genreName then found = true
                end for
                if not found then item.genres.push(genreName)
            end if
        end if
    end for
    added = item.genres.count() > beforeCount
    print "[RokuPlus tvmaze-catalog] result=matched title="; left(title,100); " show="; orbitText(selected.name,100); " genres_added="; item.genres.count()-beforeCount
    return added
end function

function rpHdTaskTvmazeSearchTitle(value as string) as string
    title = value.trim()
    key = lcase(title)
    title = CreateObject("roRegex","\s*\((19|20)[0-9]{2}\)\s*$","").replace(title,"").trim()
    if key = "avatar: la leyenda de aang" or key = "avatar: la leyenda de aang (2005)" or key = "avatar: the last airbender" or key = "avatar: the last airbender (2005)" then return "Avatar: The Last Airbender"
    if key = "hora de aventura" then return "Adventure Time"
    if key = "ben 10: fuerza alienígena" or key = "ben 10: fuerza alienígena (2008)" then return "Ben 10: Alien Force"
    if key = "ben 10: supremacía alienígena" or key = "ben 10: supremacía alienígena (2010)" then return "Ben 10: Ultimate Alien"
    if key = "viaje a las estrellas: espacio profundo nueve" or key = "viaje a las estrellas: espacio profundo nueve (1993)" then return "Star Trek: Deep Space Nine"
    if key = "el cuento de la criada" or key = "el cuento de la criada (2017)" then return "The Handmaid's Tale"
    if key = "merlina" or key = "merlina (2022)" then return "Wednesday"
    if key = "juego de tronos" or key = "juego de tronos (2011)" then return "Game of Thrones"
    if key = "bojack horseman (2014)" then return "BoJack Horseman"
    if key = "el juego del calamar" then return "Squid Game"
    if key = "el juego de la muerte" or key = "el juego de la muerte (2023)" then return "Death's Game"
    if key = "el juego de gracie darling" then return "Playing Gracie Darling"
    if key = "phony: la otra madre" then return "Phony"
    if key = "chicago en llamas" then return "Chicago Fire"
    if key = "estamos muertos" or key = "estamos muertos (2022)" then return "All of Us Are Dead"
    if key = "reacher (2022)" then return "Reacher"
    if key = "frasier (1993)" then return "Frasier"
    if key = "el rey de queens" then return "The King of Queens"
    if key = "asesinato para principiantes" or key = "asesinato para principiantes (2024)" then return "A Good Girl's Guide to Murder"
    if key = "2 chicas quebradas" or key = "2 chicas quebradas (2011)" then return "2 Broke Girls"
    if key = "el adn del delito" then return "DNA do Crime"
    if key = "anatomía según grey" then return "Grey's Anatomy"
    if key = "buscando a wanda" then return "Where's Wanda?"
    if key = "coraje, el perro cobarde" or key = "coraje, el perro cobarde (1999)" then return "Courage the Cowardly Dog"
    if key = "el intercambio" then return "Bytet"
    if key = "breaking bad (2008)" then return "Breaking Bad"
    if key = "the blacklist (2013)" then return "The Blacklist"
    if key = "la lista terminal (2022)" then return "The Terminal List"
    if key = "visionquest (2026)" then return "VisionQuest"
    return title
end function

function rpHdTaskCinemetaTitleKey(value as dynamic) as string
    title = lcase(orbitText(value,240).trim())
    ' Repair common UTF-8-as-Windows-1252 mojibake before comparing titles.
    title = title.replace("ãƒâ¡","a")
    title = title.replace("ãƒâ©","e")
    title = title.replace("ãƒâ­","i")
    title = title.replace("ãƒâ³","o")
    title = title.replace("ãƒâº","u")
    title = title.replace("ãƒâ±","n")
    title = title.replace("ã¡","a")
    title = title.replace("ã©","e")
    title = title.replace("ã­","i")
    title = title.replace("ã³","o")
    title = title.replace("ãº","u")
    title = title.replace("ã±","n")
    title = title.replace("ã¼","u")
    ' Fold accents so localized spellings compare consistently without fuzzy matching.
    title = title.replace("á","a")
    title = title.replace("à","a")
    title = title.replace("ä","a")
    title = title.replace("â","a")
    title = title.replace("é","e")
    title = title.replace("è","e")
    title = title.replace("ë","e")
    title = title.replace("ê","e")
    title = title.replace("í","i")
    title = title.replace("ì","i")
    title = title.replace("ï","i")
    title = title.replace("î","i")
    title = title.replace("ó","o")
    title = title.replace("ò","o")
    title = title.replace("ö","o")
    title = title.replace("ô","o")
    title = title.replace("ú","u")
    title = title.replace("ù","u")
    title = title.replace("ü","u")
    title = title.replace("û","u")
    title = title.replace("ñ","n")
    title = title.replace("ç","c")
    title = CreateObject("roRegex","[^a-z0-9]","").replaceAll(title,"")
    return title
end function

function rpHdTaskCinemetaYear(value as dynamic) as string
    yearText = orbitText(value,32)
    match = CreateObject("roRegex","(19|20)[0-9]{2}","").match(yearText)
    if match.count() < 1 then return ""
    return match[0]
end function

' Fetch/decoder/source injection exercises this exact orchestration offline.
function rpHdTaskExecute(request as object, fetcher = invalid as dynamic, decoderAccept = invalid as dynamic, catalogSources = invalid as dynamic) as object
    if fetcher = invalid then fetcher = rpHdTaskDownloadText
    if decoderAccept = invalid then decoderAccept = rpHdTaskCanDecode
    operation = orbitText(request.operation,20)
    kind = orbitText(request.kind,10)
    provider = rpHdOnlineProvider(request.provider)
    answer = {ok:false, cancelled:false, requestId:orbitText(request.requestId,120), operation:operation, kind:kind, provider:provider, message:"No se pudo completar la consulta HD.", subtitleTracks:[], selectedSubtitleGroup:""}
    m.hdProviderDeadline = 0
    if provider = ""
        answer.message = "Elige una fuente HD válida."
        return answer
    end if
    if operation = "search"
        return rpHdTaskGlobalSearch(request,answer,fetcher,catalogSources)
    end if
    if operation = "find-source"
        return rpHdTaskFindSource(request,answer,fetcher,decoderAccept,catalogSources)
    end if
    if operation = "cinemeta-catalog"
        return rpHdTaskCinemetaBrowseCatalog(request,answer,fetcher)
    end if
    if operation = "meta" and type(request.item) = "roAssociativeArray"
        if orbitText(request.item.discoverySource,32) = "cinemeta"
            answer.item = request.item
            answer.ok = true
            answer.message = ""
            return rpHdCinemetaEnrichAnswer(answer,request,fetcher)
        end if
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
        rpHdTaskEnrichCatalogMetadata(answer.items,kind,fetcher)
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
    if provider = "cinehax"
        answer = rpHdCinehaxTask(request,answer,fetcher,decoderAccept)
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
    end if
    if provider = "seriesmetro"
        answer = rpHdSeriesmetroTask(request,answer,fetcher,decoderAccept)
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
    end if
    if provider = "cinecalidad"
        answer = rpHdCinecalidadTask(request,answer,fetcher,decoderAccept)
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
    end if
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
            if loaded.ok
                item.seasons = loaded.seasons
                item.seasonNumbers = loaded.seasonNumbers
            else
                ' Keep the series details usable when the first episode request is temporarily unavailable.
                ' The season browser will retry this season through the normal episodes operation.
                item.seasons = [{number:1,episodes:[],loaded:false}]
                item.seasonNumbers = [1]
                print "[RokuPlus series] meta_episode_load_deferred provider="; provider; " id="; item.id
            end if
        end if
        answer.item = item
        answer.ok = true
        answer.message = ""
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
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
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
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
    resolved = rpHdTaskResolveEmbeds(embeds,provider,answer,fetcher,decoderAccept,retry)
    if resolved.ok or resolved.cancelled or provider <> "allcalidad" or resolved.voeBlocked <> true then return resolved

    ' VOE may answer with an anti-bot interstitial instead of its public player.
    ' Do not attempt to defeat that protection. Episodes do not have a safe
    ' cross-catalog identity match here, so return a clear, non-retry message.
    if item.kind <> "movie"
        resolved.message = "VOE está temporalmente protegido y no se pudo obtener un enlace compatible para este episodio."
        return resolved
    end if

    ' For movies, search other installed HD catalogs for the same exact
    ' title/year match only.
    fallbackProviders = ["lamovie","cinehax","seriesmetro","cinecalidad"]
    for fallbackIndex = 0 to fallbackProviders.count()-1
        if rpHdTaskSliceExpired() then exit for
        fallbackProvider = fallbackProviders[fallbackIndex]
        rpHdTaskBeginSlice(fallbackProviders.count()-fallbackIndex)
        catalog = rpHdTaskCatalogPage(fallbackProvider,"movie",1,item.title,fetcher)
        if catalog.cancelled then return rpHdTaskFailure(resolved,catalog)
        if catalog.ok
            for each candidate in catalog.items
                if rpHdTaskSameCatalogItem(item,candidate)
                    print "[RokuPlus source-fallback] matched title="; item.title; " from=allcalidad to="; fallbackProvider; " id="; candidate.id
                    candidateAnswer = {
                        ok:false,cancelled:false,requestId:answer.requestId
                        operation:"resolve",provider:fallbackProvider,message:""
                    }
                    ' Provider-specific catalogs must use their own resolver; the generic
                    ' online resolver does not understand CineCalidad or SeriesMetro IDs.
                    fallbackRequest = {operation:"resolve",provider:fallbackProvider,item:candidate,attempt:retry}
                    if fallbackProvider = "cinehax"
                        candidateAnswer = rpHdCinehaxTask(fallbackRequest,candidateAnswer,fetcher,decoderAccept)
                    else if fallbackProvider = "seriesmetro"
                        candidateAnswer = rpHdSeriesmetroTask(fallbackRequest,candidateAnswer,fetcher,decoderAccept)
                    else if fallbackProvider = "cinecalidad"
                        candidateAnswer = rpHdCinecalidadTask(fallbackRequest,candidateAnswer,fetcher,decoderAccept)
                    else
                        candidateAnswer = rpHdTaskResolveItem(candidate,fallbackProvider,candidateAnswer,fetcher,decoderAccept,retry)
                    end if
                    if candidateAnswer.ok
                        candidateAnswer.sourceFallback = true
                        candidateAnswer.sourceProvider = fallbackProvider
                        print "[RokuPlus source-fallback] result=accepted provider="; fallbackProvider
                        return candidateAnswer
                    end if
                    if candidateAnswer.cancelled then return candidateAnswer
                    print "[RokuPlus source-fallback] result=unavailable provider="; fallbackProvider
                end if
            end for
        end if
    end for
    resolved.message = "VOE está temporalmente protegido y no se encontró otra fuente compatible para este título."
    return resolved
end function

' Adapters may discover Vimeos links differently but share media validation.
' Playlist checks and three bounded consecutive audio-segment samples are diagnostic only.
function rpHdTaskAuditExternalAudio(master as object, selected as object, fetcher as dynamic, referer as string, videoAudit as dynamic, videoManifest as dynamic) as object
    result = {checked:0,valid:0,segments:0,durationSets:0,samples:0,tsValid:0,aacSamples:0,timingAligned:0,timingRejected:0,spanishTracksChecked:0,spanishTimingAligned:false,tracks:[]}
    videoPlaylistAudit = rpHdTaskAuditManifestTiming(videoManifest)
    print "[RokuPlus video-playlist] segments="; videoPlaylistAudit.segmentCount; " extinf="; videoPlaylistAudit.extinfCount; " sequence="; videoPlaylistAudit.mediaSequence; " discontinuities="; videoPlaylistAudit.discontinuities; " target="; videoPlaylistAudit.targetDuration; " totalDuration="; videoPlaylistAudit.totalDuration
    if type(videoAudit) = "roAssociativeArray"
        pcrPidMatchesPmt = false
        if videoAudit.audioPcrPid >= 0 and videoAudit.pmtPcrPid >= 0 then pcrPidMatchesPmt = (videoAudit.audioPcrPid = videoAudit.pmtPcrPid)
        print "[RokuPlus video-clock] pcrPid="; videoAudit.audioPcrPid; " pmtPcrPid="; videoAudit.pmtPcrPid; " pcrPidMatchesPmt="; pcrPidMatchesPmt; " pcrCount="; videoAudit.audioPcrCount; " pcrSpanMs="; videoAudit.audioPcrSpanMs; " videoPtsCount="; videoAudit.videoPtsCount; " videoFirstPts="; videoAudit.firstVideoPts; " videoLastPts="; videoAudit.lastVideoPts
    end if
    ' Inspect the final video TS segment so the audio-tail comparison uses
    ' the same playlist boundary instead of inferring video timing from segment EXTINF.
    videoSegments = rpHdTaskSegmentList(videoManifest,selected.url)
    if videoSegments.count() > 0
        videoTailIndex = videoSegments.count()-1
        videoTailSample = fetcher(videoSegments[videoTailIndex],"sample-full",referer)
        if videoTailSample.ok
            videoTailAudit = rpHdTaskAuditAudioSegment(videoTailSample.bytes)
            videoTailDuration = -1.0
            if videoPlaylistAudit.durations.count() > videoTailIndex then videoTailDuration = videoPlaylistAudit.durations[videoTailIndex]
            videoTailPtsSpanMs = -1.0
            if videoTailAudit.videoPtsCount > 0
                videoTailPtsTicks = videoTailAudit.lastVideoPts-videoTailAudit.firstVideoPts
                if videoTailPtsTicks < 0 then videoTailPtsTicks += 8589934592
                videoTailPtsSpanMs = videoTailPtsTicks/90.0
            end if
            print "[RokuPlus video-tail-audit] segment="; videoTailIndex; " extinf="; videoTailDuration
            print "[RokuPlus video-tail-audit] bytes="; videoTailAudit.bytes; " packets="; videoTailAudit.packetCount; " aligned="; videoTailAudit.aligned; " syncErrors="; videoTailAudit.syncErrors
            print "[RokuPlus video-tail-audit] videoPid="; videoTailAudit.videoPid; " videoPtsCount="; videoTailAudit.videoPtsCount; " firstPts90k="; videoTailAudit.firstVideoPts
            print "[RokuPlus video-tail-audit] lastPts90k="; videoTailAudit.lastVideoPts; " ptsSpanMs="; videoTailPtsSpanMs
            print "[RokuPlus video-tail-audit] pcrPid="; videoTailAudit.audioPcrPid; " pmtPcrPid="; videoTailAudit.pmtPcrPid; " pcrCount="; videoTailAudit.audioPcrCount; " pcrSpanMs="; videoTailAudit.audioPcrSpanMs
            print "[RokuPlus video-tail-audit] patSections="; videoTailAudit.patSectionCount; " pmtSections="; videoTailAudit.pmtSectionCount; " continuityErrors="; videoTailAudit.continuityErrors
        else
            print "[RokuPlus video-tail-audit] segment="; videoTailIndex; " request_failed status="; videoTailSample.httpStatus
        end if
    else
        print "[RokuPlus video-tail-audit] playlist_has_no_segments"
    end if
    if type(master.audioTracks) <> "roArray" then return result
    if selected.audioGroup = "" then return result
    for each track in master.audioTracks
        if track.group = selected.audioGroup and track.url <> ""
            result.checked++
            trackLanguage = lcase(orbitText(track.language,40))
            trackName = lcase(orbitText(track.name,120))
            isSpanishTrack = false
            if trackLanguage = "es" or trackLanguage = "spa" or left(trackLanguage,3) = "es-" then isSpanishTrack = true
            if instr(1,trackName,"español") > 0 or instr(1,trackName,"espanol") > 0 or instr(1,trackName,"spanish") > 0 or instr(1,trackName,"latino") > 0 or instr(1,trackName,"castellano") > 0 then isSpanishTrack = true
            if isSpanishTrack then result.spanishTracksChecked++
            trackTsValidBefore = result.tsValid
            trackAacBefore = result.aacSamples
            response = fetcher(track.url,"media",referer)
            if response.cancelled
                print "[RokuPlus audio-audit] cancelled before playlist validation"
                return result
            end if
            if response.ok and rpHdTaskMediaManifest(response.body,track.url)
                audioPlaylistAudit = rpHdTaskAuditManifestTiming(response.body)
                segments = rpHdTaskSegmentList(response.body,track.url)
                durations = rpHdTaskSegmentDurations(response.body,segments.count())
                sequenceDelta = -1
                if videoPlaylistAudit.mediaSequence >= 0 and audioPlaylistAudit.mediaSequence >= 0 then sequenceDelta = audioPlaylistAudit.mediaSequence-videoPlaylistAudit.mediaSequence
                totalDurationDeltaMs = (audioPlaylistAudit.totalDuration-videoPlaylistAudit.totalDuration)*1000.0
                timingAligned = rpHdTaskAudioTimingAligned(videoPlaylistAudit,audioPlaylistAudit)
                if timingAligned
                    result.timingAligned++
                    if isSpanishTrack then result.spanishTimingAligned = true
                else
                    result.timingRejected++
                end if
                print "[RokuPlus native-hls-audio-gate] language="; track.language; " spanish="; isSpanishTrack; " timingAligned="; timingAligned; " videoSegments="; videoPlaylistAudit.segmentCount; " audioSegments="; audioPlaylistAudit.segmentCount; " sequenceDelta="; sequenceDelta; " totalDeltaMs="; totalDurationDeltaMs
                durationPairCount = audioPlaylistAudit.durations.count()
                if videoPlaylistAudit.durations.count() < durationPairCount then durationPairCount = videoPlaylistAudit.durations.count()
                durationMismatchCount = 0
                durationDeltaSumMs = 0.0
                durationDeltaMinMs = 0.0
                durationDeltaMaxMs = 0.0
                if durationPairCount > 0
                    for durationIndex = 0 to durationPairCount-1
                        durationDeltaMs = (audioPlaylistAudit.durations[durationIndex]-videoPlaylistAudit.durations[durationIndex])*1000.0
                        durationDeltaSumMs += durationDeltaMs
                        if durationDeltaMs > 1.0 or durationDeltaMs < -1.0
                            durationMismatchCount++
                            print "[RokuPlus audio-duration-outlier] language="; track.language; " segment="; durationIndex; " videoDuration="; videoPlaylistAudit.durations[durationIndex]; " audioDuration="; audioPlaylistAudit.durations[durationIndex]; " deltaMs="; durationDeltaMs
                        end if
                        if durationIndex = 0 or durationDeltaMs < durationDeltaMinMs then durationDeltaMinMs = durationDeltaMs
                        if durationIndex = 0 or durationDeltaMs > durationDeltaMaxMs then durationDeltaMaxMs = durationDeltaMs
                    end for
                end if
                print "[RokuPlus audio-playlist] language="; track.language; " videoSegments="; videoPlaylistAudit.segmentCount; " audioSegments="; audioPlaylistAudit.segmentCount; " videoSequence="; videoPlaylistAudit.mediaSequence; " audioSequence="; audioPlaylistAudit.mediaSequence; " sequenceDelta="; sequenceDelta
                print "[RokuPlus audio-playlist] language="; track.language; " videoDiscontinuities="; videoPlaylistAudit.discontinuities; " audioDiscontinuities="; audioPlaylistAudit.discontinuities; " videoDiscSequence="; videoPlaylistAudit.discontinuitySequence; " audioDiscSequence="; audioPlaylistAudit.discontinuitySequence; " totalDurationDeltaMs="; totalDurationDeltaMs; " targetVideo="; videoPlaylistAudit.targetDuration; " targetAudio="; audioPlaylistAudit.targetDuration
                print "[RokuPlus audio-duration-audit] language="; track.language; " pairs="; durationPairCount; " mismatchesOver1ms="; durationMismatchCount; " summedDeltaMs="; durationDeltaSumMs; " minDeltaMs="; durationDeltaMinMs; " maxDeltaMs="; durationDeltaMaxMs
                print "[RokuPlus audio-playlist] language="; track.language; " videoMap="; videoPlaylistAudit.hasMap; " audioMap="; audioPlaylistAudit.hasMap; " videoKey="; videoPlaylistAudit.hasKey; " audioKey="; audioPlaylistAudit.hasKey; " videoByteRanges="; videoPlaylistAudit.byteRanges; " audioByteRanges="; audioPlaylistAudit.byteRanges
                print "[RokuPlus playlist-clock] language="; track.language; " videoFirstDate="; videoPlaylistAudit.firstProgramDateTime; " audioFirstDate="; audioPlaylistAudit.firstProgramDateTime; " videoLastDate="; videoPlaylistAudit.lastProgramDateTime; " audioLastDate="; audioPlaylistAudit.lastProgramDateTime
                if segments.count() > 0
                    result.valid++
                    result.segments += segments.count()
                    if durations.count() = segments.count() then result.durationSets++
                    print "[RokuPlus audio-audit] language="; track.language; " name="; track.name; " playlist=valid segments="; segments.count(); " durations="; durations.count()
                    sampleLimit = 3
                    if segments.count() < sampleLimit then sampleLimit = segments.count()
                    previousFirstPts = -1
                    previousLastPts = -1
                    previousDuration = 0.0
                    for segmentIndex = 0 to sampleLimit-1
                        ' Full bounded-size audio segments are required to inspect their ending PTS.
                        sample = fetcher(segments[segmentIndex],"sample-full",referer)
                        if sample.cancelled
                            print "[RokuPlus audio-audit] cancelled before full segment sample"
                            return result
                        end if
                        if sample.ok
                            result.samples++
                            audit = rpHdTaskAuditAudioSegment(sample.bytes)
                            if audit.aligned and audit.syncErrors = 0 and audit.packetCount > 0 then result.tsValid++
                            if audit.aac and audit.adtsCandidates > 0 then result.aacSamples++
                            sampleDuration = -1.0
                            if durations.count() > segmentIndex then sampleDuration = durations[segmentIndex]
                            videoSampleDuration = -1.0
                            if videoPlaylistAudit.durations.count() > segmentIndex then videoSampleDuration = videoPlaylistAudit.durations[segmentIndex]
                            durationDeltaMs = -1.0
                            if sampleDuration > 0 and videoSampleDuration > 0 then durationDeltaMs = (sampleDuration-videoSampleDuration)*1000.0
                            print "[RokuPlus playlist-segment] language="; track.language; " segment="; segmentIndex; " videoDuration="; videoSampleDuration; " audioDuration="; sampleDuration; " deltaMs="; durationDeltaMs
                            ptsSpanMs = -1.0
                            if audit.ptsCount > 0
                                ptsSpanTicks = audit.lastPts-audit.firstPts
                                if ptsSpanTicks < 0 then ptsSpanTicks += 8589934592
                                ptsSpanMs = ptsSpanTicks/90.0
                            end if
                            print "[RokuPlus audio-sample] language="; track.language; " segment="; segmentIndex; " duration="; sampleDuration; " bytes="; audit.bytes; " packets="; audit.packetCount; " trailingBytes="; audit.trailingBytes
                            print "[RokuPlus audio-sample] language="; track.language; " segment="; segmentIndex; " aligned="; audit.aligned; " syncErrors="; audit.syncErrors; " pat="; audit.patPackets; " pmt="; audit.pmtPackets
                            print "[RokuPlus audio-sample] language="; track.language; " segment="; segmentIndex; " audioPids="; audit.audioPids; " aac="; audit.aac; " audioBytes="; audit.audioElementaryBytes; " adtsFrames="; audit.adtsCandidates
                            print "[RokuPlus audio-sample] language="; track.language; " segment="; segmentIndex; " ptsCount="; audit.ptsCount; " firstPts90k="; audit.firstPts; " lastPts90k="; audit.lastPts; " ptsSpanMs="; ptsSpanMs; " continuityErrors="; audit.continuityErrors
                            print "[RokuPlus audio-adts] language="; track.language; " segment="; segmentIndex; " frames="; audit.adtsFrames; " samples="; audit.adtsSamples; " sampleRate="; audit.adtsSampleRate; " durationMs="; audit.adtsDurationMs; " invalidHeaders="; audit.adtsInvalidHeaders; " incompleteFrames="; audit.adtsIncompleteFrames
                            print "[RokuPlus audio-adts] language="; track.language; " segment="; segmentIndex; " rateMismatches="; audit.adtsSampleRateMismatches; " profile="; audit.adtsProfile; " objectType="; audit.adtsObjectType; " channels="; audit.adtsChannelConfig; " mpegId="; audit.adtsMpegId
                            print "[RokuPlus audio-adts] language="; track.language; " segment="; segmentIndex; " crcFrames="; audit.adtsCrcProtectedFrames; " frameLengthMin="; audit.adtsFrameLengthMin; " frameLengthMax="; audit.adtsFrameLengthMax; " configChanges="; audit.adtsConfigChanges; " frameBytes="; audit.adtsFrameBytes
                            print "[RokuPlus audio-pes] language="; track.language; " segment="; segmentIndex; " pesCount="; audit.audioPesRecords.count(); " headerSplit="; audit.audioPesHeaderSplitCount; " ptsDeltaMinMs="; audit.audioPtsDeltaMinMs; " ptsDeltaMaxMs="; audit.audioPtsDeltaMaxMs; " ptsDeltaAvgMs="; audit.audioPtsDeltaAvgMs; " nonMonotonic="; audit.audioPtsNonMonotonic
                            print "[RokuPlus audio-pes] language="; track.language; " segment="; segmentIndex; " dtsCount="; audit.audioPesDtsCount; " zeroLength="; audit.audioPesZeroLengthCount; " descriptorLanguages="; audit.audioDescriptorLanguages; " patSections="; audit.patSectionCount; " pmtSections="; audit.pmtSectionCount; " psiSplit="; audit.psiSplitSectionCount
                            print "[RokuPlus audio-pes] language="; track.language; " segment="; segmentIndex; " patVersion="; audit.patVersion; " pmtVersion="; audit.pmtVersion; " program="; audit.pmtProgramNumber; " pmtSection="; audit.pmtSectionNumber; "/"; audit.pmtLastSectionNumber
                            pcrPidMatchesPmt = false
                            if audit.audioPcrPid >= 0 and audit.pmtPcrPid >= 0 then pcrPidMatchesPmt = (audit.audioPcrPid = audit.pmtPcrPid)
                            pcrPtsDeltaMs = -1.0
                            if audit.audioPcrCount > 0 and audit.ptsCount > 0
                                pcrPtsDelta = audit.firstPts-audit.audioPcrFirst
                                if pcrPtsDelta > 4294967296 then pcrPtsDelta -= 8589934592
                                if pcrPtsDelta < -4294967296 then pcrPtsDelta += 8589934592
                                pcrPtsDeltaMs = pcrPtsDelta/90.0
                            end if
                            print "[RokuPlus audio-clock] language="; track.language; " segment="; segmentIndex; " pcrPid="; audit.audioPcrPid; " pmtPcrPid="; audit.pmtPcrPid; " pcrPidMatchesPmt="; pcrPidMatchesPmt; " pcrCount="; audit.audioPcrCount; " pcrSpanMs="; audit.audioPcrSpanMs; " firstPtsMinusPcrMs="; pcrPtsDeltaMs
                            print "[RokuPlus video-pes] language="; track.language; " segment="; segmentIndex; " ptsDeltaMinMs="; audit.videoPtsDeltaMinMs; " ptsDeltaMaxMs="; audit.videoPtsDeltaMaxMs; " ptsDeltaAvgMs="; audit.videoPtsDeltaAvgMs; " nonMonotonic="; audit.videoPtsNonMonotonic
                            pesLogIndex = 0
                            for each pesRecord in audit.audioPesRecords
                                print "[RokuPlus audio-pes-record] language="; track.language; " segment="; segmentIndex; " index="; pesLogIndex; " packet="; pesRecord.packetIndex; " byteOffset="; pesRecord.byteOffset; " pts90k="; pesRecord.pts; " dts90k="; pesRecord.dts; " packetLength="; pesRecord.packetLength; " headerLength="; pesRecord.headerLength
                                print "[RokuPlus audio-pes-record] language="; track.language; " segment="; segmentIndex; " index="; pesLogIndex; " expectedPayload="; pesRecord.expectedPayloadBytes; " payloadDelta="; pesRecord.payloadLengthDelta; " byteSpan="; pesRecord.byteSpan; " frameBytes="; pesRecord.frameBytes; " unparsedBytes="; pesRecord.unparsedBytes
                                print "[RokuPlus audio-pes-record] language="; track.language; " segment="; segmentIndex; " index="; pesLogIndex; " frames="; pesRecord.frameCount; " samples="; pesRecord.frameSamples; " durationMs="; pesRecord.frameDurationMs; " ptsDtsMs="; pesRecord.ptsDtsDeltaMs; " ptsDeltaMs="; pesRecord.ptsDeltaFromPreviousMs; " ptsVsPrevFrameMs="; pesRecord.ptsFrameDurationDeltaMs
                                pesLogIndex++
                            end for
                            if segmentIndex = 0 and audit.ptsCount > 0 and type(videoAudit) = "roAssociativeArray" and videoAudit.videoPtsCount > 0
                                deltaPts = audit.firstPts-videoAudit.firstVideoPts
                                if deltaPts > 4294967296 then deltaPts -= 8589934592
                                if deltaPts < -4294967296 then deltaPts += 8589934592
                                print "[RokuPlus audio-sync] language="; track.language; " videoFirstPts90k="; videoAudit.firstVideoPts; " audioFirstPts90k="; audit.firstPts; " deltaMs="; deltaPts/90.0
                            end if
                            if segmentIndex > 0 and audit.ptsCount > 0 and previousFirstPts >= 0 and previousLastPts >= 0 and previousDuration > 0
                                firstDeltaPts = audit.firstPts-previousFirstPts
                                if firstDeltaPts > 4294967296 then firstDeltaPts -= 8589934592
                                if firstDeltaPts < -4294967296 then firstDeltaPts += 8589934592
                                expectedPts = previousDuration*90000.0
                                boundaryPts = audit.firstPts-previousLastPts
                                if boundaryPts > 4294967296 then boundaryPts -= 8589934592
                                if boundaryPts < -4294967296 then boundaryPts += 8589934592
                                print "[RokuPlus audio-continuity] language="; track.language; " fromSegment="; segmentIndex-1; " toSegment="; segmentIndex; " segmentStartDeltaMs="; firstDeltaPts/90.0; " expectedSegmentMs="; expectedPts/90.0; " segmentStartDriftMs="; (firstDeltaPts-expectedPts)/90.0; " lastPesStartToNextFirstMs="; boundaryPts/90.0
                            end if
                            if audit.ptsCount > 0
                                previousFirstPts = audit.firstPts
                                previousLastPts = audit.lastPts
                            else
                                previousFirstPts = -1
                                previousLastPts = -1
                            end if
                            if durations.count() > segmentIndex then previousDuration = durations[segmentIndex] else previousDuration = 0.0
                        else
                            previousFirstPts = -1
                            previousLastPts = -1
                            previousDuration = 0.0
                            print "[RokuPlus audio-sample] language="; track.language; " segment="; segmentIndex; " request_failed status="; sample.httpStatus
                        end if
                    end for
                    lastSegmentIndex = segments.count()-1
                    if lastSegmentIndex >= sampleLimit
                        lastSample = fetcher(segments[lastSegmentIndex],"sample-full",referer)
                        if lastSample.ok
                            lastAudit = rpHdTaskAuditAudioSegment(lastSample.bytes)
                            lastDuration = -1.0
                            if durations.count() > lastSegmentIndex then lastDuration = durations[lastSegmentIndex]
                            lastPtsSpanMs = -1.0
                            if lastAudit.ptsCount > 0
                                lastPtsTicks = lastAudit.lastPts-lastAudit.firstPts
                                if lastPtsTicks < 0 then lastPtsTicks += 8589934592
                                lastPtsSpanMs = lastPtsTicks/90.0
                            end if
                            print "[RokuPlus audio-tail-audit] language="; track.language; " segment="; lastSegmentIndex; " extinf="; lastDuration
                            print "[RokuPlus audio-tail-audit] bytes="; lastAudit.bytes; " packets="; lastAudit.packetCount; " aligned="; lastAudit.aligned; " syncErrors="; lastAudit.syncErrors
                            print "[RokuPlus audio-tail-audit] ptsCount="; lastAudit.ptsCount; " firstPts90k="; lastAudit.firstPts; " lastPts90k="; lastAudit.lastPts; " ptsSpanMs="; lastPtsSpanMs
                            print "[RokuPlus audio-tail-audit] audioPids="; lastAudit.audioPids; " adtsFrames="; lastAudit.adtsFrames; " adtsSamples="; lastAudit.adtsSamples
                            print "[RokuPlus audio-tail-audit] sampleRate="; lastAudit.adtsSampleRate; " adtsDurationMs="; lastAudit.adtsDurationMs; " invalidHeaders="; lastAudit.adtsInvalidHeaders
                            print "[RokuPlus audio-tail-audit] incompleteFrames="; lastAudit.adtsIncompleteFrames; " continuityErrors="; lastAudit.continuityErrors
                        else
                            print "[RokuPlus audio-tail-audit] language="; track.language; " segment="; lastSegmentIndex; " request_failed status="; lastSample.httpStatus
                        end if
                    end if
                    if timingAligned and result.tsValid-trackTsValidBefore = sampleLimit and result.aacSamples-trackAacBefore = sampleLimit and left(track.url,8) = "https://"
                        validatedTrack = {language:track.language,name:track.name,url:track.url}
                        if type(track.default) = "Boolean" then validatedTrack.default = track.default
                        if type(track.autoselect) = "Boolean" then validatedTrack.autoselect = track.autoselect
                        result.tracks.push(validatedTrack)
                        print "[RokuPlus audio-audit] validated language="; track.language; " name="; track.name; " timingAligned=true samples="; sampleLimit
                    else
                        print "[RokuPlus audio-audit] rejected language="; track.language; " timingAligned="; timingAligned; " tsValidSamples="; result.tsValid-trackTsValidBefore; " aacSamples="; result.aacSamples-trackAacBefore
                    end if
                else
                    print "[RokuPlus audio-audit] language="; track.language; " name="; track.name; " playlist=empty"
                end if
            else
                print "[RokuPlus audio-audit] language="; track.language; " name="; track.name; " playlist=unavailable_or_rejected"
            end if
        end if
    end for
    print "[RokuPlus audio-audit] checked="; result.checked; " valid="; result.valid; " segments="; result.segments; " durationSets="; result.durationSets
    print "[RokuPlus audio-audit] samples="; result.samples; " tsValid="; result.tsValid; " aacSamples="; result.aacSamples
    print "[RokuPlus native-hls-audio-gate] alignedTracks="; result.timingAligned; " rejectedTracks="; result.timingRejected
    print "[RokuPlus native-hls-audio-gate] spanishTracksChecked="; result.spanishTracksChecked; " spanishTimingAligned="; result.spanishTimingAligned
    return result
end function

' Require matching VOD segment boundaries before considering a native HLS audio group.
' Small per-segment rounding differences are allowed; truncated tails are not.
function rpHdTaskAudioTimingAligned(video as object, audio as object) as boolean
    if video.segmentCount < 1 or audio.segmentCount < 1 then return false
    if video.extinfCount <> video.segmentCount or audio.extinfCount <> audio.segmentCount then return false
    if video.segmentCount <> audio.segmentCount then return false
    if video.mediaSequence < 0 or audio.mediaSequence < 0 then return false
    if video.mediaSequence <> audio.mediaSequence then return false
    if video.discontinuities <> audio.discontinuities then return false
    if video.discontinuitySequence <> audio.discontinuitySequence then return false
    if video.durations.count() <> video.segmentCount or audio.durations.count() <> audio.segmentCount then return false
    totalDeltaMs = (audio.totalDuration-video.totalDuration)*1000.0
    ' Permit a single shortened terminal audio segment. Some VOD playlists
    ' end audio a few seconds before the final video tail; earlier boundaries
    ' must still match and the terminal gap is capped at four seconds.
    if totalDeltaMs > 500.0 or totalDeltaMs < -4000.0 then return false
    for i = 0 to video.segmentCount-1
        deltaMs = (audio.durations[i]-video.durations[i])*1000.0
        if i = video.segmentCount-1
            if deltaMs > 250.0 or deltaMs < -4000.0 then return false
        else
            if deltaMs > 250.0 or deltaMs < -250.0 then return false
        end if
    end for
    return true
end function

' Parse HLS timing and discontinuity metadata without exposing signed segment URLs.
function rpHdTaskAuditManifestTiming(body as dynamic) as object
    result = {segmentCount:0,extinfCount:0,totalDuration:0.0,targetDuration:0.0,mediaSequence:-1,discontinuities:0,discontinuitySequence:-1,byteRanges:0,programDates:0,hasMap:false,hasKey:false,hasEndList:false,hasIndependent:false,firstProgramDateTime:"",lastProgramDateTime:"",durations:[]}
    text = orbitText(body,2097153)
    for each rawLine in text.split(chr(10))
        line = rawLine.trim()
        if left(line,8) = "#EXTINF:"
            value = mid(line,9).split(",")[0].trim().toFloat()
            result.extinfCount++
            result.durations.push(value)
            result.totalDuration += value
        else if left(line,22) = "#EXT-X-TARGETDURATION:"
            result.targetDuration = mid(line,23).trim().toFloat()
        else if left(line,22) = "#EXT-X-MEDIA-SEQUENCE:"
            result.mediaSequence = mid(line,23).trim().toInt()
        else if line = "#EXT-X-DISCONTINUITY"
            result.discontinuities++
        else if left(line,30) = "#EXT-X-DISCONTINUITY-SEQUENCE:"
            result.discontinuitySequence = mid(line,31).trim().toInt()
        else if left(line,17) = "#EXT-X-BYTERANGE:"
            result.byteRanges++
        else if left(line,25) = "#EXT-X-PROGRAM-DATE-TIME:"
            result.programDates++
            dateValue = mid(line,26).trim()
            if result.firstProgramDateTime = "" then result.firstProgramDateTime = dateValue
            result.lastProgramDateTime = dateValue
        else if left(line,11) = "#EXT-X-MAP:"
            result.hasMap = true
        else if left(line,11) = "#EXT-X-KEY:"
            result.hasKey = true
        else if left(line,14) = "#EXT-X-ENDLIST"
            result.hasEndList = true
        else if left(line,28) = "#EXT-X-INDEPENDENT-SEGMENTS"
            result.hasIndependent = true
        else if line <> "" and left(line,1) <> "#"
            result.segmentCount++
        end if
    end for
    return result
end function

' Inspect only complete 188-byte packets from a bounded sample; never mutate playback data.
function rpHdTaskAuditAudioSegment(payload as object) as object
    result = {bytes:0,packetCount:0,trailingBytes:0,aligned:false,syncErrors:0,patPackets:0,pmtPackets:0,pmtPid:-1,videoPid:-1,aac:false,audioPids:"",ptsCount:0,firstPts:-1,lastPts:-1,videoPtsCount:0,firstVideoPts:-1,lastVideoPts:-1,adtsCandidates:0,audioElementaryBytes:0,adtsFrames:0,adtsSamples:0,adtsDurationMs:0,adtsSampleRate:0,adtsInvalidHeaders:0,adtsIncompleteFrames:0,adtsSampleRateMismatches:0,adtsProfile:-1,adtsObjectType:-1,adtsChannelConfig:-1,adtsMpegId:-1,adtsCrcProtectedFrames:0,adtsFrameLengthMin:-1,adtsFrameLengthMax:0,adtsConfigChanges:0,adtsFrameBytes:0,audioPtsFrameDeltaAvgMs:-1,audioPtsFrameDeltaMaxAbsMs:-1,continuityErrors:0,audioPesRecords:[],audioPesHeaderSplitCount:0,audioPesDtsCount:0,audioPesZeroLengthCount:0,audioPtsDeltaMinMs:-1,audioPtsDeltaMaxMs:-1,audioPtsDeltaAvgMs:-1,audioPtsNonMonotonic:0,videoPtsDeltaMinMs:-1,videoPtsDeltaMaxMs:-1,videoPtsDeltaAvgMs:-1,videoPtsNonMonotonic:0,audioPcrCount:0,audioPcrPid:-1,audioPcrFirst:-1,audioPcrLast:-1,audioPcrSpanMs:-1,pmtPcrPid:-1,audioDescriptorLanguages:"",patSectionCount:0,pmtSectionCount:0,psiSplitSectionCount:0,patVersion:-1,pmtVersion:-1,pmtProgramNumber:-1,pmtSectionNumber:-1,pmtLastSectionNumber:-1,adtsPesMappedFrames:0,adtsPesUnmappedFrames:0,adtsPesMappedSamples:0}
    if type(payload) <> "roByteArray" then return result
    total = payload.count()
    result.bytes = total
    if total < 188 then return result
    result.packetCount = total \ 188
    result.trailingBytes = total mod 188
    result.aligned = true
    lastCounters = {}
    haveCounters = {}
    audioPidFlags = {}
    audioBytes = []
    videoPtsValues = []
    for packetIndex = 0 to result.packetCount-1
        offset = packetIndex*188
        if payload[offset] <> &H47
            result.syncErrors++
        else
            pid = (payload[offset+1] mod 32)*256+payload[offset+2]
            header = payload[offset+3]
            adaptationControl = (header \ 16) mod 4
            continuity = header mod 16
            hasPayload = adaptationControl = 1 or adaptationControl = 3
            discontinuity = false
            ' PCR belongs to the program clock; capture its PID and 27-MHz value.
            if adaptationControl = 2 or adaptationControl = 3
                adaptationLength = payload[offset+4]
                if adaptationLength > 0 and offset+5 < total
                    adaptationFlags = payload[offset+5]
                    if (adaptationFlags and &H80) <> 0 then discontinuity = true
                end if
                if adaptationLength >= 7 and offset+5+adaptationLength <= offset+188 and offset+11 < total
                    adaptationFlags = payload[offset+5]
                    if (adaptationFlags and &H10) <> 0
                        pcrBase = payload[offset+6]*33554432+payload[offset+7]*131072+payload[offset+8]*512+payload[offset+9]*2+(payload[offset+10] \ 128)
                        pcrExtension = (payload[offset+10] mod 2)*256+payload[offset+11]
                        pcrValue = pcrBase+pcrExtension/300.0
                        if result.audioPcrCount = 0
                            result.audioPcrFirst = pcrValue
                            result.audioPcrPid = pid
                        end if
                        result.audioPcrLast = pcrValue
                        result.audioPcrCount++
                    end if
                end if
            end if
            payloadStart = offset+4
            if adaptationControl = 3 then payloadStart = offset+5+payload[offset+4]
            if hasPayload and payloadStart < offset+188
                key = pid.toStr()
                if pid <> 8191
                    if haveCounters[key] = true
                        if continuity <> lastCounters[key] and continuity <> ((lastCounters[key]+1) mod 16) and not discontinuity then result.continuityErrors++
                    end if
                    lastCounters[key] = continuity
                    haveCounters[key] = true
                end if
                if pid = 0
                    pointer = payload[payloadStart]
                    sectionStart = payloadStart+1+pointer
                    if sectionStart+12 <= offset+188 and payload[sectionStart] = 0
                        sectionLength = (payload[sectionStart+1] mod 16)*256+payload[sectionStart+2]
                        sectionEnd = sectionStart+3+sectionLength
                        if sectionEnd <= offset+188
                            result.patSectionCount++
                            result.patVersion = (payload[sectionStart+5] \ 2) mod 32
                            entry = sectionStart+8
                            while entry+4 <= sectionEnd-4
                                programNumber = payload[entry]*256+payload[entry+1]
                                if programNumber > 0
                                    result.pmtPid = (payload[entry+2] mod 32)*256+payload[entry+3]
                                    exit while
                                end if
                                entry += 4
                            end while
                        else
                            result.psiSplitSectionCount++
                        end if
                    end if
                else if pid = result.pmtPid and result.pmtPid >= 0
                    pointer = payload[payloadStart]
                    sectionStart = payloadStart+1+pointer
                    if sectionStart+12 <= offset+188 and payload[sectionStart] = 2
                        result.pmtPcrPid = (payload[sectionStart+8] mod 32)*256+payload[sectionStart+9]
                        sectionLength = (payload[sectionStart+1] mod 16)*256+payload[sectionStart+2]
                        sectionEnd = sectionStart+3+sectionLength
                        if sectionEnd <= offset+188
                            result.pmtPackets++
                            result.pmtSectionCount++
                            result.pmtProgramNumber = payload[sectionStart+3]*256+payload[sectionStart+4]
                            result.pmtVersion = (payload[sectionStart+5] \ 2) mod 32
                            result.pmtSectionNumber = payload[sectionStart+6]
                            result.pmtLastSectionNumber = payload[sectionStart+7]
                            programInfoLength = (payload[sectionStart+10] mod 16)*256+payload[sectionStart+11]
                            entry = sectionStart+12+programInfoLength
                            while entry+5 <= sectionEnd-4
                                streamType = payload[entry]
                                elementaryPid = (payload[entry+1] mod 32)*256+payload[entry+2]
                                esInfoLength = (payload[entry+3] mod 16)*256+payload[entry+4]
                                if streamType = 27
                                    result.videoPid = elementaryPid
                                else if streamType = 15 or streamType = 17
                                    result.aac = true
                                    descriptorOffset = entry+5
                                    descriptorEnd = descriptorOffset+esInfoLength
                                    while descriptorOffset+2 <= descriptorEnd
                                        descriptorTag = payload[descriptorOffset]
                                        descriptorLength = payload[descriptorOffset+1]
                                        if descriptorOffset+2+descriptorLength > descriptorEnd then exit while
                                        if descriptorTag = 10 and descriptorLength >= 4
                                            descriptorLanguage = chr(payload[descriptorOffset+2])+chr(payload[descriptorOffset+3])+chr(payload[descriptorOffset+4])
                                            if result.audioDescriptorLanguages <> "" then result.audioDescriptorLanguages += ","
                                            result.audioDescriptorLanguages += descriptorLanguage
                                        end if
                                        descriptorOffset += 2+descriptorLength
                                    end while
                                    if not audioPidFlags.doesExist(elementaryPid.toStr())
                                        audioPidFlags[elementaryPid.toStr()] = true
                                        if result.audioPids <> "" then result.audioPids += ","
                                        result.audioPids += elementaryPid.toStr()
                                    end if
                                end if
                                entry += 5+esInfoLength
                            end while
                        else
                            result.psiSplitSectionCount++
                        end if
                    end if
                end if
                isAudioPid = audioPidFlags.doesExist(pid.toStr()) and audioPidFlags[pid.toStr()]
                isVideoPid = pid = result.videoPid and result.videoPid >= 0
                if isAudioPid or isVideoPid
                    dataStart = payloadStart
                    payloadUnitStart = (payload[offset+1] and &H40) <> 0
                    if payloadUnitStart and payloadStart+9 < offset+188 and payload[payloadStart] = 0 and payload[payloadStart+1] = 0 and payload[payloadStart+2] = 1
                        pesFlags = (payload[payloadStart+7] \ 64) mod 4
                        pesHeaderLength = payload[payloadStart+8]
                        if isAudioPid and payloadStart+9+pesHeaderLength > offset+188
                            result.audioPesHeaderSplitCount++
                            dataStart = offset+188
                        end if
                        if (pesFlags = 2 or pesFlags = 3) and pesHeaderLength >= 5 and payloadStart+14 <= offset+188
                            pts = rpHdTaskReadPts(payload,payloadStart+9)
                            dts = -1
                            if pesFlags = 3 and pesHeaderLength >= 10 and payloadStart+19 <= offset+188
                                dts = rpHdTaskReadPts(payload,payloadStart+14)
                            end if
                            pesPacketLength = payload[payloadStart+4]*256+payload[payloadStart+5]
                            if pts >= 0
                                if isAudioPid
                                    if result.ptsCount = 0 then result.firstPts = pts
                                    result.lastPts = pts
                                    result.ptsCount++
                                    if dts >= 0 then result.audioPesDtsCount++
                                    if pesPacketLength = 0 then result.audioPesZeroLengthCount++
                                    result.audioPesRecords.push({byteOffset:audioBytes.count(),pts:pts,dts:dts,packetLength:pesPacketLength,headerLength:pesHeaderLength,packetIndex:packetIndex,ptsDeltaFromPreviousMs:-1.0,ptsFrameDurationDeltaMs:-1.0})
                                else
                                    if result.videoPtsCount = 0 then result.firstVideoPts = pts
                                    result.lastVideoPts = pts
                                    result.videoPtsCount++
                                    videoPtsValues.push(pts)
                                end if
                            end if
                        end if
                        if payloadStart+9+pesHeaderLength <= offset+188 then dataStart = payloadStart+9+pesHeaderLength
                    end if
                    if isAudioPid and dataStart < offset+188
                        for scan = dataStart to offset+187
                            audioBytes.push(payload[scan])
                        end for
                    end if
                end if
            end if
        end if
    end for
    result.audioElementaryBytes = audioBytes.count()
    adts = rpHdTaskAuditAdtsBytes(audioBytes)
    result.adtsCandidates = adts.frames
    result.adtsFrames = adts.frames
    result.adtsSamples = adts.samples
    result.adtsDurationMs = adts.durationMs
    result.adtsSampleRate = adts.sampleRate
    result.adtsInvalidHeaders = adts.invalidHeaders
    result.adtsIncompleteFrames = adts.incompleteFrames
    result.adtsSampleRateMismatches = adts.sampleRateMismatches
    result.adtsProfile = adts.profile
    result.adtsObjectType = adts.objectType
    result.adtsChannelConfig = adts.channelConfig
    result.adtsMpegId = adts.mpegId
    result.adtsCrcProtectedFrames = adts.crcProtectedFrames
    result.adtsFrameLengthMin = adts.frameLengthMin
    result.adtsFrameLengthMax = adts.frameLengthMax
    result.adtsConfigChanges = adts.configChanges
    result.adtsFrameBytes = adts.frameBytes
    ' Associate ADTS frame byte offsets with each PES PTS record.
    for recordIndex = 0 to result.audioPesRecords.count()-1
        record = result.audioPesRecords[recordIndex]
        nextOffset = audioBytes.count()
        if recordIndex+1 < result.audioPesRecords.count()
            nextOffset = result.audioPesRecords[recordIndex+1].byteOffset
        end if
        mappedFrames = 0
        for each frameOffset in adts.frameOffsets
            if frameOffset >= record.byteOffset and frameOffset < nextOffset then mappedFrames++
        end for
        mappedSamples = 0
        for frameIndex = 0 to adts.frameOffsets.count()-1
            frameOffset = adts.frameOffsets[frameIndex]
            if frameOffset >= record.byteOffset and frameOffset < nextOffset
                mappedSamples += adts.frameSamples[frameIndex]
            end if
        end for
        record.frameCount = mappedFrames
        record.frameSamples = mappedSamples
        record.frameDurationMs = 0.0
        record.frameBytes = 0
        for frameIndex = 0 to adts.frameOffsets.count()-1
            frameOffset = adts.frameOffsets[frameIndex]
            if frameOffset >= record.byteOffset and frameOffset < nextOffset
                record.frameBytes += adts.frameLengths[frameIndex]
            end if
        end for
        record.byteSpan = nextOffset-record.byteOffset
        record.unparsedBytes = record.byteSpan-record.frameBytes
        record.expectedPayloadBytes = -1
        if record.packetLength > 0 then record.expectedPayloadBytes = record.packetLength-3-record.headerLength
        record.payloadLengthDelta = -1
        if record.expectedPayloadBytes >= 0 then record.payloadLengthDelta = record.byteSpan-record.expectedPayloadBytes
        record.ptsDtsDeltaMs = -1.0
        if record.dts >= 0
            ptsDtsDelta = record.pts-record.dts
            if ptsDtsDelta > 4294967296 then ptsDtsDelta -= 8589934592
            if ptsDtsDelta < -4294967296 then ptsDtsDelta += 8589934592
            record.ptsDtsDeltaMs = ptsDtsDelta/90.0
        end if
        if adts.sampleRate > 0 then record.frameDurationMs = mappedSamples*1000.0/adts.sampleRate
        result.adtsPesMappedFrames += mappedFrames
        result.adtsPesMappedSamples += mappedSamples
    end for
    result.adtsPesUnmappedFrames = result.adtsFrames-result.adtsPesMappedFrames
    ptsFrameErrorTotal = 0.0
    ptsFrameErrorMaxAbs = 0.0
    ptsFrameErrorCount = 0
    for recordIndex = 1 to result.audioPesRecords.count()-1
        previousRecord = result.audioPesRecords[recordIndex-1]
        currentRecord = result.audioPesRecords[recordIndex]
        ptsFrameDelta = currentRecord.pts-previousRecord.pts
        if ptsFrameDelta > 4294967296 then ptsFrameDelta -= 8589934592
        if ptsFrameDelta < -4294967296 then ptsFrameDelta += 8589934592
        currentRecord.ptsDeltaFromPreviousMs = ptsFrameDelta/90.0
        currentRecord.ptsFrameDurationDeltaMs = currentRecord.ptsDeltaFromPreviousMs-previousRecord.frameDurationMs
        ptsFrameError = abs(currentRecord.ptsFrameDurationDeltaMs)
        if ptsFrameError > ptsFrameErrorMaxAbs then ptsFrameErrorMaxAbs = ptsFrameError
        ptsFrameErrorTotal += currentRecord.ptsFrameDurationDeltaMs
        ptsFrameErrorCount++
    end for
    if ptsFrameErrorCount > 0
        result.audioPtsFrameDeltaAvgMs = ptsFrameErrorTotal/ptsFrameErrorCount
        result.audioPtsFrameDeltaMaxAbsMs = ptsFrameErrorMaxAbs
    end if
    if result.audioPesRecords.count() > 1
        deltaTotal = 0.0
        deltaCount = 0
        for recordIndex = 1 to result.audioPesRecords.count()-1
            previousRecord = result.audioPesRecords[recordIndex-1]
            currentRecord = result.audioPesRecords[recordIndex]
            delta = currentRecord.pts-previousRecord.pts
            if delta > 4294967296 then delta -= 8589934592
            if delta < -4294967296 then delta += 8589934592
            deltaMs = delta/90.0
            if deltaCount = 0 or deltaMs < result.audioPtsDeltaMinMs then result.audioPtsDeltaMinMs = deltaMs
            if deltaCount = 0 or deltaMs > result.audioPtsDeltaMaxMs then result.audioPtsDeltaMaxMs = deltaMs
            if deltaMs <= 0 then result.audioPtsNonMonotonic++
            deltaTotal += deltaMs
            deltaCount++
        end for
        if deltaCount > 0 then result.audioPtsDeltaAvgMs = deltaTotal/deltaCount
    end if
    if videoPtsValues.count() > 1
        videoDeltaTotal = 0.0
        videoDeltaCount = 0
        for recordIndex = 1 to videoPtsValues.count()-1
            videoDelta = videoPtsValues[recordIndex]-videoPtsValues[recordIndex-1]
            if videoDelta > 4294967296 then videoDelta -= 8589934592
            if videoDelta < -4294967296 then videoDelta += 8589934592
            videoDeltaMs = videoDelta/90.0
            if videoDeltaCount = 0 or videoDeltaMs < result.videoPtsDeltaMinMs then result.videoPtsDeltaMinMs = videoDeltaMs
            if videoDeltaCount = 0 or videoDeltaMs > result.videoPtsDeltaMaxMs then result.videoPtsDeltaMaxMs = videoDeltaMs
            if videoDeltaMs <= 0 then result.videoPtsNonMonotonic++
            videoDeltaTotal += videoDeltaMs
            videoDeltaCount++
        end for
        if videoDeltaCount > 0 then result.videoPtsDeltaAvgMs = videoDeltaTotal/videoDeltaCount
    end if
    if result.audioPcrCount > 1
        pcrDelta = result.audioPcrLast-result.audioPcrFirst
        if pcrDelta < 0 then pcrDelta += 8589934592
        result.audioPcrSpanMs = pcrDelta/90.0
    end if
    result.patPackets = 0
    for packetIndex = 0 to result.packetCount-1
        offset = packetIndex*188
        if payload[offset] = &H47
            pid = (payload[offset+1] mod 32)*256+payload[offset+2]
            if pid = 0 then result.patPackets++
        end if
    end for
    return result
end function

' Validate complete ADTS frames in the reconstructed AAC elementary-stream bytes.
function rpHdTaskAuditAdtsBytes(data as object) as object
    result = {frames:0,samples:0,durationMs:0,sampleRate:0,invalidHeaders:0,incompleteFrames:0,frameOffsets:[],frameSamples:[],frameLengths:[],sampleRateMismatches:0,profile:-1,objectType:-1,channelConfig:-1,mpegId:-1,crcProtectedFrames:0,frameLengthMin:-1,frameLengthMax:0,configChanges:0,frameBytes:0}
    if type(data) <> "roArray" then return result
    total = data.count()
    offset = 0
    while offset+7 <= total
        if data[offset] = 255 and (data[offset+1] and &HF6) = &HF0
            protectionAbsent = data[offset+1] mod 2
            sampleRateIndex = (data[offset+2] \ 4) mod 16
            frameLength = (data[offset+3] mod 4)*2048+data[offset+4]*8+(data[offset+5] \ 32)
            headerLength = 7
            if protectionAbsent = 0 then headerLength = 9
            if sampleRateIndex < 13 and frameLength >= headerLength
                if offset+frameLength > total
                    result.incompleteFrames++
                    exit while
                end if
                sampleRates = [96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350]
                rate = sampleRates[sampleRateIndex]
                profile = (data[offset+2] \ 64) mod 4
                mpegId = (data[offset+1] \ 8) mod 2
                channelConfig = (data[offset+2] mod 2)*4+((data[offset+3] \ 64) mod 4)
                if result.frames = 0
                    result.profile = profile
                    result.objectType = profile+1
                    result.channelConfig = channelConfig
                    result.mpegId = mpegId
                else if result.profile <> profile or result.channelConfig <> channelConfig or result.mpegId <> mpegId
                    result.configChanges++
                end if
                if protectionAbsent = 0 then result.crcProtectedFrames++
                if result.frameLengthMin < 0 or frameLength < result.frameLengthMin then result.frameLengthMin = frameLength
                if frameLength > result.frameLengthMax then result.frameLengthMax = frameLength
                result.frameBytes += frameLength
                rawBlocks = data[offset+6] mod 4
                frameSamples = 1024*(rawBlocks+1)
                result.frames++
                result.frameOffsets.push(offset)
                result.frameSamples.push(frameSamples)
                result.frameLengths.push(frameLength)
                result.samples += frameSamples
                result.durationMs += (frameSamples*1000.0)/rate
                if result.sampleRate = 0
                    result.sampleRate = rate
                else if result.sampleRate <> rate
                    result.sampleRateMismatches++
                end if
                offset += frameLength
            else
                result.invalidHeaders++
                offset++
            end if
        else
            offset++
        end if
    end while
    return result
end function

function rpHdTaskReadPts(payload as object, offset as integer) as dynamic
    if offset < 0 or offset+4 >= payload.count() then return -1
    b0 = payload[offset]
    b1 = payload[offset+1]
    b2 = payload[offset+2]
    b3 = payload[offset+3]
    b4 = payload[offset+4]
    prefix = b0 \ 16
    if prefix <> 1 and prefix <> 2 and prefix <> 3 then return -1
    if (b0 mod 2) <> 1 or (b2 mod 2) <> 1 or (b4 mod 2) <> 1 then return -1
    ' MPEG-2 PTS/DTS: marker bits are excluded; preserve all 33 timestamp bits.
    return ((b0 mod 16) \ 2)*1073741824+b1*4194304+(b2 \ 2)*32768+b3*128+(b4 \ 2)
end function

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
        embedUrl = orbitText(embed.url,2048)
        answer.sourceHost = "other"
        if CreateObject("roRegex","^https://fastream\.to/(embed-)?[a-zA-Z0-9_-]+(\.html)?$","i").isMatch(embedUrl)
            answer.sourceHost = "fastream"
        end if
        ' Only VOE is routed to the dedicated host-player instance for now.
        ' Keep Fastream, Vimeos and every existing provider on the standard
        ' player until a separate host adapter is explicitly validated.
        ' Reset for every candidate to prevent provider crossover.
        answer.playbackEngine = "standard"
        if CreateObject("roRegex","^https://(www\.)?voe\.sx/","i").isMatch(orbitText(embed.url,2048)) or CreateObject("roRegex","^https://arianathankspecial\.com/","i").isMatch(orbitText(embed.url,2048))
            answer.playbackEngine = "host"
        end if
        ' The HLS host may validate the page that embeds its player.
        ' Use the exact validated embed page as Referer instead of a fixed site root.
        mediaReferer = embed.url
        answer.embedAttempts++
        rpHdTaskBeginResolveSlice(count-i)
        response = fetcher(embed.url,"embed",embedReferer)
        if response.cancelled then return rpHdTaskFailure(answer,response)
        if response.ok
            if orbitText(response.httpFinalUrl,4096) <> "" then mediaReferer = response.httpFinalUrl
            masterUrl = rpHdOnlineMediaUrl(response.body)
            voeEmbedPage = instr(1,lcase(embed.url),"voe.sx") > 0 or instr(1,lcase(embed.url),"arianathankspecial.com") > 0
            if masterUrl = "" and voeEmbedPage
                masterUrl = rpHdOnlineVoeMediaUrl(response.body)
                if masterUrl <> "" then print "[RokuPlus voe] extractor=obfuscated-json result=hls"
            end if
            if masterUrl = "" and voeEmbedPage
                bodyLower = lcase(orbitText(response.body,65536))
                serverLower = lcase(orbitText(response.httpServer,80))
                bodyChallenge = instr(1,bodyLower,"ddos-guard") > 0 or instr(1,bodyLower,"checking your browser") > 0 or instr(1,bodyLower,"captcha") > 0 or instr(1,bodyLower,"challenge-platform") > 0 or instr(1,bodyLower,"cf-chl-") > 0 or instr(1,bodyLower,"verify you are human") > 0 or instr(1,bodyLower,"enable javascript and cookies") > 0
                serverGuard = instr(1,serverLower,"ddos-guard") > 0
                ' A server header is only a hint: the response body must contain
                ' an actual challenge marker before this session is marked blocked.
                antiBotPage = bodyChallenge
                ' If the canonical VOE host appears guarded, try the same public
                ' embed ID on its known alternate HTTPS hostname. This does not
                ' solve or bypass any challenge/CAPTCHA.
                if (serverGuard or antiBotPage) and instr(1,lcase(embed.url),"voe.sx") > 0
                    voeMatch = CreateObject("roRegex","^https://(www\.)?voe\.sx/(e/)?([a-z0-9]{8,20})/?$","i").match(embed.url)
                    if voeMatch.count() >= 4
                        alternateUrl = "https://arianathankspecial.com/e/"+lcase(voeMatch[3])
                        print "[RokuPlus voe] alternate_host_attempt=1 host=arianathankspecial.com"
                        alternateResponse = fetcher(alternateUrl,"embed",embedReferer)
                        if alternateResponse.cancelled then return rpHdTaskFailure(answer,alternateResponse)
                        if alternateResponse.ok
                            response = alternateResponse
                            mediaReferer = alternateUrl
                            if orbitText(response.httpFinalUrl,4096) <> "" then mediaReferer = response.httpFinalUrl
                            masterUrl = rpHdOnlineMediaUrl(response.body)
                            if masterUrl = "" then masterUrl = rpHdOnlineVoeMediaUrl(response.body)
                            if masterUrl <> ""
                                print "[RokuPlus voe] alternate_host_result=media-found"
                            else
                                alternateBodyLower = lcase(orbitText(response.body,65536))
                                alternateServerLower = lcase(orbitText(response.httpServer,80))
                                antiBotPage = instr(1,alternateBodyLower,"ddos-guard") > 0 or instr(1,alternateBodyLower,"checking your browser") > 0 or instr(1,alternateBodyLower,"captcha") > 0 or instr(1,alternateBodyLower,"challenge-platform") > 0 or instr(1,alternateBodyLower,"cf-chl-") > 0 or instr(1,alternateBodyLower,"verify you are human") > 0 or instr(1,alternateBodyLower,"enable javascript and cookies") > 0
                                ' Record only structural markers; never print page source, tokens, cookies or URLs.
                                print "[RokuPlus voe] page_probe json_script="; instr(1,alternateBodyLower,"application/json") > 0; " voeplayer="; instr(1,alternateBodyLower,"voeplayer") > 0; " file_key="; instr(1,alternateBodyLower,chr(34)+"file"+chr(34)) > 0
                                print "[RokuPlus voe] page_probe source_key="; instr(1,alternateBodyLower,chr(34)+"source"+chr(34)) > 0; " sources_key="; instr(1,alternateBodyLower,chr(34)+"sources"+chr(34)) > 0; " hls_key="; instr(1,alternateBodyLower,chr(34)+"hls"+chr(34)) > 0
                                print "[RokuPlus voe] page_probe stream_urls="; instr(1,alternateBodyLower,"stream_urls") > 0; " m3u8="; instr(1,alternateBodyLower,".m3u8") > 0; " mp4="; instr(1,alternateBodyLower,".mp4") > 0
                                print "[RokuPlus voe] page_probe videojs="; instr(1,alternateBodyLower,"videojs") > 0; " jwplayer="; instr(1,alternateBodyLower,"jwplayer") > 0; " plyr="; instr(1,alternateBodyLower,"plyr") > 0; " iframe="; instr(1,alternateBodyLower,"<iframe") > 0
                                print "[RokuPlus voe] page_probe atob="; instr(1,alternateBodyLower,"atob(") > 0; " base64="; instr(1,alternateBodyLower,"base64") > 0; " eval="; instr(1,alternateBodyLower,"eval(") > 0; " onclick="; instr(1,alternateBodyLower,"onclick") > 0
                                print "[RokuPlus voe] page_probe challenge="; antiBotPage; " server_guard="; instr(1,alternateServerLower,"ddos-guard") > 0; " title="; instr(1,alternateBodyLower,"<title") > 0
                                print "[RokuPlus voe] alternate_host_result=media-missing bytes="; len(response.body)
                            end if
                        else
                            print "[RokuPlus voe] alternate_host_result=request-failed"
                        end if
                    end if
                end if
                if masterUrl = "" and antiBotPage
                    answer.voeBlocked = true
                    print "[RokuPlus voe] blocked=1 reason=anti-bot-page bytes="; len(response.body)
                else if masterUrl = ""
                    print "[RokuPlus voe] manifest_missing=1 bytes="; len(response.body)
                end if
            end if
            if masterUrl <> ""
                response = fetcher(masterUrl,"media",mediaReferer)
                if response.cancelled then return rpHdTaskFailure(answer,response)
                if response.ok
                    master = rpHdOnlineMaster(response.body,masterUrl)
                    answer.subtitleTracks = master.subtitleTracks
                    ' VOE/JWPlayer publishes subtitle files beside the embed, not in its HLS master.
                    ' HAR confirms the public naming convention: /vtt/{embed-id}_es.srt and _en.srt.
                    if answer.subtitleTracks.count() = 0
                        voePageUrl = orbitText(mediaReferer,4096)
                        if voePageUrl = "" then voePageUrl = orbitText(embed.url,4096)
                        voePageMatch = CreateObject("roRegex","^https://arianathankspecial\.com/e/([a-z0-9]{8,20})/?$","i").match(voePageUrl)
                        if voePageMatch.count() >= 2
                            voePageId = lcase(voePageMatch[1])
                            answer.subtitleTracks.push({group:"",name:"Español",language:"es",default:true,forced:false,url:"https://arianathankspecial.com/vtt/"+voePageId+"_es.srt"})
                            answer.subtitleTracks.push({group:"",name:"English",language:"en",default:false,forced:false,url:"https://arianathankspecial.com/vtt/"+voePageId+"_en.srt"})
                            print "[RokuPlus voe-subtitles] sourceTracks=2 languages=es,en"
                        end if
                    end if
                    if answer.subtitleTracks.count() = 0
                        answer.subtitleTracks = rpHdOnlineVimeosSubtitleTracks(masterUrl)
                    end if
                    print "[RokuPlus hls-subtitles] mediaTags="; master.subtitleMediaTagCount; " tracks="; answer.subtitleTracks.count()
                    print "[RokuPlus hls-captions] mediaTags="; master.closedCaptionMediaTagCount; " groups="; master.closedCaptionGroups.count()
                    for each captionGroup in master.closedCaptionGroups
                        print "[RokuPlus hls-captions] group="; captionGroup.group; " instream="; captionGroup.instreamId; " language="; captionGroup.language; " name="; captionGroup.name
                    end for
                    for each subtitleTrack in master.subtitleTracks
                        subtitleUriState = "missing"
                        if subtitleTrack.url <> "" then subtitleUriState = "present"
                        print "[RokuPlus hls-subtitles] group="; subtitleTrack.group; " language="; subtitleTrack.language; " name="; subtitleTrack.name; " default="; subtitleTrack.default; " uri="; subtitleUriState
                    end for
                    print "[RokuPlus hls] master variants="; master.variants.count(); " audioTracks="; master.audioTracks.count(); " mediaTags="
                    print "[RokuPlus hls] master variants="; "cont"; master.mediaTagCount; " audioMediaTags="; master.audioMediaTagCount; " audioGroups="
                    print "[RokuPlus hls] master variants="; "cont"; master.audioGroupCount; " variantAudioGroups="; master.variantAudioGroupCount; " encrypted="
                    print "[RokuPlus hls] master variants="; "cont"; master.encrypted
                    for each audioTrack in master.audioTracks
                        uriState = "missing"
                        if audioTrack.url <> "" then uriState = "present"
                        print "[RokuPlus hls] audio group="; audioTrack.group; " language="; audioTrack.language; " name="; audioTrack.name; " default="
                        print "[RokuPlus hls] audio group="; "cont"; audioTrack.default; " uri="; uriState
                    end for
                    spanishCandidates = []
                    fallbackCandidates = []
                    for each variant in master.variants
                        print "[RokuPlus hls] variant group="; variant.audioGroup; " resolution="; variant.width; "x"; variant.height; " fps="; variant.fps
                        print "[RokuPlus hls] variant group="; "cont"; " bandwidth="; variant.bandwidth; " averageBandwidth="; variant.averageBandwidth; " codecs="
                        print "[RokuPlus hls] variant group="; "cont"; variant.codecs; " videoRange="; variant.videoRange; " hdcp="; variant.hdcpLevel
                        fallbackCandidates.push(variant)
                        if rpHdTaskSpanishAudio(master,variant) then spanishCandidates.push(variant)
                    end for
                    candidates = {variants:spanishCandidates,audioTracks:master.audioTracks,encrypted:master.encrypted}
                    if spanishCandidates.count() = 0
                        ' No Spanish language was identified: keep playback available
                        ' and let Roku use the stream's declared/default audio track.
                        candidates.variants = fallbackCandidates
                        print "[RokuPlus hls] spanish-compatible variants=0 fallback=all-playable"
                    else
                        print "[RokuPlus hls] spanish-compatible variants="; spanishCandidates.count()
                    end if
                    ' Try Spanish-compatible renditions first; use all valid variants only when Spanish is absent.
                    choices = rpHdTaskStableVariants(candidates,decoderAccept)
                    print "[RokuPlus hls-test] eligibleVariants="; choices.count()
                    variantOffset = 0
                    if choices.count() > 0 then variantOffset = (retry \ count) mod choices.count()
                    for qualityAttempt = 0 to choices.count()-1
                        if rpHdTaskSliceExpired() then exit for
                        variantIndex = (qualityAttempt+variantOffset) mod choices.count()
                        selected = choices[variantIndex]
                        answer.selectedSubtitleGroup = orbitText(selected.subtitleGroup,100)
                        print "[RokuPlus hls-captions] selectedGroup="; orbitText(selected.closedCaptionGroup,100)
                        print "[RokuPlus hls-test] selectedPlaylist="; rpHdTaskSafeUrl(selected.url)
                        answer.variantAttempts++
                        child = fetcher(selected.url,"media",mediaReferer)
                        if child.cancelled then return rpHdTaskFailure(answer,child)
                        manifestPlayable = child.ok and rpHdTaskMediaManifest(child.body,selected.url)
                        playable = manifestPlayable
                        segmentUrl = ""
                        candidateStage = "child_fetch_failed"
                        if child.ok
                            candidateStage = "manifest_rejected"
                            if playable
                                candidateStage = "segment_not_ts"
                                segmentUrl = rpHdTaskFirstSegment(child.body,selected.url)
                                ' Only this tested TS path has an AVC/AAC byte validator.
                                ' Codec labels alone must not send a dead or silent stream to Video.
                                playable = rpHdTaskTsSegment(segmentUrl)
                                if playable
                                    candidateStage = "sample_fetch_failed"
                                    sample = fetcher(segmentUrl,"sample",mediaReferer)
                                    if sample.cancelled then return rpHdTaskFailure(answer,sample)
                                    if sample.ok
                                        playable = rpHdOnlineMuxedAvcAac(sample.bytes)
                                        candidateStage = "sample_rejected"
                                        if playable then candidateStage = "accepted"

                                        ' Keep startup validation to one bounded TS sample.
                                        ' Extra segment-boundary and full-segment probes delayed playback
                                        ' without changing the native HLS stream returned to Roku.
                                    end if
                                end if
                            end if
                        end if
                        print "[RokuPlus candidate] result="; candidateStage
                        ' TS relay remains preferred. If its byte-level AVC/AAC validation fails,
                        ' try the already validated HLS rendition using Roku's single Video decoder.
                        ' This fallback does not require the provider to label its audio language.
                        if not playable and manifestPlayable and rpHdTaskNativeDefaultAudioSafe(master,selected,decoderAccept)
                            answer.url = masterUrl
                            answer.streamFormat = "hls"
                            answer.segmentUrls = []
                            answer.segmentDurations = []
                            answer.tsRelayEnabled = false
                            answer.fallbackTsRelayEnabled = false
                            answer.mediaHeaders = {Referer:mediaReferer, "User-Agent":rpHdTaskUserAgent()}
                            answer.description = "HLS compatible · audio predeterminado · H.264 · "+selected.height.toStr()+"p"
                            answer.language = embed.language
                            answer.width = selected.width
                            answer.height = selected.height
                            answer.codecs = selected.codecs
                            answer.seekSupport = "native-hls"
                            print "[RokuPlus resolve] provider="; provider; " format=hls mode=default-audio-fallback reason=ts-validation-failed languageMetadata=not-required"
                            answer.attemptUsed = embedIndex+variantIndex*count
                            answer.ok = true
                            answer.message = ""
                            m.hdProviderDeadline = 0
                            return answer
                        end if
                        if playable
                            relaySegments = rpHdTaskSegmentList(child.body,selected.url)
                            if relaySegments.count() > 1
                                ' Validate alternate audio renditions before selecting native HLS; otherwise keep the validated TS relay.
                                rpHdTaskBeginResolveSlice(1)
                                videoAudit = rpHdTaskAuditAudioSegment(sample.bytes)
                                audioAudit = rpHdTaskAuditExternalAudio(master,selected,fetcher,mediaReferer,videoAudit,child.body)
                                spanishVerified = rpHdTaskHasSpanishValidatedAudio(audioAudit.tracks)
                                if rpHdTaskNativeAudioMasterSafe(master,selected,decoderAccept) and audioAudit.tracks.count() >= 2
                                    answer.url = masterUrl
                                    answer.streamFormat = "hls"
                                    answer.fallbackSegmentUrls = relaySegments
                                    answer.fallbackSegmentDurations = rpHdTaskSegmentDurations(child.body,relaySegments.count())
                                    answer.fallbackTsRelayEnabled = true
                                    answer.segmentUrls = []
                                    answer.segmentDurations = []
                                    answer.tsRelayEnabled = false
                                    answer.mediaHeaders = {Referer:mediaReferer, "User-Agent":rpHdTaskUserAgent()}
                                    answer.description = "Multiaudio · preferencia español · H.264 · "+selected.height.toStr()+"p"
                                    answer.language = embed.language
                                    answer.width = selected.width
                                    answer.height = selected.height
                                    answer.codecs = selected.codecs
                                    answer.seekSupport = "native-hls"
                                    print "[RokuPlus resolve] provider="; provider; " format=hls mode=native-multiaudio spanishPreferred="; spanishVerified; " tracks="; audioAudit.tracks.count()
                                    answer.attemptUsed = embedIndex+variantIndex*count
                                    answer.ok = true
                                    answer.message = ""
                                    m.hdProviderDeadline = 0
                                    return answer
                                end if
                                print "[RokuPlus audio-mode] format=ts reason=native-multiaudio-not-safe validatedTracks="; audioAudit.tracks.count(); " spanishVerified="; spanishVerified
                                answer.segmentUrls = relaySegments
                                answer.tsRelayEnabled = true
                                segmentDurations = rpHdTaskSegmentDurations(child.body,relaySegments.count())
                                if segmentDurations.count() = relaySegments.count()
                                    answer.segmentDurations = segmentDurations
                                    print "[RokuPlus ts-relay] candidate_segments="; relaySegments.count(); " duration_entries="; segmentDurations.count()
                                else
                                    answer.segmentDurations = []
                                    print "[RokuPlus ts-relay] duration_metadata_unavailable segments="; relaySegments.count()
                                end if
                                answer.url = relaySegments[0]
                                answer.streamFormat = "ts"
                                answer.mediaHeaders = {Referer:mediaReferer, "User-Agent":rpHdTaskUserAgent()}
                                answer.description = "H.264 · "+selected.height.toStr()+"p"
                                if selected.audioGroup <> "" and rpHdTaskSpanishAudio(master,selected) then answer.description = "Audio español verificado · H.264 · "+selected.height.toStr()+"p"
                                answer.language = embed.language
                                answer.width = selected.width
                                answer.height = selected.height
                                answer.codecs = selected.codecs
                                answer.seekSupport = "ts-relay"
                                print "[RokuPlus resolve] provider="; provider; " format=ts playlist=segment-relay height="; selected.height
                                answer.attemptUsed = embedIndex+variantIndex*count
                                answer.ok = true
                                answer.message = ""
                                m.hdProviderDeadline = 0
                                return answer
                            else
                                candidateStage = "relay_segments_unavailable"
                                print "[RokuPlus ts-relay] disabled reason=segment_list_unavailable"
                                if manifestPlayable and rpHdTaskNativeDefaultAudioSafe(master,selected,decoderAccept)
                                    answer.url = masterUrl
                                    answer.streamFormat = "hls"
                                    answer.segmentUrls = []
                                    answer.segmentDurations = []
                                    answer.tsRelayEnabled = false
                                    answer.fallbackTsRelayEnabled = false
                                    answer.mediaHeaders = {Referer:mediaReferer, "User-Agent":rpHdTaskUserAgent()}
                                    answer.description = "HLS compatible · audio predeterminado · H.264 · "+selected.height.toStr()+"p"
                                    answer.language = embed.language
                                    answer.width = selected.width
                                    answer.height = selected.height
                                    answer.codecs = selected.codecs
                                    answer.seekSupport = "native-hls"
                                    print "[RokuPlus resolve] provider="; provider; " format=hls mode=default-audio-fallback reason=ts-relay-unavailable languageMetadata=not-required"
                                    answer.attemptUsed = embedIndex+variantIndex*count
                                    answer.ok = true
                                    answer.message = ""
                                    m.hdProviderDeadline = 0
                                    return answer
                                end if
                            end if
                        end if
                    end for
                end if
            end if
        end if
    end for
    m.hdProviderDeadline = 0
    answer.message = "No se encontró una variante de video compatible y reproducible para esta fuente. Prueba otra opción del título."
    return answer
end function

' Audit the complete child playlist without printing signed segment URLs or query tokens.
sub rpHdTaskLogManifest(body as dynamic, baseUrl as string)
    text = orbitText(body,2097153)
    lineCount = 0
    segmentCount = 0
    extinfCount = 0
    totalDuration = 0.0
    minDuration = 0.0
    maxDuration = 0.0
    targetDuration = ""
    targetValue = 0.0
    mediaSequence = ""
    playlistType = ""
    version = ""
    discontinuities = 0
    byteRanges = 0
    programDates = 0
    invalidExtinf = 0
    targetOverruns = 0
    hasEndList = false
    hasIndependent = false
    hasMap = false
    hasKey = false
    firstSegment = ""
    for each raw in text.split(chr(10))
        line = raw.trim()
        if line <> ""
            lineCount++
            if left(line,8) = "#EXTINF:"
                extinfCount++
                value = mid(line,9).split(",")[0].trim()
                parsedDuration = value.toFloat()
                if parsedDuration > 0
                    totalDuration += parsedDuration
                    if minDuration = 0 or parsedDuration < minDuration then minDuration = parsedDuration
                    if parsedDuration > maxDuration then maxDuration = parsedDuration
                    if targetValue > 0 and parsedDuration > targetValue then targetOverruns++
                else
                    invalidExtinf++
                end if
            else if left(line,21) = "#EXT-X-TARGETDURATION"
                targetDuration = mid(line,instr(1,line,":")+1).trim()
                targetValue = targetDuration.toFloat()
            else if left(line,21) = "#EXT-X-MEDIA-SEQUENCE"
                mediaSequence = mid(line,instr(1,line,":")+1).trim()
            else if left(line,20) = "#EXT-X-PLAYLIST-TYPE"
                playlistType = mid(line,instr(1,line,":")+1).trim()
            else if left(line,14) = "#EXT-X-VERSION"
                version = mid(line,instr(1,line,":")+1).trim()
            else if left(line,14) = "#EXT-X-ENDLIST"
                hasEndList = true
            else if left(line,20) = "#EXT-X-DISCONTINUITY"
                discontinuities++
            else if left(line,17) = "#EXT-X-BYTERANGE:"
                byteRanges++
            else if left(line,24) = "#EXT-X-PROGRAM-DATE-TIME"
                programDates++
            else if left(line,28) = "#EXT-X-INDEPENDENT-SEGMENTS"
                hasIndependent = true
            else if left(line,11) = "#EXT-X-MAP:"
                hasMap = true
            else if left(line,11) = "#EXT-X-KEY:"
                hasKey = true
            else if left(line,1) <> "#"
                segmentCount++
                resolved = rpHdOnlineJoin(baseUrl,line)
                if firstSegment = "" then firstSegment = rpHdTaskSafeUrl(resolved)
                if resolved = "" then print "[RokuPlus hls-manifest] WARNING unresolvedSegment index="; segmentCount
            end if
        end if
    end for
    averageDuration = 0.0
    if extinfCount > 0 then averageDuration = totalDuration/extinfCount
    print "[RokuPlus hls-manifest] version="; version; " targetDuration="; targetDuration; " mediaSequence="; mediaSequence; " playlistType="; playlistType
    print "[RokuPlus hls-manifest] segments="; segmentCount; " extinfCount="; extinfCount; " totalDuration="; totalDuration; " endList="; hasEndList
    print "[RokuPlus hls-manifest] duration min="; minDuration; " max="; maxDuration; " avg="; averageDuration; " invalid="; invalidExtinf; " targetOverruns="; targetOverruns
    print "[RokuPlus hls-manifest] discontinuities="; discontinuities; " byteRanges="; byteRanges; " programDates="; programDates
    print "[RokuPlus hls-manifest] discontinuities="; "cont"; " independent="; hasIndependent; " map="; hasMap; " key="; hasKey; " lines="
    print "[RokuPlus hls-manifest] discontinuities="; "cont"; lineCount
    if firstSegment <> "" then print "[RokuPlus hls-manifest] firstSegment="; firstSegment
end sub

' Return only a host for diagnostics; never print media URLs, paths, or tokens.
function rpHdTaskSafeHost(value as dynamic) as string
    url = orbitText(value,4096)
    match = CreateObject("roRegex","^https://([^/?#]+)","i").match(url)
    if match.count() < 2 then return "unknown"
    return lcase(match[1])
end function

' Diagnostic URL: omit query strings and fragments so signed CDN tokens are not printed.
function rpHdTaskSafeUrl(value as dynamic) as string
    url = orbitText(value,4096)
    queryAt = instr(1,url,"?")
    fragmentAt = instr(1,url,"#")
    cutAt = 0
    if queryAt > 0 then cutAt = queryAt
    if fragmentAt > 0 and (cutAt = 0 or fragmentAt < cutAt) then cutAt = fragmentAt
    if cutAt > 0 then url = left(url,cutAt-1)
    return url
end function

function rpHdTaskResponseHeader(headers as dynamic, wanted as string) as string
    if type(headers) <> "roAssociativeArray" then return ""
    for each name in headers
        if lcase(name) = lcase(wanted) then return left(orbitText(headers[name],256),256)
    end for
    return ""
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

' Remove a trailing year from a series display title and retain it as metadata.
' This allows providers with different IDs/title formatting to be deduplicated.
' Cross-provider identity: trust matching external IDs first. If both records
' carry conflicting external IDs, never merge them by title. Title/year is a
' conservative fallback for providers that do not expose shared identifiers.
' Canonical identity for the one confirmed translated series pair.
' This is deliberately an exact alias, not fuzzy title matching.
function rpHdTaskKnownSeriesTitleKey(title as dynamic) as string
    key = lcase(orbitText(title,200).trim())
    key = CreateObject("roRegex","\s*\\(((?:19|20)[0-9]{2})\\)\s*$","").replace(key,"").trim()
    key = key.replace("á","a").replace("é","e").replace("í","i").replace("ó","o").replace("ú","u").replace("ñ","n")
    key = CreateObject("roRegex","\s+","").replace(key,"")
    if key = "thelastmanonearth" or key = "elultimohombreenlatierra"
        return "tmdb-tv-61888"
    end if
    return ""
end function

function rpHdTaskSameCatalogItem(existing as dynamic, item as dynamic) as boolean
    if type(existing) <> "roAssociativeArray" or type(item) <> "roAssociativeArray" then return false
    if orbitText(existing.kind,16) <> orbitText(item.kind,16) then return false
    existingTmdb = orbitText(existing.providerTmdbId,40)
    itemTmdb = orbitText(item.providerTmdbId,40)
    if existingTmdb <> "" and itemTmdb <> ""
        return existingTmdb = itemTmdb
    end if
    existingImdb = lcase(orbitText(existing.imdbId,40))
    itemImdb = lcase(orbitText(item.imdbId,40))
    if existingImdb <> "" and itemImdb <> ""
        return existingImdb = itemImdb
    end if
    if existingTmdb <> "" or itemTmdb <> "" or existingImdb <> "" or itemImdb <> ""
        ' One source has an ID and the other does not: allow a strict title/year fallback.
        ' Conflicting IDs were already rejected above.
    end if
    if orbitText(existing.kind,16) = "series"
        existingKnownKey = rpHdTaskKnownSeriesTitleKey(existing.title)
        itemKnownKey = rpHdTaskKnownSeriesTitleKey(item.title)
        if existingKnownKey <> "" and existingKnownKey = itemKnownKey then return true
    end if
    existingKey = CreateObject("roRegex","\s+","").replace(lcase(orbitText(existing.title,200).trim()),"")
    itemKey = CreateObject("roRegex","\s+","").replace(lcase(orbitText(item.title,200).trim()),"")
    if existingKey = "" or itemKey = "" or existingKey <> itemKey then return false
    existingYear = orbitText(existing.year,4)
    itemYear = orbitText(item.year,4)
    return existingYear = "" or itemYear = "" or existingYear = itemYear
end function

function rpHdTaskNormalizeSeriesTitle(item as dynamic) as dynamic
    if type(item) <> "roAssociativeArray" then return item
    title = orbitText(item.title,200).trim()
    match = CreateObject("roRegex","\s*\(((?:19|20)[0-9]{2})\)\s*$","").match(title)
    if match.count() > 1
        if orbitText(item.year,4) = "" then item.year = match[1]
        title = CreateObject("roRegex","\s*\(((?:19|20)[0-9]{2})\)\s*$","").replace(title,"").trim()
        item.title = title
    end if
    return item
end function

' skip encodes source-page rounds in steps of twenty, not displayed-card count.
' JSON providers request twenty records; SSR pages may contain more cards.
' Round-robin output keeps source order while merging the same series across providers.
function rpHdTaskGlobalSearch(request as object, answer as object, fetcher as dynamic, sources as dynamic) as object
    return rpHdTaskCinemetaGlobalSearch(request,answer,fetcher)
end function

' Global discovery is independent from the playback providers. Cinemeta supplies
' searchable movie/series metadata; provider catalogs are queried only after Play.
function rpHdTaskCinemetaGlobalSearch(request as object, answer as object, fetcher as dynamic) as object
    query = rpHdOnlineSearchQuery(request.query)
    if query = "" then return answer
    transfer = CreateObject("roUrlTransfer")
    escapedQuery = transfer.escape(query)
    successes = 0
    failures = 0
    merged = []
    seen = {}
    for each searchKind in ["movie","series"]
        if m.top.cancelRequested or rpHdTaskSliceExpired() then exit for
        rpHdTaskBeginSlice(2)
        endpoint = "https://v3-cinemeta.strem.io/catalog/"+searchKind+"/top/search="+escapedQuery+".json"
        response = fetcher(endpoint,"cinemeta","")
        if response.cancelled then return rpHdTaskFailure(answer,response)
        if response.ok
            successes++
            data = ParseJson(response.body)
            if type(data) = "roAssociativeArray" and type(data.metas) = "roArray"
                for each meta in data.metas
                    if type(meta) = "roAssociativeArray"
                        metaType = orbitText(meta.type,16)
                        metaId = orbitText(meta.id,80)
                        title = orbitText(meta.name,200).trim()
                        if (metaType = "" or metaType = searchKind) and title <> "" and CreateObject("roRegex","^tt[0-9]{6,12}$","").isMatch(metaId)
                            if not seen.doesExist(metaId)
                                year = rpHdTaskCinemetaYear(meta.year)
                                if year = "" then year = rpHdTaskCinemetaYear(meta.releaseInfo)
                                genres = []
                                if type(meta.genres) = "roArray"
                                    for each genre in meta.genres
                                        if GetInterface(genre,"ifString") <> invalid
                                            genreName = lcase(genre.trim())
                                            if genreName <> ""
                                                genreFound = false
                                                for each savedGenre in genres
                                                    if savedGenre = genreName then genreFound = true
                                                end for
                                                if not genreFound then genres.push(genreName)
                                            end if
                                        end if
                                    end for
                                end if
                                item = {
                                    id:"cinemeta-"+metaId, imdbId:metaId, kind:searchKind
                                    provider:"all", discoverySource:"cinemeta", library:"hd-online"
                                    title:title, searchQuery:query, year:year, description:orbitText(meta.description,4000)
                                    poster:orbitText(meta.poster,2048), background:orbitText(meta.background,2048)
                                    genres:genres, runtime:0, language:"", seasons:[]
                                    source:"Cinemeta"
                                }
                                merged.push(item)
                                seen[metaId] = true
                            end if
                        end if
                    end if
                end for
            end if
        else
            failures++
            print "[RokuPlus discovery] source=cinemeta kind="; searchKind; " error="; orbitText(response.message,180)
        end if
    end for
    answer.items = merged
    answer.ok = successes > 0
    answer.partial = failures > 0
    answer.hasMore = false
    answer.nextSkip = 0
    answer.total = merged.count()
    answer.totalKnown = true
    answer.message = ""
    if not answer.ok then answer.message = "El catálogo de búsqueda no respondió. Vuelve a intentarlo."
    print "[RokuPlus discovery] source=cinemeta query="; query; " results="; merged.count(); " failures="; failures
    return answer
end function

' Resolve a Cinemeta discovery record against installed catalogs only when the
' user chooses Play (or opens a series episode list). Search the original
' localized query first, then the Cinemeta title as a fallback.
' Keep query order stable while removing duplicates after the same normalization
' used by provider identity checks (including punctuation and accents).
function rpHdTaskIsPlaceholderTitle(value as dynamic) as boolean
    title = lcase(orbitText(value,200).trim())
    if title = "" or title = "unknown" or title = "tba" or title = "to be announced" then return true
    return CreateObject("roRegex","^untitled([ :]|$)","i").isMatch(title)
end function

function rpHdTaskAppendUniqueSearchQuery(queries as object, value as dynamic) as object
    query = orbitText(value,200).trim()
    queryKey = rpHdTaskCinemetaTitleKey(query)
    if queryKey = "" then return queries
    for each existingQuery in queries
        if rpHdTaskCinemetaTitleKey(existingQuery) = queryKey then return queries
    end for
    queries.push(query)
    return queries
end function

' Remove a leading article for providers whose search index stores the title
' without it (e.g. "The Gilded Age" -> "Gilded Age"). This is a query variant
' only; candidate identity/year validation remains unchanged.
function rpHdTaskSearchTitleCore(value as dynamic) as string
    title = orbitText(value,200).trim()
    if title = "" then return ""
    return CreateObject("roRegex","^(the|a|an|el|la|los|las|un|una|une|le|les)\s+","i").replace(title,"").trim()
end function

function rpHdTaskFindSource(request as object, answer as object, fetcher as dynamic, decoderAccept as dynamic, sources as dynamic) as object
    item = request.item
    if type(item) <> "roAssociativeArray"
        answer.message = "El título no tiene metadatos válidos."
        return answer
    end if
    requestedKind = orbitText(item.kind,16)
    isEpisode = requestedKind = "episode"
    kind = requestedKind
    discovery = {
        kind:requestedKind,title:orbitText(item.title,200)
        year:orbitText(item.year,32),imdbId:orbitText(item.imdbId,40)
        searchQuery:orbitText(item.searchQuery,200)
    }
    if isEpisode
        kind = "series"
        seriesTitle = orbitText(item.seriesTitle,200).trim()
        if seriesTitle = ""
            answer.message = "No se conserva el título de la serie para buscar otra fuente de este episodio."
            return answer
        end if
        discovery = {
            kind:"series",title:seriesTitle,year:orbitText(item.year,32)
            imdbId:orbitText(item.seriesImdbId,40),searchQuery:orbitText(item.seriesSearchQuery,200)
        }
    end if
    if kind <> "movie" and kind <> "series"
        answer.message = "No se puede buscar una fuente para este contenido."
        return answer
    end if
    seasonNumber = orbitInteger(item.season,999,-1)
    episodeNumber = orbitInteger(item.episode,9999)
    if isEpisode and (seasonNumber < 0 or episodeNumber < 1)
        answer.message = "No se conserva la temporada y el número de episodio para buscar otra fuente."
        return answer
    end if
    if type(sources) <> "roArray" then sources = rpHdOnlineProviderIds()
    triedProviders = []
    if isEpisode and type(item.hdFallbackProviders) = "roArray"
        for each triedValue in item.hdFallbackProviders
            triedProvider = rpHdOnlineProvider(triedValue)
            if triedProvider <> "" and triedProvider <> "all"
                alreadyTried = false
                for each savedProvider in triedProviders
                    if savedProvider = triedProvider then alreadyTried = true
                end for
                if not alreadyTried then triedProviders.push(triedProvider)
            end if
        end for
    end if
    currentProvider = rpHdOnlineProvider(item.provider)
    if isEpisode and currentProvider <> ""
        alreadyTried = false
        for each savedProvider in triedProviders
            if savedProvider = currentProvider then alreadyTried = true
        end for
        if not alreadyTried then triedProviders.push(currentProvider)
    end if
    providers = []
    for each value in sources
        source = rpHdOnlineProvider(value)
        if source <> "" and source <> "all"
            skipProvider = false
            if isEpisode
                for each triedProvider in triedProviders
                    if triedProvider = source then skipProvider = true
                end for
            end if
            if not skipProvider and (source <> "cinecalidad" or kind <> "series") then providers.push(source)
        end if
    end for
    ' For automatic source discovery, prefer providers that expose Vimeos first,
    ' then providers that can expose VOE, and leave SeriesMetro/Fastream last.
    ' Keep the user's catalog/provider selection untouched; this order applies
    ' only to alternate-source discovery after a source fails.
    orderedProviders = []
    for each preferredProvider in ["cinehax","cinecalidad","allcalidad","lamovie","seriesmetro"]
        for each availableProvider in providers
            if availableProvider = preferredProvider then orderedProviders.push(availableProvider)
        end for
    end for
    providers = orderedProviders
    if providers.count() = 0
        answer.message = "No hay proveedores compatibles para este tipo de contenido."
        print "[RokuPlus source-search] result=no-providers kind="; kind
        return answer
    end if
    searchQueries = []
    originalQuery = orbitText(discovery.searchQuery,200).trim()
    cinemetaTitle = orbitText(discovery.title,200).trim()
    if rpHdTaskIsPlaceholderTitle(cinemetaTitle)
        if rpHdTaskIsPlaceholderTitle(originalQuery)
            answer.message = "Cinemeta no confirmó un título válido para buscar fuentes."
            print "[RokuPlus source-search] result=skipped reason=placeholder-title kind="; kind
            return answer
        end if
        print "[RokuPlus source-search] identity-fallback=original-query reason=placeholder-title"
        cinemetaTitle = originalQuery
        discovery.title = originalQuery
    end if
    searchQueries = rpHdTaskAppendUniqueSearchQuery(searchQueries,originalQuery)
    searchQueries = rpHdTaskAppendUniqueSearchQuery(searchQueries,cinemetaTitle)
    discoveryYear = rpHdTaskCinemetaYear(discovery.year)
    if cinemetaTitle <> "" and discoveryYear <> ""
        yearQuery = cinemetaTitle+" "+discoveryYear
        searchQueries = rpHdTaskAppendUniqueSearchQuery(searchQueries,yearQuery)
    end if
    ' If the full-title search returns no useful candidates, a distinctive
    ' title word can reveal provider entries with shortened/localized names.
    ' Source matching remains protected by the exact-title/IMDb checks below.
    suggestionQuery = rpHdTaskSuggestionSearchQuery(cinemetaTitle)
    if suggestionQuery <> "" and rpHdTaskCinemetaTitleKey(suggestionQuery) <> rpHdTaskCinemetaTitleKey(cinemetaTitle)
        searchQueries = rpHdTaskAppendUniqueSearchQuery(searchQueries,suggestionQuery)
        print "[RokuPlus source-search] suggestion-query="; suggestionQuery
    end if
    if searchQueries.count() = 0
        answer.message = "No hay un título válido para buscar en las fuentes."
        return answer
    end if
    ' Episode fallback must reach every provider. Searching several title variants
    ' against one provider first can exhaust the shared deadline before the
    ' remaining providers are checked. Use the canonical series title once per
    ' provider; the strict title/year and episode-number checks remain unchanged.
    if isEpisode
        episodeQueries = []
        rpHdTaskAppendUniqueSearchQuery(episodeQueries,cinemetaTitle)
        if episodeQueries.count() = 0 then rpHdTaskAppendUniqueSearchQuery(episodeQueries,originalQuery)
        searchQueries = episodeQueries
    end if
    failures = 0
    suggestions = []
    print "[RokuPlus source-search] start kind="; kind; " episode="; isEpisode; " title="; cinemetaTitle; " year="; discoveryYear; " providers="; providers.count(); " queries="; searchQueries.count()
    for providerIndex = 0 to providers.count()-1
        if m.top.cancelRequested then exit for
        rpHdTaskBeginSlice(providers.count()-providerIndex)
        if rpHdTaskSliceExpired() then exit for
        source = providers[providerIndex]
        providerFailed = false
        providerQueries = 0
        providerErrors = 0
        providerNoMatches = 0
        providerAmbiguous = 0
        providerUnavailable = 0
        providerSearchQueries = []
        for each baseSearchQuery in searchQueries
            rpHdTaskAppendUniqueSearchQuery(providerSearchQueries,baseSearchQuery)
        end for
        if source = "cinehax" and not isEpisode
            originalCore = rpHdTaskSearchTitleCore(originalQuery)
            titleCore = rpHdTaskSearchTitleCore(cinemetaTitle)
            if originalCore <> "" and rpHdTaskCinemetaTitleKey(originalCore) <> rpHdTaskCinemetaTitleKey(originalQuery)
                rpHdTaskAppendUniqueSearchQuery(providerSearchQueries,originalCore)
                print "[RokuPlus source-search] provider=cinehax title-variant="; originalCore
            end if
            if titleCore <> "" and rpHdTaskCinemetaTitleKey(titleCore) <> rpHdTaskCinemetaTitleKey(cinemetaTitle)
                rpHdTaskAppendUniqueSearchQuery(providerSearchQueries,titleCore)
                print "[RokuPlus source-search] provider=cinehax title-variant="; titleCore
            end if
        end if
        for each searchQuery in providerSearchQueries
            if m.top.cancelRequested or rpHdTaskSliceExpired() then exit for
            providerQueries++
            catalog = rpHdTaskCatalogPage(source,kind,1,searchQuery,fetcher)
            if catalog.cancelled and m.top.cancelRequested then return rpHdTaskFailure(answer,catalog)
            if not catalog.ok
                providerFailed = true
                providerErrors++
                print "[RokuPlus source-search] provider="; source; " query="; searchQuery; " result=error"
            else
                matches = []
                for each candidate in catalog.items
                    exactDiscoveryMatch = rpHdTaskSameDiscoveryItem(discovery,candidate,searchQuery)
                    if exactDiscoveryMatch
                        matches.push(candidate)
                    else if rpHdTaskSameDiscoveryYearUnique(discovery,candidate,catalog.items,searchQuery)
                        matches.push(candidate)
                        print "[RokuPlus source-search] provider="; source; " query="; searchQuery; " result=localized-year-match title="; orbitText(candidate.title,100); " year="; orbitText(candidate.year,12)
                    end if
                end for
                ' Keep plausible title alternatives for a user choice if no verified source is found.
                if not isEpisode
                    for each suggestionCandidate in catalog.items
                        if type(suggestionCandidate) = "roAssociativeArray"
                            suggestionScore = rpHdTaskSuggestionScore(discovery.title,suggestionCandidate.title,discovery.year,suggestionCandidate.year)
                            if type(suggestionCandidate.metadataAliases) = "roArray"
                                for each suggestionAlias in suggestionCandidate.metadataAliases
                                    aliasScore = rpHdTaskSuggestionScore(discovery.title,suggestionAlias,discovery.year,suggestionCandidate.year)
                                    if aliasScore > suggestionScore then suggestionScore = aliasScore
                                end for
                            end if
                            if suggestionScore >= 0.15
                                suggestionKey = rpHdTaskCinemetaTitleKey(suggestionCandidate.title)
                                alreadySuggested = false
                                for each savedSuggestion in suggestions
                                    if rpHdTaskCinemetaTitleKey(savedSuggestion.title) = suggestionKey then alreadySuggested = true
                                end for
                                if not alreadySuggested and suggestions.count() < 12
                                    suggestionCandidate.suggestionScore = suggestionScore
                                    suggestions.push(suggestionCandidate)
                                end if
                            end if
                        end if
                    end for
                end if
                if matches.count() = 1
                    candidate = matches[0]
                    operation = "resolve"
                    if kind = "series" then operation = "meta"
                    sourceRequest = {operation:operation,kind:kind,provider:source,item:candidate,requestId:answer.requestId,attempt:orbitInteger(request.attempt,99)}
                    sourceAnswer = rpHdTaskExecute(sourceRequest,fetcher,decoderAccept,sources)
                    if sourceAnswer.ok and isEpisode
                        sourceSeries = sourceAnswer.item
                        sourceAnswer = rpHdTaskResolveAlternateEpisode(sourceSeries,item,source,answer.requestId,request,fetcher,decoderAccept,sources)
                    end if
                    if sourceAnswer.ok
                        sourceAnswer.operation = "find-source"
                        sourceAnswer.requestId = answer.requestId
                        sourceAnswer.sourceProvider = source
                        if isEpisode and type(sourceAnswer.item) = "roAssociativeArray"
                            sourceAnswer.item.hdFallbackProviders = []
                            for each triedProvider in triedProviders
                                sourceAnswer.item.hdFallbackProviders.push(triedProvider)
                            end for
                            sourceAnswer.item.hdFallbackProviders.push(source)
                        end if
                        if not isEpisode and (kind = "movie" or type(sourceAnswer.item) <> "roAssociativeArray") then sourceAnswer.item = candidate
                        print "[RokuPlus source-search] provider="; source; " query="; searchQuery; " result=matched kind="; kind; " episode="; isEpisode
                        print "[RokuPlus source-search] finish result=matched provider="; source
                        return sourceAnswer
                    end if
                    if sourceAnswer.cancelled and m.top.cancelRequested then return sourceAnswer
                    providerFailed = true
                    providerUnavailable++
                    print "[RokuPlus source-search] provider="; source; " query="; searchQuery; " result=unavailable"
                else if matches.count() > 1
                    providerAmbiguous++
                    print "[RokuPlus source-search] provider="; source; " query="; searchQuery; " result=ambiguous matches="; matches.count()
                else
                    providerNoMatches++
                    print "[RokuPlus source-search] provider="; source; " query="; searchQuery; " result=no-match candidates="; catalog.items.count()
                    diagnosticCount = 0
                    for each diagnosticCandidate in catalog.items
                        if diagnosticCount >= 3 then exit for
                        if type(diagnosticCandidate) = "roAssociativeArray"
                            diagnosticCount++
                            print "[RokuPlus source-search] candidate provider="; source; " title="; left(orbitText(diagnosticCandidate.title,100),100); " year="; rpHdTaskCinemetaYear(diagnosticCandidate.year); " imdb="; orbitText(diagnosticCandidate.imdbId,24)
                        end if
                    end for
                end if
            end if
        end for
        print "[RokuPlus source-search] provider-summary provider="; source; " queries="; providerQueries; " errors="; providerErrors; " no_match="; providerNoMatches; " ambiguous="; providerAmbiguous; " unavailable="; providerUnavailable
        if providerFailed then failures++
    end for
    if isEpisode
        answer.message = "No se encontró otra fuente para el episodio "+seasonNumber.toStr()+"x"+episodeNumber.toStr()+"."
    else
        answer.message = "No se encontró una fuente compatible para este título. Prueba otro título o inténtalo más tarde."
    end if
    if failures = providers.count() then answer.message = "Las fuentes no respondieron. Inténtalo de nuevo más tarde."
    if not isEpisode and suggestions.count() > 0
        answer.alternatives = rpHdTaskSortSuggestions(suggestions)
        answer.alternativeKind = kind
        print "[RokuPlus source-search] alternatives count="; answer.alternatives.count(); " kind="; kind
    end if
    print "[RokuPlus source-search] finish result=no-source providers="; providers.count(); " providers_failed="; failures; " timed_out="; rpHdTaskSliceExpired()
    return answer
end function

function rpHdTaskSuggestionSearchQuery(title as dynamic) as string
    words = CreateObject("roRegex","[^a-z0-9]+","").replaceAll(lcase(orbitText(title,240))," ").trim().split(" ")
    selected = ""
    selectedLength = 0
    for each word in words
        if len(word) >= 4 and not rpHdTaskSuggestionIgnoredWord(word)
            if len(word) >= selectedLength
                selected = word
                selectedLength = len(word)
            end if
        end if
    end for
    return selected
end function

function rpHdTaskSuggestionScore(wantedTitle as dynamic, candidateTitle as dynamic, wantedYear as dynamic, candidateYear as dynamic) as float
    wanted = rpHdTaskCinemetaTitleKey(wantedTitle)
    candidate = rpHdTaskCinemetaTitleKey(candidateTitle)
    if wanted = "" or candidate = "" or wanted = candidate then return 0
    wantedWords = CreateObject("roRegex","[^a-z0-9]+","").replaceAll(lcase(orbitText(wantedTitle,240))," ").trim().split(" ")
    candidateWords = CreateObject("roRegex","[^a-z0-9]+","").replaceAll(lcase(orbitText(candidateTitle,240))," ").trim().split(" ")
    shared = 0
    usefulWanted = 0
    usefulCandidate = 0
    for each word in wantedWords
        if len(word) >= 3 and not rpHdTaskSuggestionIgnoredWord(word)
            usefulWanted++
            found = false
            for each other in candidateWords
                if word = other then found = true
            end for
            if found then shared++
        end if
    end for
    for each word in candidateWords
        if len(word) >= 3 and not rpHdTaskSuggestionIgnoredWord(word) then usefulCandidate++
    end for
    if usefulWanted = 0 or usefulCandidate = 0 then return 0
    denominator = usefulWanted
    if usefulCandidate > denominator then denominator = usefulCandidate
    score = shared/denominator
    if rpHdTaskCinemetaYear(wantedYear) <> "" and rpHdTaskCinemetaYear(wantedYear) = rpHdTaskCinemetaYear(candidateYear)
        score += 0.15
    end if
    return score
end function

function rpHdTaskSuggestionIgnoredWord(value as string) as boolean
    for each ignoredWord in ["the","and","for","with","from","una","uno","las","los","del","de","la","el","un","a","an","of","to","in","your","our","his","her","their","this","that","being","movie","film","series"]
        if value = ignoredWord then return true
    end for
    return false
end function

function rpHdTaskSortSuggestions(items as object) as object
    sorted = []
    for each item in items
        sorted.push(item)
    end for
    if sorted.count() < 2 then return sorted
    for i = 0 to sorted.count()-2
        for j = i+1 to sorted.count()-1
            if sorted[j].suggestionScore > sorted[i].suggestionScore
                saved = sorted[i]
                sorted[i] = sorted[j]
                sorted[j] = saved
            end if
        end for
    end for
    return sorted
end function

function rpHdTaskResolveAlternateEpisode(series as dynamic, originalEpisode as object, provider as string, requestId as string, request as object, fetcher as dynamic, decoderAccept as dynamic, sources as dynamic) as object
    answer = {ok:false,cancelled:false,requestId:requestId,operation:"find-source",provider:provider,message:"No se encontró ese episodio en la fuente alternativa."}
    if type(series) <> "roAssociativeArray" then return answer
    seasonNumber = orbitInteger(originalEpisode.season,999,-1)
    episodeNumber = orbitInteger(originalEpisode.episode,9999)
    if seasonNumber < 0 or episodeNumber < 1 then return answer
    rpHdTaskBeginSlice(2)
    episodeRequest = {operation:"episodes",kind:"series",provider:provider,item:series,season:seasonNumber,requestId:requestId}
    episodeAnswer = rpHdTaskExecute(episodeRequest,fetcher,decoderAccept,sources)
    if not episodeAnswer.ok
        answer.message = orbitText(episodeAnswer.message,240)
        if answer.message = "" then answer.message = "No se pudo cargar la temporada de la fuente alternativa."
        answer.cancelled = episodeAnswer.cancelled
        return answer
    end if
    matchingEpisode = invalid
    for each seasonEntry in episodeAnswer.seasons
        if type(seasonEntry) = "roAssociativeArray" and orbitInteger(seasonEntry.number,999,-1) = seasonNumber and type(seasonEntry.episodes) = "roArray"
            for each candidateEpisode in seasonEntry.episodes
                if type(candidateEpisode) = "roAssociativeArray" and orbitInteger(candidateEpisode.season,999,-1) = seasonNumber and orbitInteger(candidateEpisode.episode,9999) = episodeNumber
                    matchingEpisode = candidateEpisode
                    exit for
                end if
            end for
        end if
        if matchingEpisode <> invalid then exit for
    end for
    if matchingEpisode = invalid
        answer.message = "La fuente alternativa no contiene el episodio "+seasonNumber.toStr()+"x"+episodeNumber.toStr()+"."
        return answer
    end if
    print "[RokuPlus source-fallback] episode-match provider="; provider; " season="; seasonNumber; " episode="; episodeNumber; " id="; orbitText(matchingEpisode.id,160)
    rpHdTaskBeginSlice(2)
    resolveRequest = {operation:"resolve",kind:"episode",provider:provider,item:matchingEpisode,requestId:requestId,attempt:orbitInteger(request.attempt,99)}
    resolved = rpHdTaskExecute(resolveRequest,fetcher,decoderAccept,sources)
    if resolved.ok
        resolved.item = matchingEpisode
        resolved.sourceFallback = true
        resolved.sourceProvider = provider
        print "[RokuPlus source-fallback] episode-resolved provider="; provider
        return resolved
    end if
    return resolved
end function

function rpHdTaskHasTitleSuffixBoundary(baseTitle as string, fullTitle as string) as boolean
    if baseTitle = "" or Len(fullTitle) <= Len(baseTitle) then return false
    if left(fullTitle, Len(baseTitle)) <> baseTitle then return false
    separator = mid(fullTitle, Len(baseTitle)+1, 1)
    return separator = " " or separator = ":"
end function

' A small explicit alias map handles provider titles translated into Spanish.
' It is intentionally exact; it is not a general fuzzy-title matcher.
function rpHdTaskLocalizedTitleAliasKey(title as dynamic) as string
    normalized = rpHdTaskCinemetaTitleKey(title)
    ' Ignore a trailing release year for alias comparison; acceptance still requires an exact year match.
    normalized = CreateObject("roRegex","(19|20)[0-9]{2}$","").replace(normalized,"")
    ' CinemetaTitleKey removes spaces and punctuation, so compare compact keys.
    if normalized = "rickandmorty" or normalized = "rickymorty" then return "rick-and-morty"
    if normalized = "rick and morty" or normalized = "ricky morty" then return "rick-and-morty"
    if normalized = "thesimpsons" or normalized = "lossimpson" then return "the-simpsons"
    if normalized = "the simpsons" or normalized = "los simpson" then return "the-simpsons"
    if normalized = "familyguy" or normalized = "padredefamilia" then return "family-guy"
    if normalized = "family guy" or normalized = "padre de familia" then return "family-guy"
    if normalized = "avatarthelastairbender" or normalized = "avatarlaleyendadeaang" or normalized = "avatar the last airbender" or normalized = "avatar la leyenda de aang" then return "avatar-the-last-airbender"
    if normalized = "spidermanbrandnewday" or normalized = "spidermanunnuevodia" then return "spider-man-brand-new-day"
    if normalized = "residentevil" or normalized = "residentevilnochecero" then return "resident-evil-2026"
    if normalized = "obsession" or normalized = "obsesion" then return "obsession-2026"
    if normalized = "heartofthebeast" or normalized = "elcorazondelabestia" or normalized = "enelcorazondelabestia" then return "heart-of-the-beast-2026"
    if normalized = "theendofoakstreet" or normalized = "elfinaldelacalleoak" or normalized = "elfinaldeoakstreet" then return "the-end-of-oak-street-2026"
    if normalized = "thelordoftheringsthefellowshipofthering" or normalized = "thefellowshipofthering" or normalized = "elsenordelosanilloslacomunidaddelanillo" then return "lord-of-the-rings-fellowship-2001"
    return ""
end function

' Compare provider titles against the canonical discovery title and provider-supplied
' alternate titles. A conservative edit-distance fallback catches spelling variants.
function rpHdTaskTitleSimilarity(leftTitle as dynamic, rightTitle as dynamic) as float
    leftKey = rpHdTaskCinemetaTitleKey(leftTitle)
    rightKey = rpHdTaskCinemetaTitleKey(rightTitle)
    if leftKey = "" or rightKey = "" then return 0
    if leftKey = rightKey then return 1
    leftLength = len(leftKey)
    rightLength = len(rightKey)
    longest = leftLength
    if rightLength > longest then longest = rightLength
    if longest < 8 then return 0
    lengthDifference = abs(leftLength-rightLength)
    if lengthDifference > 2 or lengthDifference/longest > 0.12 then return 0

    previous = []
    for column = 0 to rightLength
        previous.push(column)
    end for
    for row = 1 to leftLength
        current = [row]
        for column = 1 to rightLength
            current.push(0)
        end for
        for column = 1 to rightLength
            cost = 0
            if mid(leftKey,row,1) <> mid(rightKey,column,1) then cost = 1
            deletion = previous[column] + 1
            insertion = current[column-1] + 1
            substitution = previous[column-1] + cost
            best = deletion
            if insertion < best then best = insertion
            if substitution < best then best = substitution
            current[column] = best
        end for
        previous = current
    end for
    distance = previous[rightLength]
    return 1 - (distance/longest)
end function

function rpHdTaskTitleMatchesCandidate(discoveryTitle as dynamic, candidate as dynamic) as boolean
    if type(candidate) <> "roAssociativeArray" then return false
    wantedKey = rpHdTaskCinemetaTitleKey(discoveryTitle)
    candidateKey = rpHdTaskCinemetaTitleKey(candidate.title)
    if wantedKey = "" or candidateKey = "" then return false
    if wantedKey = candidateKey then return true
    aliases = candidate.metadataAliases
    if type(aliases) = "roArray"
        for each alias in aliases
            aliasKey = rpHdTaskCinemetaTitleKey(alias)
            if aliasKey <> "" and aliasKey = wantedKey then return true
        end for
    end if
    return rpHdTaskTitleSimilarity(wantedKey,candidateKey) >= 0.88
end function

function rpHdTaskSameDiscoveryYearUnique(discovery as dynamic, candidate as dynamic, candidates as dynamic, searchQuery as string) as boolean
    if type(discovery) <> "roAssociativeArray" or type(candidate) <> "roAssociativeArray" or type(candidates) <> "roArray" then return false
    if candidates.count() = 0 then return false
    if searchQuery.trim() = "" then return false
    discoveryTitle = rpHdTaskCinemetaTitleKey(discovery.title)
    queryTitle = rpHdTaskCinemetaTitleKey(searchQuery)
    if discoveryTitle = "" or queryTitle <> discoveryTitle then return false
    if orbitText(discovery.kind,16) <> orbitText(candidate.kind,16) then return false
    wantedYear = rpHdTaskCinemetaYear(discovery.year)
    candidateYear = rpHdTaskCinemetaYear(candidate.year)
    if wantedYear = "" or candidateYear = "" or wantedYear <> candidateYear then return false

    wantedImdb = lcase(orbitText(discovery.imdbId,40))
    candidateImdb = lcase(orbitText(candidate.imdbId,40))
    if wantedImdb <> "" and candidateImdb <> "" and wantedImdb <> candidateImdb then return false

    titleMatch = rpHdTaskTitleMatchesCandidate(discovery.title,candidate)
    ' Count same-year results only inside a small provider search response.
    ' This permits a translated title (e.g. English -> Spanish) when the exact
    ' title query returns one and only one result for the requested year.
    sameYearMatches = 0
    selectedYearMatch = false
    equivalentMatches = 0
    for each possible in candidates
        if type(possible) = "roAssociativeArray"
            if orbitText(possible.kind,16) = orbitText(discovery.kind,16)
                possibleYear = rpHdTaskCinemetaYear(possible.year)
                possibleImdb = lcase(orbitText(possible.imdbId,40))
                imdbCompatible = wantedImdb = "" or possibleImdb = "" or wantedImdb = possibleImdb
                if possibleYear = wantedYear and imdbCompatible
                    sameYearMatches++
                    if rpHdTaskCinemetaTitleKey(possible.title) = rpHdTaskCinemetaTitleKey(candidate.title)
                        selectedYearMatch = true
                    end if
                    if rpHdTaskTitleMatchesCandidate(discovery.title,possible)
                        equivalentMatches++
                    end if
                end if
            end if
        end if
    end for
    if titleMatch and equivalentMatches = 1
        print "[RokuPlus source-match] result=unique-title-match title="; left(orbitText(candidate.title,100),100); " year="; wantedYear
        return true
    end if
    if titleMatch and equivalentMatches > 1
        print "[RokuPlus source-match] result=ambiguous-title-match matches="; equivalentMatches; " title="; left(orbitText(discovery.title,100),100)
        return false
    end if

    ' A translation can be textually unrelated. In that case, accept only if
    ' the exact canonical-title search returned <=10 candidates and exactly
    ' one candidate of the same media kind has the requested release year.
    ' Large/popular catalog fallbacks are deliberately excluded.
    if not titleMatch and candidates.count() <= 10 and sameYearMatches = 1 and selectedYearMatch
        print "[RokuPlus source-match] result=unique-year-search-match title="; left(orbitText(candidate.title,100),100); " year="; wantedYear; " candidates="; candidates.count()
        return true
    end if
    if sameYearMatches > 1
        print "[RokuPlus source-match] result=ambiguous-year-search-match matches="; sameYearMatches; " title="; left(orbitText(discovery.title,100),100)
    end if
    return false
end function

function rpHdTaskSameDiscoveryItem(discovery as dynamic, candidate as dynamic, searchQuery as string) as boolean
    if type(discovery) <> "roAssociativeArray" or type(candidate) <> "roAssociativeArray" then return false
    if orbitText(discovery.kind,16) <> orbitText(candidate.kind,16) then return false
    wantedImdb = lcase(orbitText(discovery.imdbId,40))
    candidateImdb = lcase(orbitText(candidate.imdbId,40))
    wantedYear = rpHdTaskCinemetaYear(discovery.year)
    candidateYear = rpHdTaskCinemetaYear(candidate.year)
    candidateTitle = rpHdTaskCinemetaTitleKey(candidate.title)
    discoveryTitle = rpHdTaskCinemetaTitleKey(discovery.title)
    queryTitle = rpHdTaskCinemetaTitleKey(searchQuery)
    if candidateTitle = "" then return false
    if wantedImdb <> "" and candidateImdb <> ""
        if wantedImdb = candidateImdb
            ' The shared IMDb identity is stronger than a provider's possibly
            ' stale or incorrectly parsed year. Keep the year diagnostic, not a veto.
            if wantedYear <> "" and candidateYear <> "" and wantedYear <> candidateYear
                print "[RokuPlus source-match] imdb-confirmed-year-diff title="; left(orbitText(candidate.title,100),100); " wanted="; wantedYear; " provider="; candidateYear
            end if
            return true
        end if
        ' Provider metadata can carry a different external ID for the same
        ' edition. Accept that conflict only with exact title AND matching year.
        if candidateTitle <> discoveryTitle or wantedYear = "" or candidateYear = "" or wantedYear <> candidateYear then return false
        return true
    end if
    if candidateTitle <> discoveryTitle and (queryTitle = "" or candidateTitle <> queryTitle) then return false
    ' If both years exist they must agree. If one source omits the year,
    ' exact title identity is still required and ambiguity is rejected above.
    if wantedYear <> "" and candidateYear <> "" and wantedYear <> candidateYear then return false
    return true
end function

' Browse catalogs use Cinemeta directly. Providers are resolved only when the user presses Play.
function rpHdTaskCinemetaBrowseCatalog(request as object, answer as object, fetcher as dynamic) as object
    kind = orbitText(request.kind,10)
    if kind <> "movie" and kind <> "series" and kind <> "all"
        answer.message = "El tipo de catálogo no es válido."
        return answer
    end if
    skip = orbitInteger(request.skip,200000)
    if skip < 0 then skip = 0
    skip = (skip \ 20) * 20
    sort = "popular"
    catalogId = "top"
    genre = rpHdTaskCinemetaGenre(orbitText(request.query,80))
    if orbitInteger(request.attempt,1) = 1 then sort = "recent"
    ' Genre categories are requested from Cinemeta with their own genre extra.
    ' Only the unfiltered "Todos" feed uses the general top catalog.
    catalogKinds = [kind]
    if kind = "all" then catalogKinds = ["movie","series"]
    transfer = CreateObject("roUrlTransfer")
    answer.items = []
    successes = 0
    failures = 0
    hasMore = false
    for each catalogKind in catalogKinds
        if m.top.cancelRequested or rpHdTaskSliceExpired() then exit for
        endpoint = "https://v3-cinemeta.strem.io/catalog/"+catalogKind+"/"+catalogId
        if genre <> ""
            ' Stremio encodes extra arguments in one path segment, joined with ampersands.
            endpoint += "/genre="+genre+"&skip="+skip.toStr()
        else
            endpoint += "/skip="+skip.toStr()
        end if
        endpoint += ".json"
        print "[RokuPlus cinemeta-catalog] request kind="; catalogKind; " genre="; genre; " skip="; skip
        response = fetcher(endpoint,"cinemeta","")
        if response.cancelled then return rpHdTaskFailure(answer,response)
        if not response.ok
            failures++
            print "[RokuPlus cinemeta-catalog] kind="; catalogKind; " sort="; sort; " result=error"
        else
            data = ParseJson(response.body)
            if type(data) <> "roAssociativeArray" or type(data.metas) <> "roArray"
                failures++
                print "[RokuPlus cinemeta-catalog] kind="; catalogKind; " sort="; sort; " result=invalid-json"
            else
                successes++
                if data.metas.count() >= 20 then hasMore = true
                added = 0
                for each meta in data.metas
                    if added >= 20 then exit for
                    if type(meta) = "roAssociativeArray"
                        metaId = orbitText(meta.id,80)
                        title = orbitText(meta.name,200).trim()
                        metaType = orbitText(meta.type,16)
                        if title <> "" and CreateObject("roRegex","^tt[0-9]{6,12}$","").isMatch(metaId) and (metaType = "" or metaType = catalogKind)
                            year = rpHdTaskCinemetaYear(meta.year)
                            if year = "" then year = rpHdTaskCinemetaYear(meta.releaseInfo)
                            genres = []
                            if type(meta.genres) = "roArray"
                                for each sourceGenre in meta.genres
                                    if GetInterface(sourceGenre,"ifString") <> invalid
                                        genreName = lcase(sourceGenre.trim())
                                        if genreName <> ""
                                            genreExists = false
                                            for each savedGenre in genres
                                                if savedGenre = genreName then genreExists = true
                                            end for
                                            if not genreExists then genres.push(genreName)
                                        end if
                                    end if
                                end for
                            end if
                            item = {
                                id:"cinemeta-"+metaId, imdbId:metaId, kind:catalogKind
                                provider:"all", discoverySource:"cinemeta", library:"hd-online"
                                title:title, searchQuery:"", year:year
                                description:orbitText(meta.description,4000)
                                poster:orbitText(meta.poster,2048), background:orbitText(meta.background,2048)
                                genres:genres, runtime:0, language:"", seasons:[]
                                source:"Cinemeta"
                            }
                            answer.items.push(item)
                            added++
                        end if
                    end if
                end for
            end if
        end if
    end for
    answer.ok = successes > 0
    answer.partial = failures > 0
    answer.hasMore = hasMore
    answer.nextSkip = skip + 20
    answer.totalKnown = false
    answer.total = 0
    answer.message = ""
    if not answer.ok then answer.message = "Cinemeta no pudo cargar esta categoría. Vuelve a intentarlo."
    print "[RokuPlus cinemeta-catalog] kind="; kind; " sort="; sort; " catalog="; catalogId; " genre="; genre; " skip="; skip; " results="; answer.items.count(); " failures="; failures
    return answer
end function

function rpHdTaskCinemetaGenre(value as string) as string
    key = lcase(value.trim())
    if key = "acción" or key = "accion" then return "Action"
    if key = "comedia" then return "Comedy"
    if key = "drama" then return "Drama"
    if key = "terror" then return "Horror"
    if key = "ciencia ficción" or key = "ciencia ficcion" then return "Sci-Fi"
    if key = "animación" or key = "animacion" then return "Animation"
    return ""
end function

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
            sourceElapsed = CreateObject("roTimespan")
            sourceElapsed.mark()
            response = rpHdTaskCatalogPage(source,answer.kind,page,query,fetcher)
            sourceMs = sourceElapsed.totalMilliseconds()
            m.hdProviderDeadline = 0
            print "[RokuPlus catalog] source="; source; " elapsed_ms="; sourceMs; " ok="; response.ok; " cancelled="; response.cancelled
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
    deduped = []
    if rows > 200 then rows = 200
    for row = 0 to rows-1
        for each entries in pages
            if row < entries.count()
                item = entries[row]
                if answer.kind = "series" or answer.kind = "movie"
                    if answer.kind = "series" then item = rpHdTaskNormalizeSeriesTitle(item)
                    duplicateIndex = -1
                    for existingIndex = 0 to deduped.count()-1
                        existing = deduped[existingIndex]
                        if rpHdTaskSameCatalogItem(existing,item)
                            duplicateIndex = existingIndex
                            exit for
                        end if
                    end for
                    if duplicateIndex < 0
                        deduped.push(item)
                    else
                        ' Keep the first provider identity and fill only missing display metadata.
                        existing = deduped[duplicateIndex]
                        if existing.year = "" and item.year <> "" then existing.year = item.year
                        if existing.poster = "" and item.poster <> "" then existing.poster = item.poster
                        if existing.background = "" and item.background <> "" then existing.background = item.background
                        if existing.description = "" and item.description <> "" then existing.description = item.description
                        ' The aggregate catalog can deduplicate the same title across providers.
                        ' Preserve genre metadata from every matching source, not only the first card.
                        if type(existing.genres) <> "roArray" then existing.genres = []
                        if type(item.genres) = "roArray"
                            for each incomingGenre in item.genres
                                if GetInterface(incomingGenre,"ifString") <> invalid
                                    genreName = lcase(incomingGenre.trim())
                                    if genreName <> ""
                                        genreExists = false
                                        for each savedGenre in existing.genres
                                            if GetInterface(savedGenre,"ifString") <> invalid
                                                if lcase(savedGenre.trim()) = genreName then genreExists = true
                                            end if
                                        end for
                                        if not genreExists then existing.genres.push(genreName)
                                    end if
                                end if
                            end for
                        end if
                        if existing.providerTmdbId = "" and item.providerTmdbId <> "" then existing.providerTmdbId = item.providerTmdbId
                        if existing.imdbId = "" and item.imdbId <> "" then existing.imdbId = item.imdbId
                    end if
                else
                    deduped.push(item)
                end if
            end if
        end for
    end for
    answer.items = deduped
    ' Optional one-request enrichment, limited to the remaining catalog time budget.
    rpHdTaskEnrichCatalogMetadata(answer.items,answer.kind,fetcher)
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
        totalBudget = 40000
        if GetInterface(m.hdTotalBudgetMs,"ifInt") <> invalid then totalBudget = m.hdTotalBudgetMs
        budget = (totalBudget-now) \ remaining
        ' In "Todas", one slow provider must not consume the entire window
        ' reserved for the remaining sources. Keep a fair share, capped at 9s.
        if budget > 9000 then budget = 9000
        if budget < 0 then budget = 0
        m.hdProviderDeadline = now+budget
    end if
end sub

' Resolve is a single-provider operation with a 60s total budget.
' Give each embed/variant enough time for HLS and TS validation requests;
' the 9s cap above remains for fair-share catalog aggregation.
sub rpHdTaskBeginResolveSlice(remaining as integer)
    m.hdProviderDeadline = 0
    if remaining < 1 then remaining = 1
    if m.hdElapsed <> invalid
        now = m.hdElapsed.totalMilliseconds()
        totalBudget = 60000
        if GetInterface(m.hdTotalBudgetMs,"ifInt") <> invalid then totalBudget = m.hdTotalBudgetMs
        budget = (totalBudget-now) \ remaining
        if budget > 20000 then budget = 20000
        if budget < 0 then budget = 0
        m.hdProviderDeadline = now+budget
        print "[RokuPlus resolve-budget] remainingEmbeds="; remaining; " sliceMs="; budget
    end if
end sub

function rpHdTaskSliceExpired() as boolean
    if m.hdElapsed = invalid then return false
    now = m.hdElapsed.totalMilliseconds()
    totalBudget = 40000
    if GetInterface(m.hdTotalBudgetMs,"ifInt") <> invalid then totalBudget = m.hdTotalBudgetMs
    if now >= totalBudget then return true
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
        runtime:orbitInteger(value.runtime,86400),language:"",seasons:rpHdTaskArray(value.seasons)
        seasonNumbers:rpHdTaskArray(value.seasonNumbers)
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
        if instr(1,endpoint,"https://lamovie.org/wp-api/v1/") = 1
            diagnosticBody = body.replace(chr(13)," ").replace(chr(10)," ")
            if len(diagnosticBody) > 120 then diagnosticBody = left(diagnosticBody,120)
            print "[RokuPlus lamovie-diagnostic] invalid_json bytes="; len(body); " body="; diagnosticBody
        end if
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

' A master playlist may link each video variant to an external audio group.
' Accept Spanish audio regardless of DEFAULT/AUTOSELECT ordering in the provider manifest.
function rpHdTaskAudioGroupCount(master as object, groupId as string) as integer
    count = 0
    for each track in master.audioTracks
        if track.group = groupId and track.url <> "" then count++
    end for
    return count
end function

' Keep the original master so Roku can expose alternate audio tracks.
' The selected rendition must pass the device capability guard; the Video node's
' maxVideoDecodeResolution ceiling is applied before playback to constrain ABR.
function rpHdTaskNativeAudioMasterSafe(master as object, selected as object, decoderAccept as dynamic) as boolean
    if master.encrypted or selected.audioGroup = "" then return false
    if type(master.audioTracks) <> "roArray" or type(master.variants) <> "roArray" then return false
    if rpHdTaskAudioGroupCount(master,selected.audioGroup) < 2 then return false
    for each track in master.audioTracks
        if track.group = selected.audioGroup
            if track.url = "" then return false
        end if
    end for
    if not rpHdTaskNativeRenditionSafe(selected,decoderAccept) then return false
    return true
end function

' Shared native-HLS capability gate for BOTH player instances and both audio modes.
' Keep the ceiling aligned so a valid 1440x720 rendition is not sent to TS relay
' solely because the default-audio and multiaudio paths use different limits.
' The decoder's 1280x720 memory cap remains in place; this gate bounds the
' source rendition and still delegates device codec support to the existing selector.
function rpHdTaskNativeRenditionSafe(selected as object, decoderAccept as dynamic) as boolean
    if selected.height > 720 or selected.width > 1440 then return false
    candidate = {variants:[selected],encrypted:false}
    if rpHdOnlineSelectVariant(candidate,decoderAccept) = invalid then return false
    return true
end function

' Last-resort native HLS eligibility for a valid rendition when the TS relay
' validator cannot certify the sample. No audio-language metadata is required.
function rpHdTaskNativeDefaultAudioSafe(master as object, selected as object, decoderAccept as dynamic) as boolean
    if master.encrypted then return false
    if not rpHdTaskNativeRenditionSafe(selected,decoderAccept) then return false
    return true
end function

function rpHdTaskSpanishAudio(master as object, variant as object) as boolean
    if variant.audioGroup = "" or type(master.audioTracks) <> "roArray" then return false
    for each track in master.audioTracks
        if track.group = variant.audioGroup
            language = lcase(orbitText(track.language,40))
            name = lcase(orbitText(track.name,120))
            if language = "es" or language = "spa" or left(language,3) = "es-" then return true
            if instr(1,name,"español") > 0 or instr(1,name,"espanol") > 0 or instr(1,name,"spanish") > 0 or instr(1,name,"latino") > 0 or instr(1,name,"castellano") > 0 then return true
        end if
    end for
    return false
end function

function rpHdTaskHasSpanishValidatedAudio(tracks as dynamic) as boolean
    if type(tracks) <> "roArray" then return false
    for each track in tracks
        language = lcase(orbitText(track.language,40))
        name = lcase(orbitText(track.name,120))
        if language = "es" or language = "spa" or left(language,3) = "es-" then return true
        if instr(1,name,"español") > 0 or instr(1,name,"espanol") > 0 or instr(1,name,"spanish") > 0 or instr(1,name,"latino") > 0 or instr(1,name,"castellano") > 0 then return true
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

function rpHdTaskSegmentDurations(body as string, expectedCount as integer) as object
    durations = []
    pendingDuration = -1.0
    text = orbitText(body,2097153)
    if len(text) > 2097152 or expectedCount < 1 then return durations
    for each raw in text.split(chr(10))
        line = raw.trim()
        if left(line,8) = "#EXTINF:"
            value = Mid(line,9)
            comma = Instr(1,value,",")
            if comma > 0 then value = Left(value,comma-1)
            duration = Val(value)
            if duration <= 0 or duration > 3600 then return []
            pendingDuration = duration
        else if line <> "" and left(line,1) <> "#"
            if pendingDuration <= 0 then return []
            durations.push(pendingDuration)
            pendingDuration = -1.0
            if durations.count() > expectedCount then return []
        end if
    end for
    if durations.count() <> expectedCount then return []
    return durations
end function

function rpHdTaskSegmentList(body as string, baseUrl as string) as object
    segments = []
    for each raw in body.split(chr(10))
        line = raw.trim()
        if line <> "" and left(line,1) <> "#"
            url = rpHdOnlineJoin(baseUrl,line)
            if url = "" then return []
            segments.push(url)
            if segments.count() > 2000 then return []
        end if
    end for
    return segments
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
    if format = invalid
        print "[RokuPlus decode-cap] validCodecDeclaration=false"
        return false
    end if
    device = CreateObject("roDeviceInfo")
    accepted = false
    for each codec in ["mpeg4 avc","h264"]
        response = device.canDecodeVideo({"codec":codec,"profile":format.profile,"level":format.capabilityLevel})
        supported = false
        if type(response) = "roAssociativeArray"
            if GetInterface(response.result,"ifBoolean") <> invalid then supported = response.result
        end if
        print "[RokuPlus decode-cap] codec="; codec; " profile="; format.profile; " level="; format.capabilityLevel; " supported="; supported
        if supported then accepted = true
    end for
    return accepted
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
    if role = "cinemeta" then return CreateObject("roRegex","^https://v3-cinemeta\.strem\.io/(catalog/(movie|series)/(top(/search=[A-Za-z0-9%._~!*'()+-]+|/genre=[A-Za-z0-9%._~!*'()+-]+(&skip=[0-9]+)?|/skip=[0-9]+)?|year/genre=[0-9]{4}(/skip=[0-9]+)?)|meta/(movie|series)/tt[0-9]{6,12})\.json$","").isMatch(endpoint)
    if role = "tvmaze" then return CreateObject("roRegex","^https://api\.tvmaze\.com/(search/shows\?q=[^#]+|shows/[0-9]+/episodes)$","").isMatch(endpoint)
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
        if CreateObject("roRegex","^https://vimeos\.net/embed-[a-zA-Z0-9_-]+(\.html)?(\?[^#]*)?$","").isMatch(endpoint) then return true
        if CreateObject("roRegex","^https://(www\.)?voe\.sx/(e/)?[a-z0-9]{8,20}/?$","i").isMatch(endpoint) then return true
        return CreateObject("roRegex","^https://arianathankspecial\.com/e/[a-z0-9]{8,20}/?$","i").isMatch(endpoint)
    end if
    if role = "media" or role = "sample" or role = "audio-sample" or role = "sample-tail" or role = "sample-full" then return rpHdOnlineCdn(endpoint) <> ""
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
    if role = "api" or role = "tvmaze" or role = "cinemeta"
        transfer.addHeader("Accept","application/json")
        if referer = "" and instr(1,endpoint,"https://cinehax.org/api/rest/v1/") = 1 then referer = "https://cinehax.org/"
    end if
    if referer <> "" then transfer.addHeader("Referer",referer)
    limit = 2097152
    if role = "sample" or role = "audio-sample"
        transfer.addHeader("Range","bytes=0-65535")
        limit = 131072
    else if role = "sample-tail"
        transfer.addHeader("Range","bytes=-65612")
        limit = 65612
    else if role = "sample-full"
        ' Diagnostic only: some provider first segments exceed 2 MiB.
        limit = 4194304
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
        print "[RokuPlus http] role="; role; " host="; rpHdTaskSafeHost(endpoint); " started=false"
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
        sliceExpired = rpHdTaskSliceExpired()
        elapsedMs = elapsed.totalMilliseconds()
        if sliceExpired
            answer.message = "La fuente HD tardó demasiado. Vuelve a intentar."
            exit while
        end if
        if elapsedMs >= 20000
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
    answer.httpStatus = code
    answer.httpElapsedMs = elapsed.totalMilliseconds()
    answer.httpFinished = finished
    answer.httpContentType = rpHdTaskResponseHeader(responseHeaders,"content-type")
    answer.httpContentLength = rpHdTaskResponseHeader(responseHeaders,"content-length")
    answer.httpContentRange = rpHdTaskResponseHeader(responseHeaders,"content-range")
    answer.httpAcceptRanges = rpHdTaskResponseHeader(responseHeaders,"accept-ranges")
    answer.httpCacheControl = rpHdTaskResponseHeader(responseHeaders,"cache-control")
    answer.httpAge = rpHdTaskResponseHeader(responseHeaders,"age")
    answer.httpServer = rpHdTaskResponseHeader(responseHeaders,"server")
    answer.httpVia = rpHdTaskResponseHeader(responseHeaders,"via")
    answer.httpFinalUrl = orbitText(transfer.getUrl(),4096)
    if answer.httpFinalUrl = "" then answer.httpFinalUrl = endpoint
    redirectAllowed = true
    if role = "cinemeta" and not rpHdTaskAllowedUrl(answer.httpFinalUrl,"cinemeta")
        redirectAllowed = false
        answer.message = "Cinemeta redirigió a un dominio no permitido."
        print "[RokuPlus cinemeta] redirect_rejected=1 host="; rpHdTaskSafeHost(answer.httpFinalUrl)
    end if
    if role = "tvmaze" and not rpHdTaskAllowedUrl(answer.httpFinalUrl,"tvmaze")
        redirectAllowed = false
        answer.message = "TVmaze redirigió a un dominio no permitido."
        print "[RokuPlus tvmaze] redirect_rejected=1 host="; rpHdTaskSafeHost(answer.httpFinalUrl)
    end if
    if role = "embed" and not rpHdTaskAllowedUrl(answer.httpFinalUrl,"embed")
        redirectAllowed = false
        answer.message = "La fuente redirigió a un dominio no permitido."
        print "[RokuPlus http] role=embed redirect_rejected=1 finalHost="; rpHdTaskSafeHost(answer.httpFinalUrl)
    end if
    successCode = code = 200 and redirectAllowed
    if role = "sample" or role = "audio-sample" or role = "sample-tail" then successCode = code = 206
    if finished and successCode and not m.top.cancelRequested
        bytes = rpHdTaskFileSize(files.stat(filename))
        if bytes > 0 and bytes <= limit
            if role = "sample" or role = "audio-sample" or role = "sample-tail" or role = "sample-full"
                rangeOk = true
                if role = "sample" or role = "audio-sample" then rangeOk = rpHdTaskRangeResponse(responseHeaders,bytes)
                if role = "sample-tail" then rangeOk = rpHdTaskTailRangeResponse(responseHeaders,bytes)
                if rangeOk
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
    bytesRead = rpHdTaskFileSize(files.stat(filename))
    print "[RokuPlus http] role="; role; " host="; rpHdTaskSafeHost(endpoint); " status="; code; " finished="; finished; " ms="; answer.httpElapsedMs
    print "[RokuPlus http] bytes="; bytesRead; " ok="; answer.ok; " type="; answer.httpContentType; " length="; answer.httpContentLength
    print "[RokuPlus http] bytes="; "cont"; " range="; answer.httpContentRange; " acceptRanges="; answer.httpAcceptRanges
    print "[RokuPlus http] cache="; answer.httpCacheControl; " age="; answer.httpAge; " server="; answer.httpServer; " via="; answer.httpVia
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

function rpHdTaskTailRangeResponse(headers as dynamic, bytes as integer) as boolean
    if type(headers) <> "roAssociativeArray" then return false
    value = ""
    for each name in headers
        if lcase(name) = "content-range" then value = orbitText(headers[name],120)
    end for
    range = CreateObject("roRegex","^bytes ([0-9]+)-([0-9]+)/([0-9]+)$","i").match(value.trim())
    if range.count() < 4 then return false
    firstByte = orbitInteger(range[1],2147483647,-1)
    lastByte = orbitInteger(range[2],2147483647,-1)
    totalBytes = orbitInteger(range[3],2147483647,-1)
    if firstByte < 0 or lastByte < firstByte or totalBytes <= lastByte then return false
    if bytes <> lastByte-firstByte+1 or bytes <> 65612 then return false
    if (firstByte mod 188) <> 0 or (totalBytes mod 188) <> 0 then return false
    return true
end function

function rpHdTaskFileSize(info as dynamic) as integer
    if type(info) <> "roAssociativeArray" then return -1
    if not info.doesExist("size") then return -1
    size = info.size
    numeric = GetInterface(size,"ifInt") <> invalid or GetInterface(size,"ifLongInt") <> invalid or GetInterface(size,"ifFloat") <> invalid or GetInterface(size,"ifDouble") <> invalid
    if not numeric then return -1
    if size < 0 then return -1
    if size > 4194304 then return 4194305
    return int(size)
end function

function rpHdTaskArray(value as dynamic) as object
    if type(value) = "roArray" then return value
    return []
end function
