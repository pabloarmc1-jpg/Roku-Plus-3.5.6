' Roku Plus: original personal television application.
sub init()
    m.top.backgroundColor = "0x09090BFF"
    m.top.focusable = true
    m.canvas = m.top.findNode("canvas")
    m.player = m.top.findNode("player")
    m.deadline = m.top.findNode("catalogDeadline")
    m.deadline.observeField("fire","catalogTimedOut")
    m.lease = m.top.findNode("playbackLease")
    m.lease.observeField("fire","renewPlaybackLease")
    m.activeJobId = ""
    m.leaseTask = invalid
    m.player.observeField("closed","playerClosed")
    m.player.observeField("diagnostics","playerDiagnostic")
    m.player.observeField("retryRequested","retryVideo")
    m.player.observeField("progress","playerProgress")
    m.player.observeField("progress","livePreviewProgress")
    m.player.observeField("previewReturned","livePreviewReturned")
    m.player.observeField("closedRequest","livePreviewClosed")
    m.previewTimer = m.top.findNode("livePreviewDelay")
    m.previewTimer.observeField("fire","startLivePreview")
    m.noteTimer = m.top.findNode("liveNoticeTimer")
    m.noteTimer.observeField("fire","liveNoticeElapsed")
    m.nextEpisodeTimer = m.top.findNode("nextEpisodeTimer")
    m.nextEpisodeTimer.observeField("fire","nextEpisodeTick")
    m.heroRotation = m.top.findNode("heroRotation")
    m.heroRotation.observeField("fire","heroRotationTick")
    m.heroRotation.control = "start"
    m.nextEpisode = invalid
    m.nextEpisodeCountdown = 0
    m.profileId = rpLoadProfileId()
    m.watchState = rpWatchLoad(m.profileId)
    m.profileCursor = 0
    m.lastPlaybackProgress = invalid
    m.watchSaveClock = CreateObject("roTimespan")
    m.watchSaveClock.mark()
    m.continueItems = rpWatchContinue(m.watchState)
    m.libraryMode = "history"
    m.libraryItems = []
    m.libraryCursor = 0
    m.view = "home"
    m.zone = "hero"
    m.nav = 0
    m.hero = 0
    m.heroFeature = 0
    m.cover = 0
    m.seriesCover = 0
    m.images = []
    m.focusItems = []
    m.kind = "movie"
    m.query = ""
    m.offset = 0
    m.nextOffset = 0
    m.more = false
    m.titles = []
    m.pageTitles = []
    m.genreFilter = "Todos"
    m.genreChoices = []
    m.channels = []
    m.countryChannels = []
    m.liveLoadedCountry = ""
    m.liveFilter = 0
    m.liveFilterCursor = 0
    m.liveFavorites = rpLiveLoadFavorites()
    m.latamChannels = []
    m.latamLoaded = false
    m.livePreviewOpen = false
    m.livePreviewItem = invalid
    m.livePreviewStatus = "Selecciona un canal"
    m.livePreviewKey = ""
    m.livePreviewRequestTag = ""
    m.liveRequestSequence = 0
    m.liveFullscreen = false
    m.liveAction = 0
    m.liveQuery = ""
    m.liveSearchCursor = 0
    m.cursor = 0
    m.liveCursor = 0
    m.season = 0
    m.episode = 0
    m.detail = invalid
    m.series = invalid
    m.detailOrigin = "home"
    m.autoplay = false
    m.busy = false
    m.job = invalid
    m.request = ""
    m.pending = invalid
    m.pendingSegmentUrls = invalid
    m.pendingTsRelay = false
    m.dialogBox = invalid
    m.dialogPurpose = ""
    m.note = ""
    m.action = 0
    m.playbackMode = "direct"
    m.capabilities = rpDeviceProfile()
    prefs = rpLoadPreferences(m.capabilities.recommendedCatalog)
    m.configured = prefs.configured
    m.catalogMode = prefs.mode
    m.countryCode = prefs.countryCode
    m.hdProvider = rpLoadHdProvider()
    m.compatBase = rpLoadCompatBase()
    m.theme = rpLoadTheme()
    m.themeCursor = 0
    m.hdSourceCursor = 0
    m.hdLibrary = rpHdLibrary()
    m.features = []
    m.homeSeries = []
    m.homeJobs = []
    m.homeCache = {}
    m.homeLoading = false
    m.settingsCursor = 0
    m.creditsPage = 0
    m.creditsPages = []
    if not m.configured
        beginSetup(false,false)
    else
        refreshHome()
    end if
    drawScreen()
    m.top.setFocus(true)
end sub

function timeText(seconds as integer) as string
    if seconds <= 0 then return ""
    minutes = seconds \ 60
    if minutes < 60 then return minutes.toStr() + " min"
    return (minutes \ 60).toStr() + " h " + (minutes mod 60).toStr() + " min"
end function

sub cancelRequest()
    m.deadline.control = "stop"
    if m.job <> invalid
        m.job.unobserveField("result")
        m.job.unobserveField("state")
        m.job.cancelRequested = true
    end if
    m.job = invalid
    m.request = ""
    m.pending = invalid
    m.busy = false
end sub

sub fetch(context as object)
    cancelRequest()
    m.pending = context
    m.request = CreateObject("roDeviceInfo").getRandomUUID()
    online = (usesOnlineHd() or (context.doesExist("item") and rpIsOnlineHdItem(context.item))) and context.operation <> "country" and context.operation <> "latam"
    taskName = "CatalogTask"
    if online then taskName = "HdCatalogTask"
    task = CreateObject("roSGNode",taskName)
    if online
        task.provider = m.hdProvider
        ' Continue Watching can contain titles from several HD providers.
        ' Resolve metadata/playback against the provider stored on the item,
        ' not whichever provider happens to be selected in Settings today.
        if context.operation <> "catalog" and context.doesExist("item")
            if type(context.item) = "roAssociativeArray" and context.item.doesExist("provider")
                ' Keep this component independent from helper namespace resolution.
                itemProvider = lcase(orbitText(context.item.provider,32))
                if itemProvider = "lamovie" or itemProvider = "allcalidad" or itemProvider = "cinehax" or itemProvider = "seriesmetro" or itemProvider = "cinecalidad"
                    task.provider = itemProvider
                end if
            end if
        end if
    end if
    if online and context.operation = "resolve" then task.attempt = orbitInteger(context.item.hdAttempt,99)
    task.operation = context.operation
    task.kind = m.kind
    if context.doesExist("kind") then task.kind = context.kind
    if context.operation = "country" then task.countryCode = m.countryCode
    task.requestId = m.request
    task.query = m.query
    if context.operation = "catalog" then task.skip = context.offset
    if context.doesExist("item")
        if online then task.item = context.item else task.imdbId = context.item.imdbId
        if context.item.kind = "episode"
            task.kind = "series"
            task.season = context.item.season
            if not online then task.episode = context.item.episode
        else
            task.kind = context.item.kind
        end if
    end if
    if online and context.doesExist("season") then task.season = context.season
    task.observeField("result","fetched")
    task.observeField("state","catalogState")
    m.job = task
    m.busy = true
    m.deadline.duration = 25
    m.deadlineMs = 25000
    if online
        m.deadline.duration = 45
        m.deadlineMs = 45000
    end if
    m.deadlineStart = CreateObject("roTimespan")
    m.deadlineStart.mark()
    m.note = ""
    drawScreen()
    m.deadline.control = "start"
    task.control = "RUN"
end sub

sub prepareCompatible()
    cancelRequest()
    m.playbackMode = "compatible"
    m.pending = {operation:"compatible",item:m.detail}
    m.request = CreateObject("roDeviceInfo").getRandomUUID()
    task = CreateObject("roSGNode","CompatTask")
    task.helperBase = m.compatBase
    task.itemId = m.detail.imdbId
    task.kind = m.detail.kind
    task.requestId = m.request
    if m.detail.kind = "episode"
        task.season = m.detail.season
        task.episode = m.detail.episode
    end if
    task.observeField("result","fetched")
    task.observeField("state","catalogState")
    m.job = task
    m.busy = true
    m.note = ""
    m.deadline.duration = 35
    m.deadlineMs = 35000
    m.deadlineStart = CreateObject("roTimespan")
    m.deadlineStart.mark()
    drawScreen()
    m.deadline.control = "start"
    task.control = "RUN"
end sub

sub catalogTimedOut()
    if not m.busy then return
    if m.deadlineStart <> invalid
        if m.deadlineStart.totalMilliseconds() < m.deadlineMs - 100 then return
    end if
    cancelRequest()
    m.autoplay = false
    m.note = "La consulta tardó demasiado. Pulsa OK para intentar de nuevo o Atrás para volver."
    drawScreen()
end sub

sub catalogState(event as object)
    if m.job = invalid then return
    if not m.job.isSameNode(event.getRoSGNode()) then return
    if event.getData() <> "STOP" then return
    if type(m.job.result) = "roAssociativeArray" then return
    cancelRequest()
    m.autoplay = false
    m.note = "No se pudo completar la consulta. Vuelve a intentar."
    drawScreen()
end sub

sub fetched(event as object)
    if m.job = invalid then return
    if not m.job.isSameNode(event.getRoSGNode()) then return
    answer = event.getData()
    if type(answer) <> "roAssociativeArray" then return
    if answer.requestId <> m.request then return
    context = m.pending
    cancelRequest()
    if not answer.ok
        m.autoplay = false
        m.note = answer.message
        if context.operation = "compatible" then m.note = "La reproducción con PC no está disponible. Puedes elegir Reproducir para usar la conexión directa."
        drawScreen()
        return
    end if
    if context.operation = "catalog"
        if answer.items.count() = 0 and context.offset > 0 and not answer.hasMore
            m.pageTitles = []
            applyGenreFilter()
            m.more = false
            m.note = "Llegaste al final de los resultados."
        else
            m.pageTitles = orbitUniqueCatalogItems(answer.items)
            applyGenreFilter()
            m.offset = context.offset
            m.nextOffset = answer.nextSkip
            m.more = answer.hasMore
            m.cursor = 0
            if context.doesExist("last") and context.last then m.cursor = m.titles.count()-1
            if m.cursor < 0 then m.cursor = 0
        end if
        m.zone = "grid"
        if answer.partial = true then m.note = "Una fuente no respondió. Se muestran las opciones disponibles."
    else if context.operation = "meta"
        ' Keep the original catalog identity when a provider metadata adapter
        ' returns a reduced item. Continue Watching needs these source fields.
        if type(answer.item) = "roAssociativeArray" and context.doesExist("item") and type(context.item) = "roAssociativeArray"
            identityFields = ["provider", "providerId", "providerSlug", "providerTmdbId", "providerKind", "season", "episode", "seriesTitle"]
            for each identityField in identityFields
                if context.item.doesExist(identityField)
                    sourceValue = context.item[identityField]
                    if sourceValue <> invalid
                        keepValue = true
                        if GetInterface(sourceValue, "ifString") <> invalid
                            if sourceValue = "" then keepValue = false
                        end if
                        if keepValue then answer.item[identityField] = sourceValue
                    end if
                end if
            end for
        end if
        m.detail = answer.item
        if m.autoplay
            m.autoplay = false
            playDetail()
            return
        end if
    else if context.operation = "resolve"
        if type(answer.mediaHeaders) = "roAssociativeArray" then m.detail.mediaHeaders = answer.mediaHeaders
        m.detail.hdAttempt = orbitInteger(answer.attemptUsed,99)
        m.pendingSegmentUrls = answer.segmentUrls
        m.pendingTsRelay = false
        if answer.tsRelayEnabled = true then m.pendingTsRelay = true
        launchVideo(m.detail,answer.url,answer.streamFormat)
        return
    else if context.operation = "episodes"
        if m.series = invalid or context.item.id <> m.series.id then return
        for each incoming in answer.seasons
            for i = 0 to m.series.seasons.count()-1
                if m.series.seasons[i].number = incoming.number then m.series.seasons[i] = incoming
            end for
        end for
        m.episode = 0
    else if context.operation = "compatible"
        m.activeJobId = answer.jobid
        launchVideo(m.detail,answer.url,"hls")
        return
    else if context.operation = "country" or context.operation = "latam"
        if context.operation = "country"
            if answer.countryCode <> m.countryCode then return
            m.countryChannels = answer.items
            m.liveLoadedCountry = answer.countryCode
        else
            m.latamChannels = answer.items
            m.latamLoaded = true
        end if
        if m.view = "live" then refreshLiveList(true)
    end if
    drawScreen()
    if not m.liveFullscreen and m.dialogBox = invalid then m.top.setFocus(true)
end sub

sub openCatalog(kind as string)
    m.kind = kind
    m.nav = 1
    if kind = "series" then m.nav = 2
    m.query = ""
    m.genreFilter = "Todos"
    m.pageTitles = []
    m.titles = []
    m.cursor = 0
    m.offset = 0
    m.view = "browse"
    m.zone = "grid"
    loadBrowsePage(0)
end sub

sub openDetails(item as object, origin as string, playNow = false as boolean)
    m.detail = item
    m.detail.hdAttempt = 0
    m.detailOrigin = origin
    m.autoplay = playNow
    m.action = 0
    m.view = "detail"
    m.zone = "action"
    m.kind = "movie"
    if item.kind = "series" or item.kind = "episode" then m.kind = "series"
    if item.kind = "episode" or (m.catalogMode = "hd" and not usesOnlineHd() and not rpIsOnlineHdItem(item))
        if playNow
            m.autoplay = false
            playDetail()
        else
            drawScreen()
        end if
    else
        fetch({operation:"meta",item:item})
    end if
end sub

sub launchVideo(item as object, url as string, format as string)
    ' Recover LaMovie numeric identity from the canonical HD id when a
    ' catalog item arrives with its slug but without providerId.
    itemProvider = lcase(orbitText(item.provider,32))
    if itemProvider = "lamovie"
        currentProviderId = ""
        if item.doesExist("providerId") then currentProviderId = orbitText(item.providerId,40)
        if currentProviderId = ""
            providerPrefix = "hdo-lamovie-"
            canonicalId = orbitText(item.id,200)
            if left(canonicalId,len(providerPrefix)) = providerPrefix
                providerIdText = mid(canonicalId,len(providerPrefix)+1)
                providerIdNumber = orbitInteger(providerIdText,999999999)
                if providerIdNumber > 0 and providerIdNumber.toStr() = providerIdText
                    item.providerId = providerIdNumber
                end if
            end if
        end if
    end if
    stopLivePreview()
    m.player.theme = m.theme
    m.player.allowPreviewReturn = false
    m.player.presentation = "fullscreen"
    if m.playbackMode <> "compatible" or item.kind = "live" then m.activeJobId = ""
    eraseScreen()
    m.canvas.visible = false
    m.viewBeforePlayer = m.view
    m.view = "player"
    m.player.visible = true
    descriptor = {title:item.title,url:url,streamFormat:format,kind:item.kind,itemId:item.id,provider:orbitText(item.provider,32),direct:m.playbackMode="direct",poster:orbitText(item.poster,2048),background:orbitText(item.background,2048),year:orbitText(item.year,20)}
    if descriptor.provider = "lamovie"
        print "[RokuPlus identity] launch id="; descriptor.itemId; " providerId="; orbitText(item.providerId,40); " slugPresent="; item.doesExist("providerSlug"); " slug="; orbitText(item.providerSlug,200)
    end if
    if item.doesExist("season") then descriptor.season = item.season
    if item.doesExist("episode") then descriptor.episode = item.episode
    if item.doesExist("introStart") then descriptor.introStart = item.introStart
    if item.doesExist("introEnd") then descriptor.introEnd = item.introEnd
    savedProgress = rpWatchGet(m.watchState,item.id)
    if savedProgress <> invalid and savedProgress.position > 15 and savedProgress.watched <> true
        descriptor.resumePosition = savedProgress.position
    end if
    if item.doesExist("mediaHeaders") then descriptor.mediaHeaders = item.mediaHeaders
    if type(m.pendingSegmentUrls) = "roArray"
        descriptor.segmentUrls = m.pendingSegmentUrls
        m.pendingSegmentUrls = invalid
    end if
    if m.pendingTsRelay then descriptor.tsRelayEnabled = true
    m.pendingTsRelay = false
    ' Tag every playback request so delayed progress from an earlier decoder
    ' generation cannot overwrite the currently selected title's watch state.
    descriptor.requestId = CreateObject("roDeviceInfo").getRandomUUID()
    m.activePlaybackRequestId = descriptor.requestId
    m.lastPlaybackProgress = invalid
    m.player.request = descriptor
    if m.activeJobId <> "" then m.lease.control = "start"
end sub

sub renewPlaybackLease()
    if m.view <> "player" or m.activeJobId = "" then return
    if m.leaseTask <> invalid
        if m.leaseTask.state = "RUN" then return
    end if
    task = CreateObject("roSGNode","CompatTask")
    task.operation = "touch"
    task.helperBase = m.compatBase
    task.jobid = m.activeJobId
    task.requestId = CreateObject("roDeviceInfo").getRandomUUID()
    m.leaseTask = task
    task.control = "RUN"
end sub

sub playerProgress(event as object)
    sample = event.getData()
    if m.watchDiagCount = invalid then m.watchDiagCount = 0
    m.watchDiagCount = m.watchDiagCount + 1
    detailId = ""
    if type(m.detail) = "roAssociativeArray" and m.detail.doesExist("id") then detailId = orbitText(m.detail.id,180)
    sampleId = ""
    if type(sample) = "roAssociativeArray" and sample.doesExist("itemId") then sampleId = orbitText(sample.itemId,180)
    if m.watchDiagCount <= 8
        nativePosition = sample.position
        renderedPosition = 0
        if sample.doesExist("nativePosition") then nativePosition = sample.nativePosition
        if sample.doesExist("renderedPosition") then renderedPosition = sample.renderedPosition
        print "[RokuPlus watch] progress-event="; m.watchDiagCount; " view="; m.view; " sampleId="; sampleId; " detailId="; detailId; " presentation="; orbitText(sample.presentation,20); " live="; sample.live; " position="; sample.position; " native="; nativePosition; " rendered="; renderedPosition; " duration="; sample.duration
    end if
    if m.view <> "player" then return
    if type(sample) <> "roAssociativeArray"
        if m.watchDiagCount <= 8 then print "[RokuPlus watch] rejected=sample-type"
        return
    end if
    if m.activePlaybackRequestId <> invalid
        if sample.requestId <> m.activePlaybackRequestId
            if m.watchDiagCount <= 8 then print "[RokuPlus watch] rejected=request-mismatch sample="; orbitText(sample.requestId,80); " active="; orbitText(m.activePlaybackRequestId,80)
            return
        end if
    end if
    if sample.live = true
        if m.watchDiagCount <= 8 then print "[RokuPlus watch] rejected=live"
        return
    end if
    if sample.presentation <> "fullscreen"
        if m.watchDiagCount <= 8 then print "[RokuPlus watch] rejected=presentation"
        return
    end if
    if type(m.detail) <> "roAssociativeArray"
        if m.watchDiagCount <= 8 then print "[RokuPlus watch] rejected=detail-missing"
        return
    end if
    if sample.itemId <> m.detail.id
        if m.watchDiagCount <= 8 then print "[RokuPlus watch] rejected=id-mismatch sample="; sampleId; " detail="; detailId
        return
    end if
    m.lastPlaybackProgress = sample
    m.watchState = rpWatchUpdate(m.watchState,m.detail,sample.position,sample.duration)
    record = rpWatchGet(m.watchState,m.detail.id)
    if m.watchSaveClock = invalid
        saved = rpWatchSave(m.watchState,m.profileId)
        m.watchSaveClock = CreateObject("roTimespan")
        m.watchSaveClock.mark()
        print "[RokuPlus watch] save-first="; saved; " records="; m.watchState.count(); " id="; detailId; " position="; sample.position; " duration="; sample.duration
    else if m.watchSaveClock.totalMilliseconds() >= 5000
        saved = rpWatchSave(m.watchState,m.profileId)
        m.watchSaveClock.mark()
        print "[RokuPlus watch] save-periodic="; saved; " records="; m.watchState.count(); " id="; detailId; " position="; sample.position; " duration="; sample.duration
    end if
    if record <> invalid then print "[RokuPlus watch] record id="; detailId; " position="; record.position; " duration="; record.duration; " provider="; orbitText(record.provider,32); " slug="; orbitText(record.providerSlug,200)
    m.continueItems = rpWatchContinue(m.watchState)
end sub

sub toggleCurrentWatch(field as string)
    if m.detail = invalid then return
    m.watchState = rpWatchToggle(m.watchState,m.detail,field)
    rpWatchSave(m.watchState,m.profileId)
    m.continueItems = rpWatchContinue(m.watchState)
    if field = "watched"
        record = rpWatchGet(m.watchState,m.detail.id)
        if record <> invalid and record.watched then m.note = "Marcada como vista." else m.note = "Marcada como no vista."
    else
        record = rpWatchGet(m.watchState,m.detail.id)
        if record <> invalid and record.listed then m.note = "Añadida a Mi lista." else m.note = "Eliminada de Mi lista."
    end if
    drawScreen()
end sub

sub nextEpisodeTick()
    if m.nextEpisode = invalid then m.nextEpisodeTimer.control = "stop": return
    m.nextEpisodeCountdown--
    if m.nextEpisodeCountdown <= 0
        item = m.nextEpisode
        m.nextEpisode = invalid
        m.nextEpisodeTimer.control = "stop"
        m.note = ""
        openDetails(item,"episodes",true)
        return
    end if
    m.note = "Siguiente capítulo en "+m.nextEpisodeCountdown.toStr()+" s · OK para reproducir ahora · Atrás para cancelar"
    drawScreen()
end sub

sub cancelNextEpisode()
    m.nextEpisodeTimer.control = "stop"
    m.nextEpisode = invalid
    m.nextEpisodeCountdown = 0
    m.note = "Reproducción automática cancelada."
    drawScreen()
end sub

sub playerClosed(event as object)
    if event.getData() <> true then return
    if m.player.active = true then return
    if m.view = "live" then return
    if m.view <> "player" then return
    closeSaved = rpWatchSave(m.watchState,m.profileId)
    closeRecord = invalid
    if type(m.detail) = "roAssociativeArray" and m.detail.doesExist("id") then closeRecord = rpWatchGet(m.watchState,m.detail.id)
    if closeRecord <> invalid
        print "[RokuPlus watch] close-save="; closeSaved; " id="; orbitText(closeRecord.id,180); " position="; closeRecord.position; " duration="; closeRecord.duration; " provider="; orbitText(closeRecord.provider,32)
    else
        print "[RokuPlus watch] close-save="; closeSaved; " record=missing"
    end if
    if m.watchSaveClock <> invalid then m.watchSaveClock.mark()
    m.lease.control = "stop"
    if m.leaseTask <> invalid then m.leaseTask.cancelRequested = true
    m.leaseTask = invalid
    m.activeJobId = ""
    m.player.visible = false
    m.view = m.viewBeforePlayer
    if m.recovering = true
        m.recovering = false
        if m.view = "live"
            channel = m.channels[m.liveCursor]
            launchVideo(channel,channel.url,channel.streamFormat)
        else if m.playbackMode = "compatible" and m.catalogMode = "hevc"
            prepareCompatible()
        else
            playDetail()
        end if
        return
    end if
    finishedNaturally = false
    if type(m.lastPlaybackProgress) = "roAssociativeArray" then finishedNaturally = m.lastPlaybackProgress.state = "finished"
    if finishedNaturally and m.detail <> invalid
        watchedRecord = rpWatchGet(m.watchState,m.detail.id)
        if watchedRecord = invalid or watchedRecord.watched <> true then m.watchState = rpWatchToggle(m.watchState,m.detail,"watched")
        rpWatchSave(m.watchState,m.profileId)
        nextItem = rpFindNextEpisode()
        m.lastPlaybackProgress = invalid
        if nextItem <> invalid
            m.nextEpisode = nextItem
            m.nextEpisodeCountdown = 10
            m.note = "Siguiente capítulo en 10 s · OK para reproducir ahora · Atrás para cancelar"
            m.nextEpisodeTimer.control = "start"
            drawScreen()
            return
        end if
    end if
    m.lastPlaybackProgress = invalid
    m.continueItems = rpWatchContinue(m.watchState)
    m.note = ""
    drawScreen()
    m.top.setFocus(true)
end sub

function rpFindNextEpisode() as dynamic
    if m.series = invalid or m.detail = invalid then return invalid
    if m.detail.kind <> "episode" then return invalid
    for si = 0 to m.series.seasons.count()-1
        season = m.series.seasons[si]
        if season.number = m.detail.season
            for ei = 0 to season.episodes.count()-1
                ep = season.episodes[ei]
                if ep.episode = m.detail.episode and ei+1 < season.episodes.count() then return season.episodes[ei+1]
            end for
            if si+1 < m.series.seasons.count()
                following = m.series.seasons[si+1]
                if following.episodes.count() > 0 then return following.episodes[0]
            end if
        end if
    end for
    return invalid
end function

sub retryVideo(event as object)
    if m.view = "live"
        retry = event.getData()
        if type(retry) <> "roAssociativeArray" then return
        if not m.livePreviewOpen or m.livePreviewItem = invalid then return
        if retry.requestId <> m.livePreviewRequestTag or retry.itemId <> m.livePreviewItem.id then return
        fullscreen = m.liveFullscreen
        stopLivePreview(false)
        startLivePreview()
        if fullscreen and m.livePreviewOpen
            m.liveFullscreen = true
            m.player.presentation = "fullscreen"
        end if
        return
    end if
    if m.view <> "player" then return
    if m.detail <> invalid and usesOnlineHd()
        m.detail.hdAttempt = orbitInteger(m.detail.hdAttempt,99)+1
        if m.detail.hdAttempt > 99 then m.detail.hdAttempt = 0
    end if
    m.recovering = true
    m.player.callFunc("closePlayback")
end sub

sub playerDiagnostic(event as object)
    ' Diagnostics remain on this device's developer console; no upload route.
    sample = event.getData()
    if type(sample) = "roAssociativeArray" then print "[RokuPlus playback] "; FormatJson(sample)
end sub

function browseItemGenres(item as object) as string
    result = ""
    if item.doesExist("genre") and GetInterface(item.genre,"ifString") <> invalid then result = item.genre
    if item.doesExist("genres") and type(item.genres) = "roArray"
        for each entry in item.genres
            if GetInterface(entry,"ifString") <> invalid
                if result <> "" then result += " "
                result += entry
            else if type(entry) = "roAssociativeArray" and entry.doesExist("name")
                if GetInterface(entry.name,"ifString") <> invalid
                    if result <> "" then result += " "
                    result += entry.name
                end if
            end if
        end for
    end if
    return lcase(result)
end function

sub applyGenreFilter()
    m.titles = []
    for each item in m.pageTitles
        include = true
        if m.genreFilter <> "Todos"
            include = instr(1,browseItemGenres(item),lcase(m.genreFilter)) > 0
        end if
        if include then m.titles.push(item)
    end for
    m.cursor = 0
end sub

sub openGenreFilter()
    choices = ["Todos"]
    known = ["Acción","Aventura","Animación","Comedia","Crimen","Documental","Drama","Fantasía","Historia","Misterio","Romance","Ciencia ficción","Suspenso","Terror"]
    available = []
    for each item in m.pageTitles
        genres = browseItemGenres(item)
        for each genre in known
            if instr(1,genres,lcase(genre)) > 0
                found = false
                for each existing in available
                    if existing = genre then found = true
                end for
                if not found then available.push(genre)
            end if
        end for
    end for
    for each genre in known
        for each present in available
            if present = genre then choices.push(genre)
        end for
    end for
    if choices.count() = 1
        m.note = "Esta página no contiene géneros disponibles para filtrar."
        drawScreen()
        return
    end if
    choices.push("Cancelar")
    m.genreChoices = choices
    dialog = CreateObject("roSGNode","StandardMessageDialog")
    dialog.title = "Filtrar por género · Página actual"
    dialog.message = "El filtro se aplica a los títulos cargados en esta página."
    dialog.buttons = choices
    dialog.observeField("buttonSelected","genreFilterChosen")
    dialog.observeField("wasClosed","genreFilterDismissed")
    m.dialogBox = dialog
    m.dialogPurpose = "genre"
    m.top.dialog = dialog
end sub

sub genreFilterChosen(event as object)
    if m.dialogBox = invalid or not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    choice = event.getData()
    if choice < 0 or choice >= m.genreChoices.count() then return
    selected = m.genreChoices[choice]
    m.genreChoices = []
    releaseDialog()
    if selected <> "Cancelar"
        m.genreFilter = selected
        applyGenreFilter()
        m.note = ""
    end if
    m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
end sub

sub genreFilterDismissed(event as object)
    if m.dialogBox = invalid or event.getData() <> true then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
end sub

sub openSearch()
    cancelRequest()
    if m.kind <> "series" then m.kind = "movie"
    m.view = "browse"
    m.zone = "nav"
    m.nav = 4
    drawScreen()
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    title = "Buscar películas"
    if m.kind = "series" then title = "Buscar series"
    dialog.title = title
    dialog.text = m.query
    dialog.buttons = ["Buscar","Cancelar"]
    dialog.observeField("buttonSelected","searchChosen")
    dialog.observeField("wasClosed","searchDismissed")
    m.dialogBox = dialog
    m.dialogPurpose = "search"
    m.top.dialog = dialog
end sub

sub openLiveSearch()
    if m.view <> "live" then return
    if m.previewTimer <> invalid then m.previewTimer.control = "stop"
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    dialog.title = "Buscar canales"
    dialog.text = m.liveQuery
    dialog.buttons = ["Buscar","Cancelar"]
    dialog.observeField("buttonSelected","liveSearchChosen")
    dialog.observeField("wasClosed","liveSearchDismissed")
    m.dialogBox = dialog
    m.dialogPurpose = "live-search"
    m.top.dialog = dialog
end sub

sub liveSearchChosen(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    text = left(m.dialogBox.text.trim(),80)
    choice = event.getData()
    releaseDialog()
    if m.view <> "live" then return
    m.liveSearchCursor = 0
    m.zone = "live-search"
    if choice = 0
        m.liveQuery = text
        m.note = ""
        refreshLiveList(false)
        if m.channels.count() > 0 then m.zone = "live"
    else if not m.livePreviewOpen and m.channels.count() > 0
        scheduleLivePreview()
    end if
    drawScreen()
    m.top.setFocus(true)
end sub

sub liveSearchDismissed(event as object)
    if m.dialogBox = invalid or event.getData() <> true then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    if m.view <> "live" then return
    m.zone = "live-search"
    m.liveSearchCursor = 0
    if not m.livePreviewOpen and m.channels.count() > 0 then scheduleLivePreview()
    drawScreen()
    m.top.setFocus(true)
end sub

sub clearLiveSearch()
    m.liveQuery = ""
    m.liveSearchCursor = 0
    m.zone = "live-search"
    m.note = ""
    refreshLiveList(false)
    drawScreen()
end sub

sub releaseDialog(alreadyClosed = false as boolean)
    if m.dialogBox = invalid then return
    dialog = m.dialogBox
    m.dialogBox = invalid
    m.dialogPurpose = ""
    if m.top.dialog <> invalid
        if m.top.dialog.isSameNode(dialog) then m.top.dialog = invalid
    end if
    dialog.unobserveField("buttonSelected")
    dialog.unobserveField("wasClosed")
    ' A wasClosed callback means Roku has already dismissed the dialog.
    ' Do not issue close=true again from inside that callback.
    if not alreadyClosed then dialog.close = true
end sub

sub dismissDialogFromBack()
    if m.dialogBox = invalid then return
    purpose = m.dialogPurpose
    releaseDialog()
    if purpose = "search"
        if m.titles.count() = 0 then loadBrowsePage(0)
        m.zone = "grid"
        drawScreen()
        m.top.setFocus(true)
    else if purpose = "compat"
        openSettings()
    else if purpose = "profile"
        m.view = "profiles"
        m.zone = "profiles"
        drawScreen()
        m.top.setFocus(true)
    else if purpose = "live-search"
        m.zone = "live-search"
        m.liveSearchCursor = 0
        if not m.livePreviewOpen and m.channels.count() > 0 then scheduleLivePreview()
        drawScreen()
        m.top.setFocus(true)
    else if purpose = "genre"
        m.zone = "grid"
        drawScreen()
        m.top.setFocus(true)
    end if
end sub

sub searchChosen(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    query = left(m.dialogBox.text.trim(),120)
    choice = event.getData()
    releaseDialog()
    if choice = 0
        m.query = query
        m.cursor = 0
        loadBrowsePage(0)
    else if m.titles.count() = 0
        loadBrowsePage(0)
    end if
    m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
end sub

sub searchDismissed(event as object)
    if m.dialogBox = invalid or event.getData() <> true then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    if m.titles.count() = 0 then loadBrowsePage(0)
    m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
end sub

sub goHome()
    stopLivePreview()
    if m.noteTimer <> invalid then m.noteTimer.control = "stop"
    cancelRequest()
    m.note = ""
    m.view = "home"
    m.nav = 0
    m.zone = "hero"
    m.hero = 0
    drawScreen()
    m.top.setFocus(true)
end sub

sub returnOneStep()
    m.note = ""
    if m.view = "credits" or m.view = "hd-source" or m.view = "appearance" or m.view = "profiles"
        openSettings()
        return
    end if
    if m.view = "detail"
        if m.detailOrigin = "library"
            m.view = "library"
            m.zone = "library"
        else if m.detailOrigin = "episodes"
            m.view = "episodes"
            m.zone = "episodes"
        else if m.detailOrigin = "browse"
            m.view = "browse"
            m.zone = "grid"
        else
            goHome()
            return
        end if
    else if m.view = "episodes"
        m.detail = m.series
        m.detailOrigin = m.seriesOrigin
        m.view = "detail"
        m.zone = "action"
        m.action = 0
    else
        goHome()
        return
    end if
    drawScreen()
end sub

sub activateNav()
    if m.nav <> 3 then stopLivePreview()
    if m.nav = 0 then goHome()
    if m.nav = 1 then openCatalog("movie")
    if m.nav = 2 then openCatalog("series")
    if m.nav = 3
        m.view = "live"
        selectLiveFilter(m.liveFilter)
    end if
    if m.nav = 4 then openSearch()
    if m.nav = 5 then openLibrary("list")
    if m.nav = 6 then openLibrary("history")
    if m.nav = 7 then openSettings()
    if m.nav = 8 then openProfiles()
end sub

sub selectLiveFilter(filter as integer)
    cancelRequest()
    stopLivePreview()
    m.liveFilter = orbitInteger(filter,3)
    m.liveFilterCursor = m.liveFilter
    m.liveCursor = 0
    m.zone = "live-filters"
    m.note = ""
    refreshLiveList(false)
    if (m.liveFilter = 2 or m.liveFilter = 3) and not m.latamLoaded
        if m.liveFilter = 2 or m.liveFavorites.count() > 0 then fetch({operation:"latam"})
    else if (m.liveFilter = 0 or m.liveFilter = 1) and m.liveLoadedCountry <> m.countryCode
        fetch({operation:"country"})
    end if
    drawScreen()
end sub

sub refreshLiveList(preserve as boolean)
    selected = ""
    selectedUrl = ""
    if preserve and m.liveCursor >= 0 and m.liveCursor < m.channels.count()
        selected = rpLiveFavoriteKey(m.channels[m.liveCursor])
        selectedUrl = m.channels[m.liveCursor].url
    end if
    source = m.countryChannels
    if m.liveFilter = 2 then source = m.latamChannels
    if m.liveFilter = 3 then source = rpLiveMergeChannels(m.countryChannels,m.latamChannels)
    merged = rpLiveMergeChannels(source,rpRealityItems())
    merged = rpLivePopularityOrder(merged)
    m.channels = rpLiveVisibleChannels(merged,m.liveFavorites,m.liveFilter,m.countryCode)
    m.channels = rpLiveSearchChannels(m.channels,m.liveQuery)
    m.liveCursor = 0
    if preserve and selected <> ""
        for i = 0 to m.channels.count()-1
            if rpLiveFavoriteKey(m.channels[i]) = selected and m.channels[i].url = selectedUrl
                m.liveCursor = i
                exit for
            end if
        end for
    end if
    if m.channels.count() > 0
        nextItem = m.channels[m.liveCursor]
        if m.livePreviewItem = invalid
            scheduleLivePreview()
        else if m.livePreviewItem.id <> nextItem.id or m.livePreviewItem.url <> nextItem.url
            scheduleLivePreview()
        end if
    else
        stopLivePreview()
    end if
end sub

sub stopLivePreview(clearItem = true as boolean)
    if m.previewTimer <> invalid then m.previewTimer.control = "stop"
    m.livePreviewRequestTag = ""
    if m.livePreviewOpen = true
        m.livePreviewOpen = false
        m.player.callFunc("closePlayback")
    end if
    m.liveFullscreen = false
    m.livePreviewKey = ""
    if clearItem
        m.livePreviewItem = invalid
        m.livePreviewStatus = "Selecciona un canal"
    end if
end sub

sub scheduleLivePreview()
    stopLivePreview()
    if m.liveCursor < 0 or m.liveCursor >= m.channels.count() then return
    m.livePreviewItem = m.channels[m.liveCursor]
    m.livePreviewStatus = "Preparando vista previa…"
    if not rpLivePlayable(m.livePreviewItem)
        m.livePreviewStatus = orbitText(m.livePreviewItem.availabilityLabel,100)
        if m.livePreviewStatus = "" then m.livePreviewStatus = "Sin señal disponible"
        return
    end if
    if m.previewTimer <> invalid then m.previewTimer.control = "start"
end sub

sub startLivePreview()
    if m.view <> "live" or m.liveFullscreen then return
    if m.dialogBox <> invalid then return
    if m.liveCursor < 0 or m.liveCursor >= m.channels.count() then return
    channel = m.channels[m.liveCursor]
    m.livePreviewItem = channel
    if not rpLivePlayable(channel) then return
    key = rpLiveFavoriteKey(channel)+"|"+channel.url
    if m.livePreviewOpen and m.livePreviewKey = key then return
    stopLivePreview(false)
    m.livePreviewItem = channel
    m.livePreviewKey = key
    m.livePreviewStatus = "Cargando señal…"
    m.livePreviewOpen = true
    m.liveRequestSequence++
    m.livePreviewRequestTag = m.liveRequestSequence.toStr()
    m.player.allowPreviewReturn = true
    m.player.theme = m.theme
    m.player.previewRect = [294,206,1016,572]
    m.player.presentation = "preview"
    descriptor = {title:channel.title,url:channel.url,streamFormat:channel.streamFormat,kind:"live",itemId:channel.id,requestId:m.livePreviewRequestTag,provider:orbitText(channel.provider,32),direct:true}
    if channel.doesExist("mediaHeaders") then descriptor.mediaHeaders = channel.mediaHeaders
    m.lastPlaybackProgress = invalid
    m.player.request = descriptor
    m.canvas.visible = true
    m.top.setFocus(true)
    drawScreen()
end sub

sub playLiveSelection()
    if m.liveCursor < 0 or m.liveCursor >= m.channels.count() then return
    channel = m.channels[m.liveCursor]
    if not rpLivePlayable(channel)
        m.note = orbitText(channel.availabilityMessage,320)
        if m.note = "" then m.note = "No hay una señal disponible para este programa."
        drawScreen()
        return
    end if
    if m.livePreviewStatus = "La señal no respondió. OK para reintentar." then stopLivePreview(false)
    if not m.livePreviewOpen
        startLivePreview()
    end if
    m.liveFullscreen = true
    m.player.presentation = "fullscreen"
end sub

sub openAppearance()
    m.view = "appearance"
    m.zone = "appearance"
    m.themeCursor = 0
    if m.theme = "classic" then m.themeCursor = 1
    drawScreen()
end sub

sub saveAppearance()
    theme = "glass"
    if m.themeCursor = 1 then theme = "classic"
    if rpSaveTheme(theme)
        m.theme = theme
        openSettings()
    else
        m.note = "No se pudo guardar la apariencia. Intenta otra vez."
        drawScreen()
    end if
end sub

sub livePreviewReturned(event as object)
    if event.getData() <> true or m.view <> "live" then return
    m.liveFullscreen = false
    m.zone = "live"
    drawScreen()
    if m.dialogBox = invalid then m.top.setFocus(true)
end sub

sub livePreviewProgress(event as object)
    if m.view <> "live" or not m.livePreviewOpen or m.livePreviewItem = invalid then return
    sample = event.getData()
    if type(sample) <> "roAssociativeArray" then return
    if sample.itemId <> m.livePreviewItem.id then return
    if sample.requestId <> m.livePreviewRequestTag then return
    status = "Cargando señal…"
    if sample.state = "playing" then status = "En vivo"
    if sample.state = "paused" then status = "En pausa"
    if sample.failed = true or sample.state = "error" then status = "La señal no respondió. OK para reintentar."
    if status <> m.livePreviewStatus
        m.livePreviewStatus = status
        if not m.liveFullscreen then drawScreen()
    end if
end sub

sub livePreviewClosed(event as object)
    if m.view <> "live" or not m.livePreviewOpen then return
    sample = event.getData()
    if type(sample) <> "roAssociativeArray" then return
    if sample.requestId <> m.livePreviewRequestTag then return
    m.livePreviewOpen = false
    m.liveFullscreen = false
    m.livePreviewRequestTag = ""
    m.livePreviewStatus = "La señal terminó. OK para volver a abrirla."
    m.player.visible = false
    drawScreen()
    if m.dialogBox = invalid then m.top.setFocus(true)
end sub

sub toggleLiveFavorite()
    if m.liveCursor < 0 or m.liveCursor >= m.channels.count() then return
    result = rpLiveFavoritesToggle(m.liveFavorites,m.channels[m.liveCursor])
    if not result.ok
        m.note = result.message
    else if not rpLiveSaveFavorites(result.keys)
        m.note = "No se pudo guardar el favorito. Intenta otra vez."
    else
        m.liveFavorites = result.keys
        m.note = "Canal quitado de favoritos."
        if result.added then m.note = "Canal guardado en favoritos. Aparecerá al principio."
        refreshLiveList(true)
    end if
    if m.noteTimer <> invalid then m.noteTimer.control = "start"
    drawScreen()
end sub

sub liveNoticeElapsed()
    if m.view <> "live" then return
    m.note = ""
    if not m.liveFullscreen then drawScreen()
end sub


sub beginSetup(fromSettings as boolean, countryOnly as boolean)
    cancelRequest()
    m.setupFromSettings = fromSettings
    m.setupCountryOnly = countryOnly
    m.setupTv = 0
    if m.catalogMode = "hevc" then m.setupTv = 1
    m.setupCountry = 0
    choices = orbitCountries()
    for i = 0 to choices.count()-1
        if choices[i].code = m.countryCode then m.setupCountry = i
    end for
    m.view = "setup-tv"
    m.zone = "setup"
    if countryOnly
        m.view = "setup-country"
        m.zone = "country"
    end if
    drawScreen()
end sub

sub commitSetup()
    stopLivePreview()
    choices = orbitCountries()
    if m.setupCountry < 0 or m.setupCountry >= choices.count() then return
    mode = "hd"
    if m.setupTv = 1 then mode = "hevc"
    code = choices[m.setupCountry].code
    saved = rpSavePreferences(mode,code)
    cancelRequest()
    cancelHomeRequests()
    m.catalogMode = mode
    m.countryCode = code
    m.configured = saved
    m.channels = []
    m.countryChannels = []
    m.liveLoadedCountry = ""
    m.liveFilter = 0
    m.liveFilterCursor = 0
    m.liveQuery = ""
    m.liveSearchCursor = 0
    m.liveCursor = 0
    m.titles = []
    m.query = ""
    m.kind = "movie"
    m.cover = 0
    m.seriesCover = 0
    m.hero = 0
    m.features = []
    m.homeSeries = []
    m.view = "home"
    m.zone = "hero"
    m.nav = 0
    m.note = ""
    if not saved then m.note = "La selección funciona en esta sesión, pero no se pudo guardar en la Roku."
    refreshHome()
    drawScreen()
    m.top.setFocus(true)
end sub

sub openLibrary(mode as string)
    stopLivePreview()
    cancelRequest()
    m.libraryMode = mode
    m.libraryItems = []
    for each record in m.watchState
        if type(record) = "roAssociativeArray"
            if mode = "history" or record.listed = true then m.libraryItems.push(record)
        end if
    end for
    m.libraryCursor = 0
    m.view = "library"
    m.zone = "library"
    drawScreen()
end sub

sub openProfiles()
    cancelRequest()
    m.view = "profiles"
    m.zone = "profiles"
    m.nav = 8
    m.profileCursor = 0
    if m.profileId = "p2" then m.profileCursor = 1
    if m.profileId = "p3" then m.profileCursor = 2
    if m.profileId = "p4" then m.profileCursor = 3
    m.note = ""
    drawScreen()
end sub

sub switchProfile(index as integer)
    ids = ["p1","p2","p3","p4"]
    if index < 0 or index >= ids.count() then return
    selected = ids[index]
    if selected = m.profileId
        m.note = "Este perfil ya está activo."
        drawScreen()
        return
    end if
    if not rpSaveProfileId(selected)
        m.note = "No se pudo guardar el perfil. Inténtalo de nuevo."
        drawScreen()
        return
    end if
    m.profileId = selected
    m.watchState = rpWatchLoad(m.profileId)
    m.continueItems = rpWatchContinue(m.watchState)
    m.lastPlaybackProgress = invalid
    m.note = "Perfil cambiado: " + rpProfileName(m.profileId)
    goHome()
end sub

sub openProfileEditor(index as integer)
    ids = ["p1","p2","p3","p4"]
    if index < 0 or index >= ids.count() then return
    m.profileEditId = ids[index]
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    dialog.title = "Nombre del perfil"
    dialog.text = rpProfileName(m.profileEditId)
    dialog.buttons = ["Guardar","Cancelar"]
    dialog.observeField("buttonSelected","profileNameChosen")
    dialog.observeField("wasClosed","profileNameDismissed")
    m.dialogBox = dialog
    m.dialogPurpose = "profile"
    m.top.dialog = dialog
end sub

sub profileNameChosen(event as object)
    if m.dialogBox = invalid or not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    value = left(m.dialogBox.text.trim(),24)
    choice = event.getData()
    releaseDialog()
    if choice = 0
        if not rpSaveProfileName(m.profileEditId,value)
            m.note = "No se pudo guardar el nombre. Usa entre 1 y 24 caracteres."
        else
            m.note = "Nombre del perfil actualizado."
        end if
    end if
    m.view = "profiles"
    m.zone = "profiles"
    drawScreen()
    m.top.setFocus(true)
end sub

sub profileNameDismissed(event as object)
    if m.dialogBox = invalid or event.getData() <> true then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    m.view = "profiles"
    m.zone = "profiles"
    drawScreen()
    m.top.setFocus(true)
end sub

sub cycleProfileAvatar(index as integer)
    ids = ["p1","p2","p3","p4"]
    if index < 0 or index >= ids.count() then return
    nextAvatar = (rpProfileAvatar(ids[index])+1) mod 6
    if rpSaveProfileAvatar(ids[index],nextAvatar)
        m.note = "Imagen del perfil actualizada."
    else
        m.note = "No se pudo guardar la imagen del perfil."
    end if
    drawScreen()
end sub

sub removeLibraryItem()
    if m.libraryCursor < 0 or m.libraryCursor >= m.libraryItems.count() then return
    selected = m.libraryItems[m.libraryCursor]
    idx = rpWatchIndex(m.watchState,selected.id)
    if idx >= 0 then m.watchState.delete(idx)
    rpWatchSave(m.watchState,m.profileId)
    m.continueItems = rpWatchContinue(m.watchState)
    openLibrary(m.libraryMode)
    m.note = "Título eliminado de este perfil."
    drawScreen()
end sub

sub openSettings()
    cancelRequest()
    m.view = "settings"
    m.zone = "settings"
    m.nav = 7
    m.settingsCursor = 0
    m.note = ""
    drawScreen()
    m.top.setFocus(true)
end sub

sub openCompatSettings()
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = "Servidor de compatibilidad (PC)"
    dialog.text = m.compatBase
    dialog.buttons = ["Guardar", "Cancelar"]
    dialog.observeField("buttonSelected", "compatSettingsChosen")
    dialog.observeField("wasClosed", "compatSettingsDismissed")
    m.dialogBox = dialog
    m.dialogPurpose = "compat"
    m.top.dialog = dialog
end sub

sub compatSettingsChosen(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    value = m.dialogBox.text.trim()
    choice = event.getData()
    releaseDialog()
    openSettings()
    if choice = 0
        if rpSaveCompatBase(value)
            m.compatBase = value
            m.note = "Servidor de compatibilidad guardado."
        else
            m.note = "Dirección no válida. Usa http://IP:PUERTO, por ejemplo http://192.168.1.17:8099."
        end if
    end if
    drawScreen()
end sub

sub compatSettingsDismissed(event as object)
    if m.dialogBox = invalid or event.getData() <> true then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    openSettings()
end sub

sub openCredits()
    m.creditsPages = []
    text = ReadAsciiFile("pkg:/CREDITS-HD.txt")
    page = ""
    for each line in text.split(chr(10))
        if len(page)+len(line) > 1250
            m.creditsPages.push(page)
            page = ""
        end if
        page += line+chr(10)
    end for
    if page <> "" then m.creditsPages.push(page)
    if m.creditsPages.count() = 0 then m.creditsPages.push("Biblioteca HD: Blender Studio y NASA. Consulta los créditos del paquete.")
    m.creditsPage = 0
    m.view = "credits"
    m.zone = "credits"
    drawScreen()
end sub

sub heroRotationTick(event as object)
    if m.view <> "home" then return
    if type(m.features) <> "roArray" or m.features.count() < 2 then return
    m.heroFeature = (m.heroFeature + 1) mod m.features.count()
    drawScreen()
end sub

sub changeHero(direction as integer)
    if type(m.features) <> "roArray" or m.features.count() < 2 then return
    m.heroFeature = m.heroFeature + direction
    if m.heroFeature < 0 then m.heroFeature = m.features.count()-1
    if m.heroFeature >= m.features.count() then m.heroFeature = 0
    if m.heroRotation <> invalid then m.heroRotation.control = "stop": m.heroRotation.control = "start"
    drawScreen()
end sub

sub cancelHomeRequests()
    for each entry in m.homeJobs
        entry.node.unobserveField("result")
        entry.node.unobserveField("state")
        entry.node.cancelRequested = true
    end for
    m.homeJobs = []
    m.homeLoading = false
end sub

sub refreshHome()
    cancelHomeRequests()
    if m.catalogMode = "hd" and not usesOnlineHd()
        m.features = orbitUniqueCatalogItems(m.hdLibrary.movies)
        m.homeSeries = orbitUniqueCatalogItems(m.hdLibrary.series)
        return
    end if
    ' Reuse the last successful home response for five minutes. This avoids
    ' duplicate network work when users leave and quickly return to Home.
    cacheKey = m.catalogMode + "|" + m.hdProvider
    if type(m.homeCache) = "roAssociativeArray" and m.homeCache.doesExist(cacheKey)
        cached = m.homeCache[cacheKey]
        if type(cached) = "roAssociativeArray" and cached.doesExist("hasMovies") and cached.doesExist("hasSeries") and cached.hasMovies and cached.hasSeries
            age = cached.clock.totalMilliseconds()
            if age >= 0 and age < 300000
                m.features = cached.movies
                m.homeSeries = cached.series
                if m.heroFeature >= m.features.count() then m.heroFeature = 0
                m.homeLoading = false
                return
            end if
        end if
    end if
    ' Start a fresh pair so a partial refresh can never combine new movies
    ' with stale series (or vice versa) and be marked as a valid cache.
    m.homeCache[cacheKey] = {movies: [], series: [], hasMovies: false, hasSeries: false, clock: CreateObject("roTimespan")}
    m.homeLoading = true
    for each kind in ["movie","series"]
        taskName = "CatalogTask"
        if usesOnlineHd() then taskName = "HdCatalogTask"
        task = CreateObject("roSGNode",taskName)
        if usesOnlineHd() then task.provider = m.hdProvider
        request = CreateObject("roDeviceInfo").getRandomUUID()
        task.operation = "catalog"
        task.kind = kind
        task.requestId = request
        task.observeField("result","homeFetched")
        task.observeField("state","homeStopped")
        m.homeJobs.push({node:task,request:request,kind:kind,mode:m.catalogMode,provider:m.hdProvider})
        task.control = "RUN"
    end for
end sub

sub homeFetched(event as object)
    answer = event.getData()
    if type(answer) <> "roAssociativeArray" then return
    for i = 0 to m.homeJobs.count()-1
        entry = m.homeJobs[i]
        if entry.node.isSameNode(event.getRoSGNode()) and answer.requestId = entry.request
            if entry.mode <> m.catalogMode then return
            if m.catalogMode = "hd" and entry.provider <> m.hdProvider then return
            if answer.ok
                if entry.kind = "movie"
                    m.features = orbitUniqueCatalogItems(answer.items)
                    if m.heroFeature >= m.features.count() then m.heroFeature = 0
                else
                    m.homeSeries = orbitUniqueCatalogItems(answer.items)
                end if
                cacheKey = entry.mode + "|" + entry.provider
                cached = {movies: [], series: [], hasMovies: false, hasSeries: false, clock: CreateObject("roTimespan")}
                if m.homeCache.doesExist(cacheKey)
                    previousCache = m.homeCache[cacheKey]
                    if type(previousCache) = "roAssociativeArray" then cached = previousCache
                end if
                if entry.kind = "movie"
                    cached.movies = orbitUniqueCatalogItems(answer.items)
                    cached.hasMovies = true
                else
                    cached.series = orbitUniqueCatalogItems(answer.items)
                    cached.hasSeries = true
                end if
                if cached.hasMovies and cached.hasSeries
                    cached.clock.mark()
                    m.homeCache[cacheKey] = cached
                else
                    m.homeCache[cacheKey] = cached
                end if
            else
                m.note = "No se pudo actualizar una de las filas. Puedes explorar desde el menú o volver a intentar."
            end if
            entry.node.unobserveField("result")
            entry.node.unobserveField("state")
            m.homeJobs.delete(i)
            exit for
        end if
    end for
    m.homeLoading = m.homeJobs.count() > 0
    if m.view = "home" then drawScreen()
end sub

sub homeStopped(event as object)
    if event.getData() <> "STOP" then return
    for i = 0 to m.homeJobs.count()-1
        entry = m.homeJobs[i]
        if entry.node.isSameNode(event.getRoSGNode())
            if type(entry.node.result) = "roAssociativeArray" then return
            entry.node.unobserveField("result")
            entry.node.unobserveField("state")
            m.homeJobs.delete(i)
            m.note = "No se pudo actualizar el catálogo. Puedes explorar desde el menú."
            exit for
        end if
    end for
    m.homeLoading = m.homeJobs.count() > 0
    if m.view = "home" then drawScreen()
end sub

sub loadBrowsePage(offset as integer, last = false as boolean)
    if m.catalogMode = "hd" and not usesOnlineHd()
        cancelRequest()
        m.pageTitles = orbitUniqueCatalogItems(rpHdCatalog(m.kind,m.query))
        applyGenreFilter()
        m.offset = 0
        m.nextOffset = 0
        m.more = false
        m.cursor = 0
        m.zone = "grid"
        drawScreen()
    else
        fetch({operation:"catalog",offset:offset,last:last})
    end if
end sub

function detailActionCount() as integer
    if m.detail = invalid then return 0
    if m.detail.kind = "series" or m.catalogMode = "hd" then return 2
    if m.capabilities.hevcKnown and not m.capabilities.canDecodeHevc then return 2
    return 3
end function

sub playDetail()
    if m.detail = invalid then return
    m.playbackMode = "direct"
    if usesOnlineHd() or rpIsOnlineHdItem(m.detail)
        fetch({operation:"resolve",item:m.detail})
    else if m.catalogMode = "hd"
        if m.detail.doesExist("directUrl") and m.detail.directUrl <> ""
            launchVideo(m.detail,m.detail.directUrl,m.detail.streamFormat)
        else
            m.note = "Este título no tiene una fuente disponible."
            drawScreen()
        end if
    else if m.capabilities.hevcKnown and not m.capabilities.canDecodeHevc
        m.note = "Esta Roku no anunció compatibilidad con este catálogo. Puedes elegir HD en Configuración."
        drawScreen()
    else
        fetch({operation:"resolve",item:m.detail})
    end if
end sub

sub enterEpisodes()
    if m.detail.seasons.count() = 0
        if usesOnlineHd() or rpIsOnlineHdItem(m.detail)
            fetch({operation:"meta",item:m.detail})
            return
        end if
        m.note = "No se encontraron episodios para esta serie."
    else
        m.series = m.detail
        m.seriesOrigin = m.detailOrigin
        m.season = 0
        if m.series.seasons[0].number = 0 and m.series.seasons.count() > 1 then m.season = 1
        m.episode = 0
        m.view = "episodes"
        m.zone = "episodes"
        loadEpisodeSeason()
    end if
    drawScreen()
end sub

function rpIsOnlineHdItem(item as dynamic) as boolean
    if type(item) <> "roAssociativeArray" then return false
    provider = ""
    if item.doesExist("provider") then provider = lcase(orbitText(item.provider,32))
    if provider = "lamovie" or provider = "allcalidad" or provider = "cinehax" or provider = "seriesmetro" or provider = "cinecalidad" then return true
    id = ""
    if item.doesExist("id") then id = orbitText(item.id,180)
    prefixes = ["hdo-lamovie-","hdo-allcalidad-","hdo-cinehax-","hdo-seriesmetro-","hdo-cinecalidad-"]
    for each prefix in prefixes
        if left(id,len(prefix)) = prefix then return true
    end for
    return false
end function

function usesOnlineHd() as boolean
    source = orbitText(m.hdProvider,32)
    return m.catalogMode = "hd" and (source = "all" or source = "lamovie" or source = "allcalidad" or source = "cinehax" or source = "seriesmetro" or source = "cinecalidad")
end function

function hdProviderName(value = invalid as dynamic) as string
    source = orbitText(value,32)
    if source = "" then source = orbitText(m.hdProvider,32)
    if source = "all" then return "Todas las fuentes"
    if source = "allcalidad" then return "AllCalidad"
    if source = "cinehax" then return "CineHax"
    if source = "seriesmetro" then return "SeriesMetro"
    if source = "cinecalidad" then return "CineCalidad"
    if source = "open" then return "Cortos y documentales"
    return "LaMovie"
end function

function hdProviderChoices() as object
    return ["all","lamovie","allcalidad","cinehax","seriesmetro","cinecalidad","open"]
end function

sub openHdSource()
    cancelRequest()
    m.hdSourceCursor = 0
    choices = hdProviderChoices()
    for i = 0 to choices.count()-1
        if choices[i] = m.hdProvider then m.hdSourceCursor = i
    end for
    m.view = "hd-source"
    m.zone = "hd-source"
    drawScreen()
end sub

sub commitHdSource()
    choices = hdProviderChoices()
    if m.hdSourceCursor < 0 or m.hdSourceCursor >= choices.count() then return
    source = choices[m.hdSourceCursor]
    saved = rpSaveHdProvider(source)
    cancelRequest()
    if m.catalogMode = "hd" then cancelHomeRequests()
    m.hdProvider = source
    m.titles = []
    m.query = ""
    m.offset = 0
    m.cursor = 0
    m.cover = 0
    m.seriesCover = 0
    m.kind = "movie"
    m.detail = invalid
    m.series = invalid
    if m.catalogMode = "hd"
        m.features = []
        m.homeSeries = []
        m.nav = 0
        m.view = "home"
        m.zone = "hero"
        m.hero = 0
        refreshHome()
        drawScreen()
    else
        openSettings()
    end if
    if not saved
        m.note = "La fuente funciona en esta sesión, pero no se pudo guardar en la Roku."
        drawScreen()
    end if
end sub

sub loadEpisodeSeason()
    if not usesOnlineHd() or m.series = invalid then return
    if m.season < 0 or m.season >= m.series.seasons.count() then return
    season = m.series.seasons[m.season]
    if season.loaded = true then return
    fetch({operation:"episodes",item:m.series,season:season.number})
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if key = "home" then return false
    if not press then return true
    if m.view = "player" then return false
    if m.dialogBox <> invalid
        ' Let StandardKeyboardDialog own Back. Manually closing it here races
        ' the platform dialog dismissal and can leave the scene needing a second Back.
        ' wasClosed observers perform the single cleanup and focus restoration.
        return false
    end if
    if m.view = "setup-tv"
        if key = "left" or key = "up" then m.setupTv = 0
        if key = "right" or key = "down" then m.setupTv = 1
        if key = "OK"
            m.view = "setup-country"
            m.zone = "country"
            drawScreen()
        else if key = "back" and m.setupFromSettings
            openSettings()
        else
            paintFocus()
        end if
        return true
    else if m.view = "setup-country"
        if key = "up" and m.setupCountry > 0 then m.setupCountry--
        if key = "down" and m.setupCountry+1 < orbitCountries().count() then m.setupCountry++
        if key = "OK" then commitSetup(): return true
        if key = "back"
            if m.setupCountryOnly and m.setupFromSettings
                openSettings()
                return true
            end if
            m.view = "setup-tv"
            m.zone = "setup"
        end if
        drawScreen()
        return true
    end if
    if m.nextEpisode <> invalid
        if key = "OK"
            item = m.nextEpisode
            m.nextEpisode = invalid
            m.nextEpisodeTimer.control = "stop"
            openDetails(item,"episodes",true)
            return true
        else if key = "back"
            cancelNextEpisode()
            return true
        end if
    end if
    if key = "back"
        if m.busy
            cancelRequest()
            m.autoplay = false
            drawScreen()
        else if m.view = "live" and (m.zone = "live" or m.zone = "live-actions" or m.zone = "live-search")
            m.zone = "live-filters"
            drawScreen()
        else
            returnOneStep()
        end if
        return true
    end if
    if m.view = "credits"
        if key = "down" and m.creditsPage+1 < m.creditsPages.count() then m.creditsPage++
        if key = "up" and m.creditsPage > 0 then m.creditsPage--
        drawScreen()
        return true
    end if
    if m.view = "appearance"
        if key = "left" then m.themeCursor = 0
        if key = "right" then m.themeCursor = 1
        if key = "OK" then saveAppearance(): return true
        paintFocus()
        return true
    end if
    if m.view = "hd-source"
        if key = "up" and m.hdSourceCursor > 0 then m.hdSourceCursor--
        if key = "down" and m.hdSourceCursor+1 < hdProviderChoices().count() then m.hdSourceCursor++
        if key = "OK" then commitHdSource(): return true
        paintFocus()
        return true
    end if
    if key = "options" or key = "info"
        if m.view = "library" and key = "options" then removeLibraryItem(): return true
        if m.view = "profiles" and key = "options" then openProfileEditor(m.profileCursor): return true
        if m.view = "browse" and key = "options" then openGenreFilter(): return true
        if m.view = "live" then toggleLiveFavorite(): return true
        if m.view = "profiles" and (key = "play" or key = "playpause" or key = "pause") then cycleProfileAvatar(m.profileCursor): return true
        if m.view = "detail"
            if key = "options" then toggleCurrentWatch("watched") else toggleCurrentWatch("listed")
            return true
        end if
        if m.view = "episodes" and m.series <> invalid
            if m.episode < m.series.seasons[m.season].episodes.count()
                m.detail = m.series.seasons[m.season].episodes[m.episode]
                if key = "options" then toggleCurrentWatch("watched") else toggleCurrentWatch("listed")
                return true
            end if
        end if
        openSearch()
        return true
    end if
    if m.busy and m.view <> "live" then return true
    if m.zone = "nav"
        if key = "left" and m.nav > 0 then m.nav--
        if key = "right" and m.nav < 8 then m.nav++
        if key = "OK" then activateNav(): return true
        if key = "down" or (key = "right" and m.nav = 8)
            if m.view = "home" then m.zone = "hero"
            if m.view = "library" then m.zone = "library"
            if m.view = "browse" then m.zone = "grid"
            if m.view = "live" then m.zone = "live-filters"
            if m.view = "detail" then m.zone = "action"
            if m.view = "episodes" then m.zone = "episodes"
            if m.view = "settings" then m.zone = "settings"
            if m.view = "profiles" then m.zone = "profiles"
        end if
        drawScreen()
        return true
    end if
    if m.view = "profiles"
        if key = "left"
            if m.profileCursor mod 2 = 1 then m.profileCursor-- else m.zone = "nav"
        end if
        if key = "right" and m.profileCursor mod 2 = 0 and m.profileCursor < 3 then m.profileCursor++
        if key = "up" and m.profileCursor > 1 then m.profileCursor -= 2
        if key = "down" and m.profileCursor < 2 then m.profileCursor += 2
        if key = "OK" then switchProfile(m.profileCursor): return true
        if key = "options" then openProfileEditor(m.profileCursor): return true
        if key = "play" or key = "playpause" or key = "pause" then cycleProfileAvatar(m.profileCursor): return true
        drawScreen()
        return true
    end if
    if m.view = "library"
        if key = "left" then m.zone = "nav": drawScreen(): return true
        if key = "up" and m.libraryCursor > 0 then m.libraryCursor--
        if key = "down" and m.libraryCursor+1 < m.libraryItems.count() then m.libraryCursor++
        if key = "OK" and m.libraryItems.count() > 0
            record = m.libraryItems[m.libraryCursor]
            selected = {id:record.id,title:record.title,kind:record.kind,poster:record.poster,background:record.background,year:record.year,provider:orbitText(record.provider,32),imdbId:orbitText(record.imdbId,180)}
            if record.doesExist("season") then selected.season = record.season
            if record.doesExist("episode") then selected.episode = record.episode
            if record.doesExist("seriesTitle") then selected.seriesTitle = record.seriesTitle
            openDetails(selected,"library")
            return true
        end if
        drawScreen()
        return true
    else if m.view = "settings"
        if key = "left" then m.zone = "nav": drawScreen(): return true
        if key = "up" and m.settingsCursor > 0 then m.settingsCursor--
        if key = "down" and m.settingsCursor < 6 then m.settingsCursor++
        if key = "OK"
            if m.settingsCursor = 0 then beginSetup(true,false)
            if m.settingsCursor = 1 then beginSetup(true,true)
            if m.settingsCursor = 2 then openHdSource()
            if m.settingsCursor = 3 then openCredits()
            if m.settingsCursor = 4 then openAppearance()
            if m.settingsCursor = 5 then openProfiles()
            if m.settingsCursor = 6 then openCompatSettings()
            return true
        end if
        paintFocus()
        return true
    else if m.view = "home"
        if m.zone = "hero"
            if key = "rewind" then changeHero(-1): return true
            if key = "fastforward" then changeHero(1): return true
            if key = "left"
                if m.hero = 0 then m.zone = "nav": drawScreen(): return true
                m.hero = 0
            end if
            if key = "right" and m.features.count() > 0 then m.hero = 1
            if key = "up" then m.zone = "nav": drawScreen(): return true
            if key = "down" then m.zone = "covers"
            if key = "OK"
                if m.features.count() > 0 then openDetails(m.features[m.heroFeature],"home",m.hero=0) else refreshHome(): drawScreen()
                return true
            end if
        else if m.zone = "covers"
            if key = "left"
                if m.cover > 0 then m.cover-- else m.zone = "nav": drawScreen(): return true
            end if
            if key = "right" and m.cover < 3 and m.cover+1 < m.features.count() then m.cover++
            if key = "up" then m.zone = "hero"
            if key = "down" and m.continueItems.count() > 0 then m.zone = "continue": m.cover = 0 else if key = "down" and m.homeSeries.count() > 0 then m.zone = "home-series"
            if key = "OK" and m.features.count() > 0 then openDetails(m.features[m.cover],"home"): return true
        else if m.zone = "continue"
            ' Diagnostic: confirm the remote-control event reaches the Continue Watching handler.
            print "[RokuPlus continue] key="; key; " cover="; m.cover; " count="; m.continueItems.count()
            if key = "left"
                if m.cover > 0 then m.cover-- else m.zone = "nav": drawScreen(): return true
            end if
            if key = "right" and m.cover < m.continueItems.count()-1 and m.cover < 2 then m.cover++
            if key = "up" then m.zone = "covers"
            if key = "OK" and m.cover < m.continueItems.count()
                saved = m.continueItems[m.cover]
                if type(saved) <> "roAssociativeArray" then return true
                savedId = "" : savedTitle = "" : savedKind = "movie"
                if saved.doesExist("id") then savedId = orbitText(saved.id,180)
                if saved.doesExist("title") then savedTitle = orbitText(saved.title,180)
                if saved.doesExist("kind") then savedKind = orbitText(saved.kind,20)
                savedImdb = ""
                if saved.doesExist("imdbId") then savedImdb = orbitImdb(saved.imdbId)
                if savedImdb = "" then savedImdb = orbitImdb(savedId)
                isOnlineSaved = rpIsOnlineHdItem(saved)
                onlineMode = usesOnlineHd()
                print "[RokuPlus continue] selected id="; savedId; " title="; savedTitle; " kind="; savedKind; " provider="; orbitText(saved.provider,32); " onlineItem="; isOnlineSaved; " onlineMode="; onlineMode; " imdb="; savedImdb
                if savedId = "" or savedTitle = "" or (not isOnlineSaved and not onlineMode and savedImdb = "")
                    print "[RokuPlus continue] rejected: idEmpty="; savedId = ""; " titleEmpty="; savedTitle = ""; " onlineItem="; isOnlineSaved; " onlineMode="; onlineMode; " imdbEmpty="; savedImdb = ""
                    m.note = "No se puede recuperar este título. El registro no contiene un identificador válido para esta fuente."
                    drawScreen()
                    return true
                end if
                resumeItem = {id:savedId,title:savedTitle,kind:savedKind,imdbId:savedImdb,poster:"",background:"",year:"",provider:""}
                if saved.doesExist("poster") then resumeItem.poster = orbitText(saved.poster,2048)
                if saved.doesExist("background") then resumeItem.background = orbitText(saved.background,2048)
                if saved.doesExist("year") then resumeItem.year = orbitText(saved.year,20)
                if saved.doesExist("provider") then resumeItem.provider = lcase(orbitText(saved.provider,32))
                if saved.doesExist("providerId")
                    if resumeItem.provider = "cinecalidad"
                        resumeItem.providerId = orbitText(saved.providerId,200)
                    else
                        resumeItem.providerId = orbitInteger(saved.providerId,999999999)
                    end if
                end if
                if saved.doesExist("providerSlug") then resumeItem.providerSlug = orbitText(saved.providerSlug,200)
                if saved.doesExist("providerTmdbId") then resumeItem.providerTmdbId = orbitText(saved.providerTmdbId,40)
                if saved.doesExist("providerKind") then resumeItem.providerKind = orbitText(saved.providerKind,16)
                ' Older records may contain provider="all" or no provider at all.
                ' The canonical HD id is the reliable source for the original provider.
                idProviders = ["lamovie","allcalidad","cinehax","seriesmetro","cinecalidad"]
                for each candidateProvider in idProviders
                    candidatePrefix = "hdo-"+candidateProvider+"-"
                    if left(savedId,len(candidatePrefix)) = candidatePrefix
                        resumeItem.provider = candidateProvider
                        candidateId = mid(savedId,len(candidatePrefix)+1)
                        if candidateProvider = "cinecalidad"
                            if candidateId <> "" then resumeItem.providerId = candidateId
                            if candidateId <> "" then resumeItem.providerSlug = candidateId
                        else
                            candidateNumber = orbitInteger(candidateId,999999999)
                            if candidateNumber > 0 and candidateNumber.toStr() = candidateId
                                resumeItem.providerId = candidateNumber
                            end if
                        end if
                        exit for
                    end if
                end for
                ' CineCalidad uses its slug for both providerId and providerSlug.
                if resumeItem.provider = "cinecalidad" and (not resumeItem.doesExist("providerId") or resumeItem.providerId = "")
                    resumeItem.providerId = resumeItem.providerSlug
                end if
                ' Restore legacy numeric IDs only when their exact provider prefix matches.
                if resumeItem.provider <> "cinecalidad" and (resumeItem.providerId = invalid or resumeItem.providerId = 0)
                    providerPrefix = "hdo-"+resumeItem.provider+"-"
                    if resumeItem.provider <> "" and left(savedId,len(providerPrefix)) = providerPrefix
                        providerNumberText = mid(savedId,len(providerPrefix)+1)
                        providerNumber = orbitInteger(providerNumberText,999999999)
                        if providerNumber > 0 and providerNumber.toStr() = providerNumberText
                            resumeItem.providerId = providerNumber
                        end if
                    end if
                end if
                if saved.doesExist("season") then resumeItem.season = orbitInteger(saved.season,999,0)
                if saved.doesExist("episode") then resumeItem.episode = orbitInteger(saved.episode,9999,0)
                if saved.doesExist("seriesTitle") then resumeItem.seriesTitle = orbitText(saved.seriesTitle,180)
                if resumeItem.kind = "episode" and (not resumeItem.doesExist("season") or not resumeItem.doesExist("episode") or resumeItem.episode < 1)
                    m.note = "Faltan los datos del episodio para reanudarlo."
                    drawScreen()
                    return true
                end if
                ' Re-enter the normal detail flow so online providers can restore
                ' their complete metadata (including seasons/episodes and source IDs)
                ' before resolve. Directly calling playDetail with this partial
                ' watch-history record can leave the resolver with incomplete data.
                print "[RokuPlus continue] accepted id="; resumeItem.id; " provider="; resumeItem.provider; " providerIdPresent="; resumeItem.doesExist("providerId"); " slugPresent="; resumeItem.doesExist("providerSlug")
                openDetails(resumeItem,"home",true)
                return true
            end if
        else if m.zone = "home-series"
            if key = "left"
                if m.seriesCover > 0 then m.seriesCover-- else m.zone = "nav": drawScreen(): return true
            end if
            if key = "right" and m.seriesCover < 2 and m.seriesCover+1 < m.homeSeries.count() then m.seriesCover++
            if key = "up" then m.zone = "covers"
            if key = "OK" and m.homeSeries.count() > 0 then openDetails(m.homeSeries[m.seriesCover],"home"): return true
        end if
    else if m.view = "browse"
        window = m.cursor \ 10
        if key = "left"
            if m.cursor mod 5 > 0 then m.cursor-- else m.zone = "nav": drawScreen(): return true
        end if
        if key = "right" and m.cursor mod 5 < 4 and m.cursor+1 < m.titles.count() then m.cursor++
        if key = "up" or key = "rewind"
            if m.cursor >= 5
                m.cursor -= 5
            else if m.offset > 0
                previous = m.offset-20
                if previous < 0 then previous = 0
                loadBrowsePage(previous,true)
                return true
            else
                m.zone = "nav"
                m.nav = 1
                if m.kind = "series" then m.nav = 2
                drawScreen()
                return true
            end if
        end if
        if key = "down" or key = "fastforward"
            if m.cursor+5 < m.titles.count()
                m.cursor += 5
            else if m.more
                loadBrowsePage(m.nextOffset)
                return true
            end if
        end if
        if key = "OK" and m.titles.count() > 0 then openDetails(m.titles[m.cursor],"browse"): return true
        if window <> m.cursor \ 10 then drawScreen(): return true
    else if m.view = "detail"
        if key = "left" then m.zone = "nav": drawScreen(): return true
        if key = "up"
            if m.action > 0 then m.action-- else m.zone = "nav": drawScreen(): return true
        end if
        finalAction = detailActionCount()-1
        if key = "down" and m.action < finalAction then m.action++
        if key = "OK"
            if m.action = finalAction
                returnOneStep()
            else if m.detail.kind = "series"
                enterEpisodes()
            else if m.action = 0
                playDetail()
            else
                prepareCompatible()
            end if
            return true
        end if
    else if m.view = "episodes"
        if key = "left"
            if m.season > 0
                m.season--
                m.episode = 0
                loadEpisodeSeason()
            else
                m.zone = "nav"
                drawScreen()
                return true
            end if
        end if
        if key = "right" and m.season+1 < m.series.seasons.count()
            m.season++
            m.episode = 0
            loadEpisodeSeason()
        end if
        items = m.series.seasons[m.season].episodes
        if key = "up" and m.episode > 0 then m.episode--
        if key = "down" and m.episode+1 < items.count() then m.episode++
        if key = "OK"
            if items.count() > 0 then openDetails(items[m.episode],"episodes") else loadEpisodeSeason()
            return true
        end if
        drawScreen()
        return true
    else if m.view = "live"
        if m.zone = "live-search"
            if key = "up" then m.zone = "live-filters": paintFocus(): return true
            if key = "down"
                if m.channels.count() > 0 then m.zone = "live"
                paintFocus()
                return true
            end if
            if key = "left"
                if m.liveSearchCursor > 0 then m.liveSearchCursor = 0 else m.zone = "nav"
            end if
            if key = "right" and m.liveQuery <> "" then m.liveSearchCursor = 1
            if key = "OK"
                if m.liveSearchCursor = 1 then clearLiveSearch() else openLiveSearch()
                return true
            end if
            paintFocus()
            return true
        end if
        if m.zone = "live-filters"
            if key = "left"
                if m.liveFilterCursor > 0
                    selectLiveFilter(m.liveFilterCursor-1)
                else
                    cancelRequest()
                    m.zone = "nav"
                    m.nav = 3
                    drawScreen()
                end if
                return true
            end if
            if key = "right" and m.liveFilterCursor < 3 then selectLiveFilter(m.liveFilterCursor+1): return true
            if key = "OK" or key = "down"
                if key = "down" or m.channels.count() = 0
                    m.zone = "live-search"
                    m.liveSearchCursor = 0
                    drawScreen()
                else if m.channels.count() > 0
                    m.zone = "live"
                    drawScreen()
                end if
                return true
            end if
            paintFocus()
            return true
        end if
        if m.zone = "live-actions"
            if key = "left" then m.zone = "nav"
            if key = "right" then m.zone = "live"
            if key = "up" then m.liveAction = 0
            if key = "down" then m.liveAction = 1
            if key = "OK"
                if m.liveAction = 0 then playLiveSelection() else toggleLiveFavorite()
                return true
            end if
            paintFocus()
            return true
        end if
        previous = m.liveCursor
        if key = "left" then m.zone = "live-actions": m.liveAction = 0: drawScreen(): return true
        if key = "up"
            if m.liveCursor > 0 then m.liveCursor-- else m.zone = "live-search": m.liveSearchCursor = 0: drawScreen(): return true
        end if
        if key = "down" and m.liveCursor+1 < m.channels.count() then m.liveCursor++
        if key = "OK" and m.channels.count() > 0
            playLiveSelection()
            return true
        end if
        if previous <> m.liveCursor then scheduleLivePreview(): drawScreen(): return true
    end if
    paintFocus()
    return true
end function
