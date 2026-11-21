' Roku Plus: original personal television application.
sub init()
    m.top.backgroundColor = "0x09090BFF"
    m.top.focusable = true
    m.plusExperience = m.top.findNode("PlusExperience")
    m.plusExperience.visible = true
    m.canvas = m.top.findNode("canvas")
    m.standardPlayer = m.top.findNode("player")
    m.hostPlayer = m.top.findNode("hostPlayer")
    ' Keep m.player as the active-player alias so existing controls, watch state,
    ' TS relay, seek and close handling are shared without changing the main player.
    m.player = m.standardPlayer
    m.pendingEngineSwitch = invalid
    m.invidiousPlayer = m.top.findNode("invidiousPlayer")
    m.invidiousPlayer.observeField("closed","invidiousPlayerClosed")
    m.deadline = m.top.findNode("catalogDeadline")
    m.deadline.observeField("fire","catalogTimedOut")
    m.lease = m.top.findNode("playbackLease")
    m.lease.observeField("fire","renewPlaybackLease")
    m.stallWatchTimer = CreateObject("roSGNode","Timer")
    m.stallWatchTimer.duration = 2
    m.stallWatchTimer.repeat = true
    m.stallWatchTimer.observeField("fire","playbackStallWatchTick")
    m.stallEpisodeClock = CreateObject("roTimespan")
    m.stallWindowClock = CreateObject("roTimespan")
    m.stallEpisodeActive = false
    m.stallEpisodeCounted = false
    m.stallEpisodeCount = 0
    m.activeJobId = ""
    m.leaseTask = invalid
    m.player.observeField("closed","playerClosed")
    m.player.observeField("diagnostics","playerDiagnostic")
    m.player.observeField("retryRequested","retryVideo")
    m.player.observeField("progress","playerProgress")
    m.player.observeField("endSelection","playerEndSelection")
    m.player.observeField("progress","livePreviewProgress")
    m.player.observeField("previewReturned","livePreviewReturned")
    m.player.observeField("closedRequest","livePreviewClosed")
    ' The dedicated host player is a separate decoder instance of the same
    ' proven PlusPlayer engine; VOE never changes the standard player instance.
    m.hostPlayer.observeField("closed","playerClosed")
    m.hostPlayer.observeField("diagnostics","playerDiagnostic")
    m.hostPlayer.observeField("retryRequested","retryVideo")
    m.hostPlayer.observeField("progress","playerProgress")
    m.hostPlayer.observeField("endSelection","playerEndSelection")
    m.hostPlayer.observeField("progress","livePreviewProgress")
    m.hostPlayer.observeField("previewReturned","livePreviewReturned")
    m.hostPlayer.observeField("closedRequest","livePreviewClosed")
    m.previewTimer = m.top.findNode("livePreviewDelay")
    m.previewTimer.observeField("fire","startLivePreview")
    m.noteTimer = m.top.findNode("liveNoticeTimer")
    m.noteTimer.observeField("fire","liveNoticeElapsed")
    m.nextEpisodeTimer = m.top.findNode("nextEpisodeTimer")
    m.nextEpisodeTimer.observeField("fire","nextEpisodeTick")
    m.searchDeleteTimer = m.top.findNode("searchDeleteTimer")
    m.searchDeleteTimer.observeField("fire","searchDeleteHoldElapsed")
    m.dialogFocusTimer = m.top.findNode("dialogFocusRestore")
    m.dialogFocusTimer.observeField("fire","dialogFocusRestoreElapsed")
    m.heroRotation = m.top.findNode("heroRotation")
    m.heroRotation.observeField("fire","heroRotationTick")
    m.discoveryRotation = m.top.findNode("discoveryRotation")
    m.discoveryRotation.observeField("fire","discoveryRotationTick")
    m.heroRotationActive = false
    m.discoveryRotationActive = false
    m.pageTransitionTimer = m.top.findNode("pageTransition")
    m.pageTransitionTimer.observeField("fire","pageTransitionTick")
    m.catalogFadeTimer = m.top.findNode("catalogFade")
    m.catalogFadeTimer.observeField("fire","catalogFadeTick")
    m.catalogFadePosters = []
    m.catalogFadeStep = 0
    m.catalogFadePending = false
    m.pageTransitionStep = 0
    m.lastRenderedView = invalid
    m.discoveryOffset = 0
    m.nextEpisode = invalid
    m.nextEpisodeCountdown = 0
    m.voeBlockedSession = {}
    m.profileId = rpLoadProfileId()
    m.watchState = rpWatchLoad(m.profileId)
    m.profileCursor = 0
    m.lastPlaybackProgress = invalid
    m.activePlaybackItem = invalid
    m.activePlaybackOrigin = invalid
    m.endScreenRequestId = invalid
    m.endScreenNextEpisodePending = false
    m.endScreenWatchedRequestId = invalid
    m.nextEpisodePrefetchTask = invalid
    m.nextEpisodePrefetchRequestId = ""
    m.nextEpisodePrefetchParentRequestId = ""
    m.nextEpisodePrefetchParentItemId = ""
    m.nextEpisodePrefetchItemId = ""
    m.nextEpisodePrefetchAnswer = invalid
    m.introDbTask = invalid
    m.introDbCache = {}
    m.introDbCacheOrder = []
    m.introDbSegments = invalid
    m.watchSaveClock = CreateObject("roTimespan")
    m.watchSaveClock.mark()
    m.watchSaveRetryDelayMs = 5000
    m.continueItems = rpWatchContinue(m.watchState)
    m.homeListItems = []
    refreshHomeListItems()
    m.listCover = 0
    m.libraryMode = "history"
    m.libraryItems = []
    m.libraryCursor = 0
    m.view = "home"
    m.zone = "hero"
    m.nav = 0
    m.hero = 0
    m.heroFeature = 0
    m.cover = 0
    m.detailHomeZone = "hero"
    m.detailHomeCover = 0
    m.detailHomeListCover = 0
    m.detailHomeSeriesCover = 0
    m.detailHomeDiscoveryOffset = 0
    m.seriesCover = 0
    m.images = []
    m.focusItems = []
    m.kind = "movie"
    m.query = ""
    m.searchText = ""
    m.searchCursor = 0
    m.searchSuggestions = []
    m.searchCache = {key:"",items:[],clock:invalid}
    m.catalogPageCache = {key:"",items:[],nextOffset:0,hasMore:false,clock:invalid}
    m.searchDeleteHeld = false
    m.searchDeleteCleared = false
    m.searchOriginView = "home"
    m.offset = 0
    m.nextOffset = 0
    m.more = false
    m.titles = []
    m.pageTitles = []
    m.genreFilter = "Todos"
    m.catalogSort = "popular"
    m.genreChoices = []
    m.ignoreBrowseDownUntilRelease = false
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
    m.categoryInitialScan = false
    m.liveCursor = 0
    m.season = 0
    m.episode = 0
    m.pendingResumeEpisode = invalid
    m.episodeMode = "seasons"
    m.detail = invalid
    m.series = invalid
    m.streamXImageTask = invalid
    m.streamXImageRequestId = ""
    m.streamXImagePendingRequestId = ""
    m.streamXImagePendingKey = ""
    m.streamXImageKey = ""
    m.streamXImages = invalid
    m.streamXImageCache = {}
    m.streamXImageCacheOrder = []
    m.detailOrigin = "home"
    m.detailHomeHero = 0
    m.detailHomeHeroValid = false
    m.autoplay = false
    m.sourceLaunchPending = false
    m.sourceAlternatives = []
    m.sourceAlternativeCursor = 0
    m.sourceAlternativeCountdown = 0
    m.sourceAlternativeQueue = []
    m.sourceAlternativeAttemptIndex = -1
    m.sourceAlternativeAutoActive = false
    m.sourceAlternativeStatus = ""
    m.sourceAlternativeTimer = CreateObject("roSGNode","Timer")
    m.sourceAlternativeTimer.duration = 1
    m.sourceAlternativeTimer.repeat = true
    m.sourceAlternativeTimer.observeField("fire","sourceAlternativeTimerTick")
    m.busy = false
    m.job = invalid
    m.request = ""
    m.pending = invalid
    m.pendingEpisodeFallback = invalid
    m.tvmazeCache = invalid
    m.pendingSegmentUrls = invalid
    m.pendingSegmentDurations = invalid
    m.pendingTsRelay = false
    m.dialogBox = invalid
    m.dialogPurpose = ""
    m.note = ""
    m.action = 0
    m.playbackMode = "direct"
    m.capabilities = rpDeviceProfile(invalid, m.top.currentDesignResolution)
    displayProfile = m.capabilities.display
    print "[RokuPlus display] design="; displayProfile.designName; " "; displayProfile.designWidth; "x"; displayProfile.designHeight; " ui="; displayProfile.uiName; " "; displayProfile.uiWidth; "x"; displayProfile.uiHeight; " output="; displayProfile.outputWidth; "x"; displayProfile.outputHeight
    prefs = rpLoadPreferences(m.capabilities.recommendedCatalog)
    m.configured = prefs.configured
    m.catalogMode = prefs.mode
    m.countryCode = prefs.countryCode
    m.hdProvider = rpLoadHdProvider()
    m.compatBase = rpLoadCompatBase()
    m.theme = rpLoadTheme()
    m.themeCursor = 0
    m.hdSourceCursor = 0
    ' Local file access and JSON parsing run in a Task, never on the Render thread.
    m.hdLibrary = {movies: [], series: []}
    m.hdDataTask = CreateObject("roSGNode", "HdLocalDataTask")
    m.hdDataTask.observeField("result", "hdLocalDataLoaded")
    m.features = []
    m.homeSeries = []
    m.discoveryOffset = 0
    m.homeJobs = []
    m.homeCache = {}
    m.homeLoading = false
    m.settingsCursor = 0
    m.invidiousItems = []
    m.invidiousCursor = 0
    m.invidiousQuery = ""
    m.creditsPage = 0
    m.creditsPages = []
    m.plusInitialized = false
    ActivatePlusExperience()
end sub

sub ActivatePlusExperience()
    print "[RokuPlus startup] activate begin"
    ' Keep the Roku Plus scene focused for normal remote navigation.
    m.top.focusable = true
    m.plusExperience.visible = true
    if not m.plusInitialized
        m.plusInitialized = true
        print "[RokuPlus startup] first activation configured="; m.configured
        ' Paint the first Roku Plus frame before starting background work.
        ' This keeps task creation and network requests out of the first-frame path.
        if not m.configured
            print "[RokuPlus startup] setup screen begin"
            beginSetup(false,false)
            print "[RokuPlus startup] setup screen complete"
        else
            print "[RokuPlus startup] home screen begin"
            drawScreen()
            print "[RokuPlus startup] home screen complete"
        end if
        if m.hdDataTask <> invalid
            print "[RokuPlus startup] local data task begin"
            m.hdDataTask.control = "RUN"
            print "[RokuPlus startup] local data task started"
        end if
        if m.configured
            print "[RokuPlus startup] home requests begin"
            refreshHome()
            print "[RokuPlus startup] home requests started"
        end if
    else if m.view = "home"
        ' Background catalog requests are cancelled when Roku Plus is hidden.
        ' Re-entering Home refreshes from the five-minute cache when possible.
        print "[RokuPlus startup] home re-entry begin"
        drawScreen()
        print "[RokuPlus startup] home re-entry screen complete"
        refreshHome()
        print "[RokuPlus startup] home re-entry requests started"
    end if
    syncHomeRotationTimers()
    m.top.focusable = true
    m.top.setFocus(true)
    print "[RokuPlus input] scene focus restored="; m.top.hasFocus()
    print "[RokuPlus startup] activate complete"
end sub

sub hdLocalDataLoaded(event as object)
    if m.hdDataTask = invalid then return
    if not m.hdDataTask.isSameNode(event.getRoSGNode()) then return
    answer = event.getData()
    m.hdDataTask.unobserveField("result")
    m.hdDataTask = invalid
    if type(answer) <> "roAssociativeArray" then return
    if type(answer.library) = "roAssociativeArray" then m.hdLibrary = answer.library
    if m.plusExperience.visible and m.catalogMode = "hd" and not usesOnlineHd()
        refreshHome()
        drawScreen()
    end if
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
    if online and type(m.tvmazeCache) = "roAssociativeArray" then task.tvmazeCache = m.tvmazeCache
    if online and (context.operation = "resolve" or context.operation = "resume-episode") then task.attempt = orbitInteger(context.item.hdAttempt,99)
    task.operation = context.operation
    task.kind = m.kind
    if context.doesExist("kind") then task.kind = context.kind
    if context.operation = "country" then task.countryCode = m.countryCode
    task.requestId = m.request
    task.query = m.query
    if online and context.operation = "cinemeta-catalog"
        task.query = m.genreFilter
        task.attempt = 0
        if m.catalogSort = "recent" then task.attempt = 1
    end if
    if context.operation = "catalog" or context.operation = "cinemeta-catalog" then task.skip = context.offset
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
        if context.operation = "find-source"
            m.deadline.duration = 65
            m.deadlineMs = 65000
        end if
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
    pendingContext = m.pending
    cancelRequest()
    if m.sourceAlternativeAutoActive
        m.sourceAlternativeAutoActive = false
        m.sourceAlternatives = m.sourceAlternativeQueue
        m.sourceAlternativeCursor = m.sourceAlternativeAttemptIndex
        if m.sourceAlternativeCursor < 0 then m.sourceAlternativeCursor = 0
        m.sourceAlternativeQueue = []
        m.sourceAlternativeAttemptIndex = -1
        m.sourceAlternativeStatus = "La búsqueda tardó demasiado. Puedes elegir otra portada o volver atrás."
    end if
    m.autoplay = false
    m.note = "La consulta tardó demasiado. Pulsa OK para intentar de nuevo o Atrás para volver."
    if type(pendingContext) = "roAssociativeArray" and (pendingContext.operation = "find-source" or pendingContext.operation = "resolve" or pendingContext.operation = "resume-episode")
        keepActiveEpisode = m.view = "player" and m.player.active = true and type(m.activePlaybackItem) = "roAssociativeArray" and type(pendingContext.item) = "roAssociativeArray" and orbitText(pendingContext.item.kind,16) = "episode"
        if m.sourceLaunchPending and not keepActiveEpisode and (type(m.sourceAlternatives) <> "roArray" or m.sourceAlternatives.count() = 0) then m.view = "detail"
        m.sourceLaunchPending = false
    end if
    if m.view = "player"
        if type(pendingContext) = "roAssociativeArray" and (pendingContext.operation = "episodes" or (type(pendingContext.item) = "roAssociativeArray" and orbitText(pendingContext.item.kind,16) = "episode"))
            showPlayerNextEpisodeError(m.note)
        else
            showPlayerEndError(m.note)
        end if
    else
        drawScreen()
    end if
end sub

sub catalogState(event as object)
    if m.job = invalid then return
    if not m.job.isSameNode(event.getRoSGNode()) then return
    if event.getData() <> "STOP" then return
    if type(m.job.result) = "roAssociativeArray" then return
    pendingContext = m.pending
    cancelRequest()
    if m.sourceAlternativeAutoActive
        m.sourceAlternativeAutoActive = false
        m.sourceAlternatives = m.sourceAlternativeQueue
        m.sourceAlternativeCursor = m.sourceAlternativeAttemptIndex
        if m.sourceAlternativeCursor < 0 then m.sourceAlternativeCursor = 0
        m.sourceAlternativeQueue = []
        m.sourceAlternativeAttemptIndex = -1
        m.sourceAlternativeStatus = "No se pudo completar la búsqueda. Puedes elegir otra portada o volver atrás."
    end if
    m.autoplay = false
    m.note = "No se pudo completar la consulta. Vuelve a intentar."
    if type(pendingContext) = "roAssociativeArray" and (pendingContext.operation = "find-source" or pendingContext.operation = "resolve" or pendingContext.operation = "resume-episode")
        keepActiveEpisode = m.view = "player" and m.player.active = true and type(m.activePlaybackItem) = "roAssociativeArray" and type(pendingContext.item) = "roAssociativeArray" and orbitText(pendingContext.item.kind,16) = "episode"
        if m.sourceLaunchPending and not keepActiveEpisode and (type(m.sourceAlternatives) <> "roArray" or m.sourceAlternatives.count() = 0) then m.view = "detail"
        m.sourceLaunchPending = false
    end if
    if m.view = "player"
        if type(pendingContext) = "roAssociativeArray" and (pendingContext.operation = "episodes" or (type(pendingContext.item) = "roAssociativeArray" and orbitText(pendingContext.item.kind,16) = "episode"))
            showPlayerNextEpisodeError(m.note)
        else
            showPlayerEndError(m.note)
        end if
    else
        drawScreen()
    end if
end sub

sub fetched(event as object)
    if m.job = invalid then return
    if not m.job.isSameNode(event.getRoSGNode()) then return
    answer = event.getData()
    if type(answer) <> "roAssociativeArray" then return
    if answer.requestId <> m.request then return
    context = m.pending
    if type(answer.tvmazeCache) = "roAssociativeArray" then m.tvmazeCache = answer.tvmazeCache
    cancelRequest()
    if not answer.ok
        voeBlocked = false
        if answer.doesExist("voeBlocked") and answer.voeBlocked = true then voeBlocked = true
        if (context.operation = "resolve" or context.operation = "resume-episode") and type(context.item) = "roAssociativeArray" and orbitText(context.item.kind,16) = "episode" and rpHdOnlineProvider(context.item.provider) <> "" and context.item.hdFallbackTried <> true
            context.item.hdFallbackTried = true
            print "[RokuPlus source-fallback] trigger=resolve-failed provider="; orbitText(context.item.provider,32); " season="; orbitInteger(context.item.season,999); " episode="; orbitInteger(context.item.episode,9999)
            fetch({operation:"find-source",item:context.item,returnView:"detail",origin:m.detailOrigin})
            return
        end if
        if context.operation = "find-source"
            if not voeBlocked
                if advanceSourceAlternativeAfterMiss() then return
            end if
            m.view = orbitText(context.returnView,24)
            if m.view = "" then m.view = "detail"
            m.sourceLaunchPending = false
            m.autoplay = false
            m.note = answer.message
            m.sourceAlternatives = []
            m.sourceAlternativeCursor = 0
            if type(answer.alternatives) = "roArray" and answer.alternatives.count() > 0 and answer.doesExist("alternativeKind")
                m.view = "source-resolving"
                m.sourceAlternativeQueue = answer.alternatives
                m.sourceAlternativeAttemptIndex = -1
                m.sourceAlternativeAutoActive = false
                m.sourceAlternativeStatus = ""
                m.sourceLaunchPending = false
                m.sourceAlternatives = answer.alternatives
                m.sourceAlternativeCursor = 0
                startSourceAlternativeCountdown()
                m.note = "No se encontró una fuente confirmada. Selecciona un título similar para intentar reproducirlo."
                print "[RokuPlus source-alternatives] displayed="; m.sourceAlternatives.count(); " kind="; orbitText(answer.alternativeKind,16); " view="; m.view
            end if
            drawScreen()
            return
        end if
        voeBlocked = false
        if answer.doesExist("voeBlocked") and answer.voeBlocked = true then voeBlocked = true
        if voeBlocked
            if type(context.item) = "roAssociativeArray"
                context.item.voeBlocked = true
                blockKey = rpVoeBlockKey(context.item)
                if blockKey <> "" then m.voeBlockedSession[blockKey] = true
            end if
            if type(m.detail) = "roAssociativeArray"
                m.detail.voeBlocked = true
                blockKey = rpVoeBlockKey(m.detail)
                if blockKey <> "" then m.voeBlockedSession[blockKey] = true
            end if
            print "[RokuPlus voe] retry_suppressed=1 reason=anti-bot-session"
        end if
        if not voeBlocked and (context.operation = "meta" or context.operation = "resolve" or context.operation = "episodes" or context.operation = "resume-episode")
            retryItem = invalid
            if context.doesExist("item") and type(context.item) = "roAssociativeArray" then retryItem = context.item
            if retryItem = invalid and type(m.detail) = "roAssociativeArray" then retryItem = m.detail
            if type(retryItem) = "roAssociativeArray"
                autoRetry = orbitInteger(retryItem.hdAutoRetry,2)
                if autoRetry < 1
                    retryItem.hdAutoRetry = autoRetry+1
                    if context.operation = "resolve" then retryItem.hdAttempt = orbitInteger(retryItem.hdAttempt,99)+1
                    print "[RokuPlus hd-retry] automatic=1 operation="; context.operation; " provider="; orbitText(retryItem.provider,32)
                    retryContext = {operation:context.operation,item:retryItem}
                    if context.doesExist("season") then retryContext.season = context.season
                    fetch(retryContext)
                    return
                end if
            end if
        end if
        if not voeBlocked and (context.operation = "resolve" or context.operation = "find-source" or context.operation = "resume-episode")
            if advanceSourceAlternativeAfterMiss() then return
        end if
        m.autoplay = false
        m.note = answer.message
        if m.sourceLaunchPending
            m.sourceLaunchPending = false
            keepActiveEpisode = m.view = "player" and m.player.active = true and type(m.activePlaybackItem) = "roAssociativeArray" and type(context.item) = "roAssociativeArray" and orbitText(context.item.kind,16) = "episode"
            if not keepActiveEpisode then m.view = "detail"
        end if
        if context.operation = "compatible" then m.note = "La reproducción con PC no está disponible. Puedes elegir Reproducir para usar la conexión directa."
        if m.view = "player"
            if context.operation = "episodes" or (type(context.item) = "roAssociativeArray" and orbitText(context.item.kind,16) = "episode")
                showPlayerNextEpisodeError(m.note)
            else
                showPlayerEndError(m.note)
            end if
        else
            drawScreen()
        end if
        return
    end if
    if type(m.detail) = "roAssociativeArray" then m.detail.hdAutoRetry = 0
    if type(context.item) = "roAssociativeArray" then context.item.hdAutoRetry = 0
    if m.sourceAlternativeAutoActive
        m.sourceAlternativeAutoActive = false
        m.sourceAlternativeQueue = []
        m.sourceAlternativeAttemptIndex = -1
        m.sourceAlternativeStatus = ""
    end if
    if context.operation = "invidious-search"
        m.invidiousItems = answer.items
        m.invidiousCursor = 0
        m.view = "invidious"
        m.zone = "invidious"
        if m.invidiousItems.count() = 0 then m.note = "No se encontraron videos en Invidious."
    else if context.operation = "invidious-resolve"
        if answer.ok
            m.playbackMode = "direct"
            m.detail = context.item
            m.detailOrigin = "invidious"
            launchInvidiousVideo(context.item,answer.url,answer.streamFormat,answer.bitrate)
            return
        else
            m.note = answer.message
        end if
    else if context.operation = "find-source" and type(answer.item) = "roAssociativeArray" and answer.item.kind = "series"
        m.sourceLaunchPending = false
        m.detail = answer.item
        m.detailOrigin = orbitText(context.origin,24)
        if m.detailOrigin = "" then m.detailOrigin = "browse"
        m.series = answer.item
        m.seriesOrigin = m.detailOrigin
        m.season = 0
        if m.series.seasons.count() > 0 and m.series.seasons[0].number = 0 and m.series.seasons.count() > 1 then m.season = 1
        m.episode = 0
        m.episodeMode = "episodes"
        m.view = "episodes"
        m.zone = "seasons"
        m.note = ""
        selectLastWatchedEpisode()
        drawScreen()
        loadEpisodeSeason()
        m.top.setFocus(true)
        return
    else if context.operation = "catalog" or context.operation = "cinemeta-catalog" or context.operation = "search"
        if context.operation = "search"
            if answer.partial <> true and answer.items.count() > 0
                cacheQuery = lcase(orbitText(context.query,120))
                if cacheQuery <> ""
                    m.searchCache = {key:m.catalogMode + "|" + m.hdProvider + "|all|" + cacheQuery,items:answer.items,clock:CreateObject("roTimespan")}
                    m.searchCache.clock.mark()
                end if
            end if
            m.pageTitles = orbitUniqueCatalogItems(answer.items)
            applyGenreFilter()
            m.offset = 0
            m.nextOffset = 0
            m.more = false
            m.cursor = 0
            if m.titles.count() = 0 then m.note = "No se encontraron películas ni series con ese título."
            if answer.partial = true then m.note = "Una fuente no respondió. Se muestran los resultados disponibles."
        else if answer.items.count() = 0 and context.offset > 0 and not answer.hasMore
            ' Keep the already displayed titles: reaching the end must not clear the continuous list.
            m.more = false
            m.note = "Llegaste al final de los resultados."
        else
            if answer.partial <> true
                pageKey = m.catalogMode + "|" + m.hdProvider + "|" + m.kind + "|" + orbitText(m.query,120) + "|" + m.genreFilter + "|" + m.catalogSort + "|" + context.operation + "|" + context.offset.toStr()
                m.catalogPageCache = {key:pageKey,items:answer.items,nextOffset:answer.nextSkip,hasMore:answer.hasMore,clock:CreateObject("roTimespan")}
                m.catalogPageCache.clock.mark()
            end if
            previousVisibleCount = m.titles.count()
            if context.offset > 0
                combinedPage = []
                for each existingItem in m.pageTitles
                    combinedPage.push(existingItem)
                end for
                for each nextItem in answer.items
                    combinedPage.push(nextItem)
                end for
                m.pageTitles = orbitUniqueCatalogItems(combinedPage)
            else
                m.pageTitles = orbitUniqueCatalogItems(answer.items)
            end if
            applyGenreFilter()
            m.offset = context.offset
            m.nextOffset = answer.nextSkip
            m.more = answer.hasMore
            ' Genre catalogs are fetched by Cinemeta genre and may scan up to 400
            ' source items automatically to collect at least 30 visible matches.
            if (context.operation = "catalog" or context.operation = "cinemeta-catalog") and m.genreFilter <> "Todos" and m.titles.count() < 30 and answer.hasMore and context.offset < 400
                print "[RokuPlus genres] scan_next=1 filter="; m.genreFilter; " source_offset="; answer.nextSkip; " matches="; m.titles.count()
                loadBrowsePage(answer.nextSkip)
                return
            end if
            if m.categoryInitialScan
                ' Keep the first poster selected while the initial genre scan appends pages.
                m.cursor = 0
                m.categoryInitialScan = false
            else
                m.cursor = 0
                if context.offset > 0 and m.titles.count() > previousVisibleCount
                    m.cursor = previousVisibleCount
                else if context.offset > 0 and m.titles.count() > 0
                    m.cursor = m.titles.count()-1
                end if
                if context.doesExist("last") and context.last then m.cursor = m.titles.count()-1
                if m.cursor < 0 then m.cursor = 0
            end if
            ' New pages join the existing grid without a page-transition fade.
            m.catalogFadePending = false
        end if
        if context.operation = "search" then m.catalogFadePending = false
        ' Keep the category strip focused after an asynchronous category refresh.
        ' If the user moved down while loading, preserve the grid focus instead.
        if m.zone <> "categories" then m.zone = "grid"
        if answer.partial = true then m.note = "Una fuente no respondió. Se muestran las opciones disponibles."
    else if context.operation = "meta"
        ' Keep the original catalog identity when a provider metadata adapter
        ' returns a reduced item. Continue Watching needs these source fields.
        if type(answer.item) = "roAssociativeArray" and context.doesExist("item") and type(context.item) = "roAssociativeArray"
            ' Keep legacy source fields only when the refreshed metadata omitted them.
            ' A validated replacement value must not be overwritten by stale history.
            identityFields = ["provider", "providerId", "providerSlug", "providerTmdbId", "providerKind", "season", "episode", "seriesTitle", "seriesId", "seriesProviderId", "seriesProviderSlug", "seriesProviderTmdbId", "seriesProviderKind", "seriesSeasonNumbers"]
            for each identityField in identityFields
                if context.item.doesExist(identityField)
                    sourceValue = context.item[identityField]
                    if sourceValue <> invalid
                        targetMissing = not answer.item.doesExist(identityField)
                        if not targetMissing
                            targetValue = answer.item[identityField]
                            if targetValue = invalid then targetMissing = true
                            if GetInterface(targetValue, "ifString") <> invalid
                                if targetValue = "" then targetMissing = true
                            end if
                        end if
                        if targetMissing
                            keepValue = true
                            if GetInterface(sourceValue, "ifString") <> invalid
                                if sourceValue = "" then keepValue = false
                            end if
                            if keepValue then answer.item[identityField] = sourceValue
                        end if
                    end if
                end if
            end for
            ' Re-key saved progress only when IMDb ID plus kind and episode
            ' coordinates establish that both catalog IDs represent one item.
            if type(m.watchState) = "roArray"
                m.watchState = rpWatchMigrateIdentity(m.watchState,context.item,answer.item)
                if orbitText(context.item.id,180) <> orbitText(answer.item.id,180)
                    if not rpWatchSave(m.watchState,m.profileId)
                        m.watchState = rpWatchLoad(m.profileId)
                        m.continueItems = rpWatchContinue(m.watchState)
                        refreshHomeListItems()
                        m.note = "No se pudo guardar la actualización del historial."
                    end if
                end if
            end if
        end if
        m.detail = answer.item
        preloadStreamXImages(m.detail)
        if m.autoplay
            m.autoplay = false
            playDetail()
            return
        end if
        ' Open a series directly in its season and episode browser.
        if m.detail.kind = "series" and m.detail.seasons.count() > 0
            m.series = m.detail
            m.seriesOrigin = m.detailOrigin
            m.season = 0
            if m.series.seasons[0].number = 0 and m.series.seasons.count() > 1 then m.season = 1
            m.episode = 0
            m.episodeMode = "episodes"
            m.view = "episodes"
            m.zone = "seasons"
            selectLastWatchedEpisode()
        end if
    else if context.operation = "resolve" or context.operation = "resume-episode" or context.operation = "find-source"
        if context.operation = "resume-episode" or context.operation = "find-source"
            if type(answer.item) = "roAssociativeArray" then m.detail = answer.item
        end if
        if context.operation = "find-source" then m.view = "detail"
        m.detail.hdAutoRetry = 0
        if type(answer.mediaHeaders) = "roAssociativeArray" then m.detail.mediaHeaders = answer.mediaHeaders
        m.detail.playbackEngine = "standard"
        if answer.doesExist("playbackEngine") and answer.playbackEngine = "host" then m.detail.playbackEngine = "host"
        m.detail.hdAttempt = orbitInteger(answer.attemptUsed,99)
        m.pendingSubtitleTracks = answer.subtitleTracks
        m.pendingSelectedSubtitleGroup = orbitText(answer.selectedSubtitleGroup,100)
        m.pendingSourceHost = orbitText(answer.sourceHost,24)
        m.pendingSegmentUrls = answer.segmentUrls
        m.pendingSegmentDurations = answer.segmentDurations
        m.pendingFallbackSegmentUrls = answer.fallbackSegmentUrls
        m.pendingFallbackSegmentDurations = answer.fallbackSegmentDurations
        m.pendingFallbackTsRelay = false
        if answer.fallbackTsRelayEnabled = true then m.pendingFallbackTsRelay = true
        m.pendingTsRelay = false
        if answer.tsRelayEnabled = true then m.pendingTsRelay = true
        launchVideo(m.detail,answer.url,answer.streamFormat)
        return
    else if context.operation = "episodes"
        if m.series = invalid or context.item.id <> m.series.id then return
        for each incoming in answer.seasons
            incoming.loaded = true
            for i = 0 to m.series.seasons.count()-1
                if m.series.seasons[i].number = incoming.number then m.series.seasons[i] = incoming
            end for
        end for
        if m.view = "episodes"
            currentSeasonNumber = -999
            if type(m.series.seasons) = "roArray" and m.season >= 0 and m.season < m.series.seasons.count()
                currentSeasonNumber = orbitInteger(m.series.seasons[m.season].number,-999)
            end if
            if context.doesExist("season") and currentSeasonNumber = orbitInteger(context.season,-998)
                m.episode = 0
                applyPendingResumeEpisode()
            end if
        end if
        if m.view = "player" and m.endScreenNextEpisodePending
            for each seasonEntry in m.series.seasons
                if seasonEntry.number = context.season then seasonEntry.loaded = true
            end for
            m.endScreenNextEpisodePending = false
            preparePlaybackEndScreen()
            return
        end if
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
    if context.operation = "meta" and m.view = "episodes" then loadEpisodeSeason()
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
    preloadStreamXImages(item)
    m.detail.hdAttempt = 0
    m.detail.hdAutoRetry = 0
    blockKey = rpVoeBlockKey(m.detail)
    m.detail.voeBlocked = blockKey <> "" and m.voeBlockedSession.doesExist(blockKey)
    m.detailOrigin = origin
    m.detailHomeHeroValid = origin = "home" and m.zone = "hero"
    if origin = "home"
        m.detailHomeZone = m.zone
        m.detailHomeCover = m.cover
        m.detailHomeListCover = m.listCover
        m.detailHomeSeriesCover = m.seriesCover
        m.detailHomeDiscoveryOffset = m.discoveryOffset
    end if
    if m.detailHomeHeroValid then m.detailHomeHero = m.hero
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
        ' Older LaMovie watch records can retain the numeric post ID but lack
        ' the slug required by the metadata endpoint. Resolve playback directly
        ' by numeric ID instead of showing a false source-connection error.
        if orbitText(item.discoverySource,32) = "cinemeta"
            fetch({operation:"meta",item:item})
            return
        end if
        resumeProvider = lcase(orbitText(item.provider,32))
        resumeSlug = orbitText(item.providerSlug,200)
        resumeProviderId = orbitInteger(item.providerId,999999999)
        if playNow and item.kind = "movie" and resumeProvider = "lamovie" and resumeSlug = "" and resumeProviderId > 0
            print "[RokuPlus continue] resume-direct=1 reason=missing-lamovie-slug providerId="; resumeProviderId
            playDetail()
        else
            fetch({operation:"meta",item:item})
        end if
    end if
end sub


' Keep metadata caches bounded on Roku devices with limited memory.
' FIFO eviction is intentionally simple and never touches active task/player data.
sub rpStoreBoundedCache(cache as object, cacheOrder as object, key as string, value as dynamic, limit as integer)
    if key = "" or limit < 1 then return
    if cache.doesExist(key)
        cache[key] = value
        return
    end if
    while cache.count() >= limit and cacheOrder.count() > 0
        oldestKey = cacheOrder[0]
        cacheOrder.delete(0)
        if cache.doesExist(oldestKey) then cache.delete(oldestKey)
    end while
    ' Recover safely if the order list and associative array ever diverge.
    while cache.count() >= limit
        removed = false
        for each existingKey in cache
            cache.delete(existingKey)
            removed = true
            exit for
        end for
        if not removed then exit while
    end while
    cache[key] = value
    cacheOrder.push(key)
end sub

sub cancelStreamXImageTask()
    if m.streamXImageTask <> invalid
        m.streamXImageTask.unobserveField("result")
        m.streamXImageTask.cancelRequested = true
        m.streamXImageTask = invalid
    end if
    m.streamXImageRequestId = ""
    m.streamXImagePendingRequestId = ""
    m.streamXImagePendingKey = ""
end sub

sub preloadStreamXImages(item as dynamic)
    if type(item) <> "roAssociativeArray"
        cancelStreamXImageTask()
        m.streamXImageKey = ""
        m.streamXImages = invalid
        return
    end if
    lookupItem = item
    mediaType = "movie"
    if orbitText(item.kind,20) = "series"
        mediaType = "series"
    else if orbitText(item.kind,20) = "episode"
        mediaType = "series"
        if type(m.series) = "roAssociativeArray"
            lookupItem = m.series
        end if
    end if

    title = orbitText(lookupItem.title,160)
    if title = "" and mediaType = "series" then title = orbitText(item.seriesTitle,160)
    imdbId = orbitText(lookupItem.imdbId,40)
    if imdbId = "" and mediaType = "series" then imdbId = orbitText(item.seriesImdbId,40)
    year = orbitText(lookupItem.year,4)
    if year = "" then year = orbitText(item.year,4)
    if title = "" and imdbId = ""
        cancelStreamXImageTask()
        m.streamXImageKey = ""
        m.streamXImages = invalid
        return
    end if

    cacheKey = mediaType+"|"+imdbId
    if imdbId = "" then cacheKey += "|"+lcase(title)+"|"+year
    if m.streamXImageKey <> cacheKey then m.streamXImages = invalid
    m.streamXImageKey = cacheKey
    if m.streamXImageCache.doesExist(cacheKey)
        cancelStreamXImageTask()
        m.streamXImages = m.streamXImageCache[cacheKey]
        return
    end if
    if m.streamXImageTask <> invalid and m.streamXImageRequestId <> ""
        if m.streamXImagePendingKey = cacheKey then return
        cancelStreamXImageTask()
    end if

    requestId = CreateObject("roDeviceInfo").getRandomUUID()
    task = CreateObject("roSGNode","StreamXImageTask")
    task.imdbId = imdbId
    task.mediaType = mediaType
    task.title = title
    task.year = year
    task.requestId = requestId
    task.observeField("result","streamXImagesLoaded")
    m.streamXImageTask = task
    m.streamXImageRequestId = requestId
    m.streamXImagePendingRequestId = requestId
    m.streamXImagePendingKey = cacheKey
    print "[RokuPlus StreamX] preload-start type="; mediaType; " imdb="; imdbId; " title="; left(title,80)
    task.control = "RUN"
end sub

sub streamXImagesLoaded(event as object)
    if m.streamXImageTask = invalid then return
    if not m.streamXImageTask.isSameNode(event.getRoSGNode()) then return
    answer = event.getData()
    m.streamXImageTask.unobserveField("result")
    m.streamXImageTask = invalid
    m.streamXImageRequestId = ""
    if type(answer) <> "roAssociativeArray" then return
    if orbitText(answer.requestId,80) = "" then return
    if answer.requestId <> m.streamXImagePendingRequestId then return
    cacheKey = orbitText(m.streamXImagePendingKey,400)
    if cacheKey = "" then return
    imageResult = {logo:orbitText(answer.logo,2048),background:orbitText(answer.background,2048),imdbId:orbitText(answer.imdbId,40)}
    rpStoreBoundedCache(m.streamXImageCache,m.streamXImageCacheOrder,cacheKey,imageResult,40)
    if m.streamXImageKey = cacheKey then m.streamXImages = imageResult
    hasLogo = imageResult.logo <> ""
    hasBanner = imageResult.background <> ""
    print "[RokuPlus StreamX] preload-complete logo="; hasLogo; " banner="; hasBanner
    if m.view = "source-resolving" and m.streamXImageKey = cacheKey then drawScreen()
end sub

sub launchInvidiousVideo(item as object, url as string, format as string, bitrate as dynamic)
    ' Dedicated decoder: Invidious playback never enters PlusPlayer or its TS/seek pipeline.
    stopLivePreview()
    m.viewBeforeInvidiousPlayer = "invidious"
    m.view = "invidious-player"
    syncHomeRotationTimers()
    m.canvas.visible = false
    eraseScreen()
    m.invidiousPlayer.visible = true
    m.invidiousPlayer.request = {title:orbitText(item.title,180),url:url,streamFormat:format,bitrate:bitrate}
    m.invidiousPlayer.setFocus(true)
end sub

sub invidiousPlayerClosed(event as object)
    if event.getData() <> true then return
    m.invidiousPlayer.visible = false
    m.view = m.viewBeforeInvidiousPlayer
    m.invidiousPlayer.active = false
    drawScreen()
    m.top.setFocus(true)
end sub

sub launchVideo(item as object, url as string, format as string)
    cancelNextEpisodePrefetch()
    m.sourceLaunchPending = false
    targetPlayer = m.standardPlayer
    targetEngine = "standard"
    if type(item) = "roAssociativeArray" and item.doesExist("playbackEngine")
        if lcase(orbitText(item.playbackEngine,20)) = "host"
            targetPlayer = m.hostPlayer
            targetEngine = "host"
        end if
    end if
    ' Switch decoder instances only after the current native pipeline has stopped.
    ' This prevents two Roku Video nodes from playing simultaneously.
    if not m.player.isSameNode(targetPlayer) and m.player.active = true
        m.pendingEngineSwitch = {target:targetEngine,item:item,url:url,format:format}
        print "[RokuPlus player-router] switch_pending from="; "active"; " to="; targetEngine
        m.player.closePlayback()
        return
    end if
    if not m.player.isSameNode(targetPlayer) then m.player.visible = false
    m.player = targetPlayer
    print "[RokuPlus player-router] engine="; targetEngine; " instance="; targetEngine
    ' Recover LaMovie numeric identity from the canonical HD id when a
    ' catalog item arrives with its slug but without providerId.
    itemProvider = lcase(orbitText(item.provider,32))
    if item.kind = "episode"
        parentSlug = orbitText(item.seriesProviderSlug,200)
        parentId = orbitText(item.seriesId,180)
        if parentId = "" and itemProvider = "seriesmetro" then parentId = "hdo-seriesmetro-"+orbitInteger(item.providerId,999999999).toStr()
        parentProviderId = item.providerId
        if item.doesExist("seriesProviderId") then parentProviderId = item.seriesProviderId
        parentProviderTmdbId = orbitText(item.seriesProviderTmdbId,40)
        parentProviderKind = orbitText(item.seriesProviderKind,16)
        if parentSlug <> "" and parentId <> ""
            if m.series = invalid or m.series.id <> parentId
                seasonNumber = orbitInteger(item.season,999,0)
                parentSeasons = []
                if type(item.seriesSeasonNumbers) = "roArray"
                    for each parentSeasonNumber in item.seriesSeasonNumbers
                        safeSeasonNumber = orbitInteger(parentSeasonNumber,999,-1)
                        if safeSeasonNumber >= 0 then parentSeasons.push({number:safeSeasonNumber,episodes:[],loaded:false})
                    end for
                end if
                hasCurrentSeason = false
                for each parentSeason in parentSeasons
                    if parentSeason.number = seasonNumber then hasCurrentSeason = true
                end for
                if not hasCurrentSeason then parentSeasons.push({number:seasonNumber,episodes:[],loaded:false})
                parentSeasons.sortBy("number")
                m.series = {id:parentId,imdbId:"",kind:"series",library:"hd-online",provider:itemProvider,providerId:parentProviderId,providerSlug:parentSlug,providerTmdbId:parentProviderTmdbId,providerKind:parentProviderKind,title:orbitText(item.seriesTitle,180),poster:orbitText(item.poster,2048),background:orbitText(item.background,2048),description:orbitText(item.description),year:orbitText(item.year,4),runtime:0,language:"",seasons:parentSeasons}
                m.seriesOrigin = "home"
                print "[RokuPlus series] restored-parent provider="; itemProvider; " id="; parentId; " season="; seasonNumber
            end if
        end if
    end if
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
    if m.view <> "player" then m.viewBeforePlayer = m.view
    m.view = "player"
    syncHomeRotationTimers()
    loadingTitleNode = m.player.findNode("loadingTitle")
    if loadingTitleNode <> invalid then loadingTitleNode.text = left(orbitText(item.title,130),130)
    m.player.visible = true
    descriptor = {title:item.title,url:url,streamFormat:format,kind:item.kind,itemId:item.id,provider:orbitText(item.provider,32),direct:m.playbackMode="direct",poster:orbitText(item.poster,2048),background:orbitText(item.background,2048),year:orbitText(item.year,20)}
    if type(m.pendingSubtitleTracks) = "roArray"
        descriptor.subtitleTracks = m.pendingSubtitleTracks
        m.pendingSubtitleTracks = invalid
    end if
    if GetInterface(m.pendingSelectedSubtitleGroup,"ifString") <> invalid
        descriptor.selectedSubtitleGroup = m.pendingSelectedSubtitleGroup
        m.pendingSelectedSubtitleGroup = invalid
    end if
    if GetInterface(m.pendingSourceHost,"ifString") <> invalid
        descriptor.sourceHost = m.pendingSourceHost
        m.pendingSourceHost = invalid
    end if
    if descriptor.provider = "lamovie"
        print "[RokuPlus identity] launch id="; descriptor.itemId; " providerId="; orbitText(item.providerId,40); " slugPresent="; item.doesExist("providerSlug"); " slug="; orbitText(item.providerSlug,200)
    end if
    if item.doesExist("imdbId") then descriptor.imdbId = orbitText(item.imdbId,24)
    if item.doesExist("seriesTitle") then descriptor.seriesTitle = orbitText(item.seriesTitle,200)
    if item.doesExist("season") then descriptor.season = item.season
    if item.doesExist("episode") then descriptor.episode = item.episode
    if item.doesExist("introStart") then descriptor.introStart = item.introStart
    if item.doesExist("introEnd") then descriptor.introEnd = item.introEnd
    savedProgress = rpWatchGet(m.watchState,item.id)
    if savedProgress <> invalid
        print "[RokuPlus resume] bookmark itemId="; orbitText(item.id,180); " position="; savedProgress.position; " watched="; savedProgress.watched
        if savedProgress.position > 15 and savedProgress.watched <> true
            descriptor.resumePosition = savedProgress.position
            print "[RokuPlus resume] descriptor itemId="; orbitText(item.id,180); " target="; descriptor.resumePosition
        else
            print "[RokuPlus resume] bookmark_ignored itemId="; orbitText(item.id,180); " reason=position_or_watched"
        end if
    else
        print "[RokuPlus resume] bookmark_missing itemId="; orbitText(item.id,180)
    end if
    if item.doesExist("mediaHeaders") then descriptor.mediaHeaders = item.mediaHeaders
    if type(m.pendingFallbackSegmentUrls) = "roArray"
        descriptor.fallbackSegmentUrls = m.pendingFallbackSegmentUrls
        m.pendingFallbackSegmentUrls = invalid
    end if
    if type(m.pendingFallbackSegmentDurations) = "roArray"
        descriptor.fallbackSegmentDurations = m.pendingFallbackSegmentDurations
        m.pendingFallbackSegmentDurations = invalid
    end if
    if m.pendingFallbackTsRelay = true then descriptor.fallbackTsRelayEnabled = true
    m.pendingFallbackTsRelay = false
    if type(m.pendingSegmentUrls) = "roArray"
        descriptor.segmentUrls = m.pendingSegmentUrls
        m.pendingSegmentUrls = invalid
    end if
    if type(m.pendingSegmentDurations) = "roArray"
        descriptor.segmentDurations = m.pendingSegmentDurations
        m.pendingSegmentDurations = invalid
    end if
    if m.pendingTsRelay then descriptor.tsRelayEnabled = true
    m.pendingTsRelay = false
    ' Tag every playback request so delayed progress from an earlier decoder
    ' generation cannot overwrite the currently selected title's watch state.
    descriptor.requestId = CreateObject("roDeviceInfo").getRandomUUID()
    m.activePlaybackRequestId = descriptor.requestId
    m.activePlaybackProfileId = m.profileId
    m.activePlaybackItem = item
    m.activePlaybackOrigin = m.detailOrigin
    m.lastPlaybackProgress = invalid
    m.endScreenRequestId = invalid
    m.endScreenWatchedRequestId = invalid
    m.endScreenNextEpisodePending = false
    m.introDbSegments = invalid
    if m.introDbTask <> invalid
        m.introDbTask.cancelRequested = true
        m.introDbTask = invalid
    end if
    m.player.endScreenData = invalid
    m.player.introDbData = invalid
    m.player.request = descriptor
    m.stallEpisodeActive = false
    m.stallEpisodeCounted = false
    m.stallEpisodeCount = 0
    m.stallWindowClock.mark()
    if item.kind = "episode" and rpHdOnlineProvider(item.provider) <> ""
        m.stallWatchTimer.control = "start"
    else
        m.stallWatchTimer.control = "stop"
    end if
    imdbId = orbitText(descriptor.imdbId,24)
    lookupTitle = orbitText(item.title,200)
    if item.kind = "episode" then lookupTitle = orbitText(item.seriesTitle,200)
    lookupYear = orbitText(item.year,4)
    cacheKey = ""
    if imdbId <> ""
        if item.kind = "movie"
            cacheKey = imdbId + "|movie"
        else if item.kind = "episode"
            cacheKey = imdbId + "|s" + orbitInteger(descriptor.season,999).toStr() + "e" + orbitInteger(descriptor.episode,9999).toStr()
        end if
    else if lookupTitle <> ""
        if item.kind = "movie"
            cacheKey = "cinemeta|" + lcase(lookupTitle) + "|" + lookupYear + "|movie"
        else if item.kind = "episode"
            cacheKey = "cinemeta|" + lcase(lookupTitle) + "|" + lookupYear + "|s" + orbitInteger(descriptor.season,999).toStr() + "e" + orbitInteger(descriptor.episode,9999).toStr()
        end if
    end if
    if cacheKey <> "" and m.introDbCache.doesExist(cacheKey)
        cachedSegments = m.introDbCache[cacheKey]
        m.introDbSegments = cachedSegments
        m.player.introDbData = {ok:true,requestId:descriptor.requestId,intro:cachedSegments.intro,recap:cachedSegments.recap,outro:cachedSegments.outro,post_credits:cachedSegments.post_credits,no_intro:cachedSegments.no_intro,no_recap:cachedSegments.no_recap,no_outro:cachedSegments.no_outro}
        print "[RokuPlus introdb] cache_hit imdb="; imdbId
    else if imdbId <> "" or lookupTitle <> ""
        task = CreateObject("roSGNode","IntroDbTask")
        task.imdbId = imdbId
        task.title = lookupTitle
        task.year = lookupYear
        task.isMovie = item.kind = "movie"
        if item.kind = "episode"
            task.season = orbitInteger(descriptor.season,999)
            task.episode = orbitInteger(descriptor.episode,9999)
        end if
        task.requestId = descriptor.requestId
        task.cacheKey = cacheKey
        task.observeField("result","introDbResult")
        m.introDbTask = task
        task.control = "RUN"
        print "[RokuPlus introdb] lookup_started imdb="; imdbId; " cinemetaTitle="; lookupTitle; " cacheKey="; cacheKey
    else
        print "[RokuPlus introdb] skipped reason=missing_title_identity item="; orbitText(item.id,100)
    end if
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

sub introDbResult(event as object)
    if m.introDbTask = invalid then return
    if not m.introDbTask.isSameNode(event.getRoSGNode()) then return
    answer = event.getData()
    m.introDbTask = invalid
    if type(answer) <> "roAssociativeArray" then return
    if answer.requestId <> m.activePlaybackRequestId then return
    if answer.ok
        cacheKey = orbitText(answer.cacheKey,100)
        cachedData = {intro:answer.intro,recap:answer.recap,outro:answer.outro,post_credits:answer.post_credits,no_intro:answer.no_intro,no_recap:answer.no_recap,no_outro:answer.no_outro}
        if cacheKey <> "" then rpStoreBoundedCache(m.introDbCache,m.introDbCacheOrder,cacheKey,cachedData,80)
        resolvedCacheKey = orbitText(answer.cacheKey,100)
        if resolvedCacheKey <> "" then rpStoreBoundedCache(m.introDbCache,m.introDbCacheOrder,resolvedCacheKey,cachedData,80)
        m.introDbSegments = answer
        m.player.introDbData = answer
        print "[RokuPlus introdb] lookup_ok intro="; type(answer.intro); " recap="; type(answer.recap); " outro="; type(answer.outro); " postCredits="; type(answer.post_credits)
    else
        print "[RokuPlus introdb] lookup_unavailable reason="; orbitText(answer.message,160)
    end if
end sub

sub playbackStallWatchTick()
    if m.view <> "player" or type(m.detail) <> "roAssociativeArray" then return
    if orbitText(m.detail.kind,16) <> "episode" then return
    provider = rpHdOnlineProvider(m.detail.provider)
    if provider = "" or m.detail.hdFallbackTried = true then return
    if m.pendingEpisodeFallback <> invalid then return
    decoder = m.player.findNode("decoder")
    if decoder = invalid then return
    state = orbitText(decoder.state,20)
    if state = "paused"
        m.stallEpisodeActive = false
        m.stallEpisodeCounted = false
        return
    end if
    buffer = decoder.bufferingStatus
    underrun = false
    if type(buffer) = "roAssociativeArray"
        if buffer.isUnderrun = true then underrun = true
    end if
    if state = "buffering" and underrun
        if not m.stallEpisodeActive
            m.stallEpisodeActive = true
            m.stallEpisodeCounted = false
            m.stallEpisodeClock.mark()
            print "[RokuPlus source-watchdog] stall_started provider="; provider
        end if
        elapsed = m.stallEpisodeClock.totalMilliseconds()
        if elapsed >= 10000 and not m.stallEpisodeCounted
            if m.stallEpisodeCount = 0 or m.stallWindowClock.totalMilliseconds() >= 120000
                m.stallEpisodeCount = 0
                m.stallWindowClock.mark()
            end if
            m.stallEpisodeCount = m.stallEpisodeCount + 1
            m.stallEpisodeCounted = true
            print "[RokuPlus source-watchdog] stall_count="; m.stallEpisodeCount; " elapsedMs="; elapsed; " provider="; provider
        end if
        if elapsed >= 30000 or m.stallEpisodeCount >= 3
            print "[RokuPlus source-watchdog] action=try_next_source count="; m.stallEpisodeCount; " elapsedMs="; elapsed; " provider="; provider
            m.detail.hdFallbackTried = true
            m.pendingEpisodeFallback = {item:m.detail,origin:m.detailOrigin}
            m.recovering = false
            m.stallWatchTimer.control = "stop"
            m.player.callFunc("closePlayback")
            return
        end if
    else
        if state = "playing" or not underrun
            m.stallEpisodeActive = false
            m.stallEpisodeCounted = false
        end if
    end if
end sub

function rpWatchNextSaveRetryDelay(saved as boolean, currentDelay as integer) as integer
    if saved then return 5000
    if currentDelay < 1000 then return 2000
    if currentDelay < 8000 then return currentDelay * 2
    return 15000
end function

sub playerProgress(event as object)
    sample = event.getData()
    if m.watchDiagCount = invalid then m.watchDiagCount = 0
    m.watchDiagCount = m.watchDiagCount + 1
    playbackItem = m.activePlaybackItem
    detailId = ""
    if type(playbackItem) = "roAssociativeArray" and playbackItem.doesExist("id") then detailId = orbitText(playbackItem.id,180)
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
    if m.activePlaybackProfileId = invalid or m.activePlaybackProfileId <> m.profileId
        if m.watchDiagCount <= 8 then print "[RokuPlus watch] rejected=profile-mismatch session="; orbitText(m.activePlaybackProfileId,8); " active="; orbitText(m.profileId,8)
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
    if type(playbackItem) <> "roAssociativeArray"
        if m.watchDiagCount <= 8 then print "[RokuPlus watch] rejected=playback-item-missing"
        return
    end if
    if sample.itemId <> playbackItem.id
        if m.watchDiagCount <= 8 then print "[RokuPlus watch] rejected=id-mismatch sample="; sampleId; " detail="; detailId
        return
    end if
    if sample.failed = true and orbitText(playbackItem.kind,16) = "episode" and rpHdOnlineProvider(playbackItem.provider) <> "" and playbackItem.hdFallbackTried <> true
        playbackItem.hdFallbackTried = true
        m.pendingEpisodeFallback = {item:playbackItem,origin:m.activePlaybackOrigin}
        m.recovering = false
        print "[RokuPlus source-fallback] trigger=automatic-playback-failure provider="; orbitText(playbackItem.provider,32); " season="; orbitInteger(playbackItem.season,999); " episode="; orbitInteger(playbackItem.episode,9999)
        m.player.callFunc("closePlayback")
        return
    end if
    m.lastPlaybackProgress = sample
    m.watchState = rpWatchUpdate(m.watchState,playbackItem,sample.position,sample.duration)
    ' Show the end card only when IntroDB gives a real credits marker.
    ' Without a confirmed marker, wait for the decoder's finished event.
    creditsStart = -1.0
    if type(m.introDbSegments) = "roAssociativeArray" and type(m.introDbSegments.outro) = "roAssociativeArray"
        outroStart = m.introDbSegments.outro.start_sec
        if GetInterface(outroStart,"ifFloat") <> invalid or GetInterface(outroStart,"ifDouble") <> invalid or GetInterface(outroStart,"ifInt") <> invalid or GetInterface(outroStart,"ifLongInt") <> invalid
            creditsStart = outroStart
        else if m.introDbSegments.outro.start_ms <> invalid
            creditsStart = m.introDbSegments.outro.start_ms / 1000.0
        end if
    end if
    if creditsStart >= 0 and sample.state <> "finished" and sample.duration > 0 and sample.position >= creditsStart
        if m.endScreenRequestId <> sample.requestId
            m.endScreenRequestId = sample.requestId
            print "[RokuPlus end-screen] credits-window position="; sample.position; " duration="; sample.duration
            preparePlaybackEndScreen()
        end if
    end if
    if sample.state = "finished"
        watchedRequest = false
        if m.endScreenWatchedRequestId <> invalid
            if m.endScreenWatchedRequestId = sample.requestId then watchedRequest = true
        end if
        if not watchedRequest
            m.endScreenWatchedRequestId = sample.requestId
            watchedAtEnd = rpWatchGet(m.watchState,playbackItem.id)
            if watchedAtEnd = invalid or watchedAtEnd.watched <> true
                m.watchState = rpWatchToggle(m.watchState,playbackItem,"watched")
                rpWatchSave(m.watchState,m.profileId)
            end if
        end if
        if m.endScreenRequestId <> sample.requestId
            m.endScreenRequestId = sample.requestId
            preparePlaybackEndScreen()
        end if
    end if
    record = rpWatchGet(m.watchState,playbackItem.id)
    refreshWatchLists = sample.state = "finished"
    if m.watchSaveClock = invalid
        saved = rpWatchSave(m.watchState,m.profileId)
        m.watchSaveClock = CreateObject("roTimespan")
        m.watchSaveClock.mark()
        m.watchSaveRetryDelayMs = rpWatchNextSaveRetryDelay(saved,m.watchSaveRetryDelayMs)
        refreshWatchLists = true
        print "[RokuPlus watch] save-first="; saved; " nextRetryMs="; m.watchSaveRetryDelayMs; " records="; m.watchState.count(); " id="; detailId; " position="; sample.position; " duration="; sample.duration
        if not saved then print "[RokuPlus watch] WARNING: first progress save failed; playback continues."
    else
        retryDelay = m.watchSaveRetryDelayMs
        if retryDelay < 1000 then retryDelay = 5000
        if m.watchSaveClock.totalMilliseconds() >= retryDelay
            saved = rpWatchSave(m.watchState,m.profileId)
            m.watchSaveClock.mark()
            m.watchSaveRetryDelayMs = rpWatchNextSaveRetryDelay(saved,retryDelay)
            refreshWatchLists = true
            print "[RokuPlus watch] save-periodic="; saved; " nextRetryMs="; m.watchSaveRetryDelayMs; " records="; m.watchState.count(); " id="; detailId; " position="; sample.position; " duration="; sample.duration
            if not saved then print "[RokuPlus watch] WARNING: periodic progress save failed; playback continues."
        end if
    end if
    if record <> invalid and m.watchDiagCount <= 8 then print "[RokuPlus watch] record id="; detailId; " position="; record.position; " duration="; record.duration; " provider="; orbitText(record.provider,32); " slug="; orbitText(record.providerSlug,200)
    ' Rebuild the derived lists only at the save cadence or on completion.
    if refreshWatchLists
        m.continueItems = rpWatchContinue(m.watchState)
        refreshHomeListItems()
    end if
end sub

sub toggleCurrentWatch(field as string)
    if m.detail = invalid then return
    toggleWatchItem(m.detail,field)
end sub

sub toggleWatchItem(item as object, field as string)
    if type(item) <> "roAssociativeArray" then return
    if not item.doesExist("id") then return
    m.watchState = rpWatchToggle(m.watchState,item,field)
    if not rpWatchSave(m.watchState,m.profileId)
        m.watchState = rpWatchLoad(m.profileId)
        m.continueItems = rpWatchContinue(m.watchState)
        refreshHomeListItems()
        m.note = "No se pudo guardar el cambio. Se restauró el último historial guardado."
        drawScreen()
        return
    end if
    m.continueItems = rpWatchContinue(m.watchState)
    refreshHomeListItems()
    record = rpWatchGet(m.watchState,item.id)
    if field = "watched"
        if record <> invalid and record.watched then m.note = "Marcada como vista." else m.note = "Marcada como no vista."
    else
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
    ' Both decoder instances report close events; only the active instance may
    ' change the scene lifecycle or consume a pending engine switch.
    if not m.player.isSameNode(event.getRoSGNode()) then return
    if m.player.active = true then return
    if m.view = "live" then return
    if m.view <> "player" then return
    cancelNextEpisodePrefetch()
    ' IntroDB lookup belongs to the active playback session; stop it when
    ' that session closes so a late response cannot update a closed player.
    if m.introDbTask <> invalid
        m.introDbTask.unobserveField("result")
        m.introDbTask.cancelRequested = true
        m.introDbTask = invalid
    end if
    m.introDbSegments = invalid
    if m.stallWatchTimer <> invalid then m.stallWatchTimer.control = "stop"
    m.stallEpisodeActive = false
    ' A source switch requested from the end screen waits for the old decoder
    ' to finish stopping before opening the other independent player instance.
    if type(m.pendingEngineSwitch) = "roAssociativeArray"
        pendingSwitch = m.pendingEngineSwitch
        m.pendingEngineSwitch = invalid
        ' Persist the previous title before changing decoder instances.
        if m.activePlaybackProfileId = m.profileId
            switchSaved = rpWatchSave(m.watchState,m.profileId)
            if not switchSaved then print "[RokuPlus watch] WARNING: engine-switch save failed."
            if m.watchSaveClock <> invalid then m.watchSaveClock.mark()
        else
            print "[RokuPlus watch] engine-switch-save-skipped=profile-mismatch"
        end if
        m.player.visible = false
        if pendingSwitch.target = "host"
            m.player = m.hostPlayer
        else
            m.player = m.standardPlayer
        end if
        print "[RokuPlus player-router] switch_ready engine="; pendingSwitch.target
        launchVideo(pendingSwitch.item,pendingSwitch.url,pendingSwitch.format)
        return
    end if
    ' A recommendation may still be resolving when the viewer presses BACK.
    ' Cancel it so a late network response cannot unexpectedly reopen playback.
    if m.busy then cancelRequest()
    m.autoplay = false
    closeSaved = false
    if m.activePlaybackProfileId = m.profileId
        closeSaved = rpWatchSave(m.watchState,m.profileId)
        if not closeSaved then print "[RokuPlus watch] WARNING: close save failed."
    else
        print "[RokuPlus watch] close-save-skipped=profile-mismatch session="; orbitText(m.activePlaybackProfileId,8); " active="; orbitText(m.profileId,8)
    end if
    closeRecord = invalid
    if type(m.activePlaybackItem) = "roAssociativeArray" and m.activePlaybackItem.doesExist("id") then closeRecord = rpWatchGet(m.watchState,m.activePlaybackItem.id)
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
    ' Return the alias to the untouched standard instance after host playback.
    m.player = m.standardPlayer
    m.view = m.viewBeforePlayer
    if type(m.pendingEpisodeFallback) = "roAssociativeArray"
        fallback = m.pendingEpisodeFallback
        m.pendingEpisodeFallback = invalid
        m.recovering = false
        fetch({operation:"find-source",item:fallback.item,returnView:m.view,origin:fallback.origin})
        return
    end if
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
    if finishedNaturally and type(m.activePlaybackItem) = "roAssociativeArray" and m.activePlaybackProfileId = m.profileId
        watchedRecord = rpWatchGet(m.watchState,m.activePlaybackItem.id)
        if watchedRecord = invalid or watchedRecord.watched <> true then m.watchState = rpWatchToggle(m.watchState,m.activePlaybackItem,"watched")
        rpWatchSave(m.watchState,m.profileId)
    end if
    m.lastPlaybackProgress = invalid
    m.activePlaybackProfileId = invalid
    m.activePlaybackItem = invalid
    m.activePlaybackOrigin = invalid
    m.continueItems = rpWatchContinue(m.watchState)
    m.note = ""
    drawScreen()
    m.top.setFocus(true)
end sub

sub showPlayerNextEpisodeError(message as string)
    if m.view <> "player" then return
    m.endScreenNextEpisodePending = false
    safeMessage = orbitText(message,320)
    if safeMessage = "" then safeMessage = "No se pudo cargar el siguiente episodio."
    m.player.endScreenData = {kind:"episode",heading:"SIGUIENTE EPISODIO",message:safeMessage,items:[]}
end sub

sub showPlayerEndError(message as string)
    if m.view <> "player" then return
    safeMessage = orbitText(message,320)
    if safeMessage = "" then safeMessage = "No se pudo abrir este título."
    m.player.endScreenData = {kind:"movie",heading:"NO SE PUDO ABRIR",message:safeMessage,items:[]}
end sub

sub cancelNextEpisodePrefetch()
    if m.nextEpisodePrefetchTask <> invalid
        m.nextEpisodePrefetchTask.unobserveField("result")
        m.nextEpisodePrefetchTask.cancelRequested = true
        m.nextEpisodePrefetchTask = invalid
    end if
    m.nextEpisodePrefetchRequestId = ""
    m.nextEpisodePrefetchParentRequestId = ""
    m.nextEpisodePrefetchParentItemId = ""
    m.nextEpisodePrefetchItemId = ""
    m.nextEpisodePrefetchAnswer = invalid
end sub

sub startNextEpisodePrefetch(item as object)
    if m.view <> "player" or type(item) <> "roAssociativeArray" then return
    if orbitText(item.kind,16) <> "episode" then return
    provider = rpHdOnlineProvider(item.provider)
    if provider = "" then return
    if orbitText(item.providerId,120) = "" and orbitText(item.providerSlug,200) = "" and orbitText(item.providerTmdbId,120) = ""
        print "[RokuPlus next-episode-prefetch] skipped=provider-identity-missing"
        return
    end if
    cancelNextEpisodePrefetch()
    requestId = CreateObject("roDeviceInfo").getRandomUUID()
    task = CreateObject("roSGNode","HdCatalogTask")
    if task = invalid then return
    task.operation = "resolve"
    task.kind = "episode"
    task.provider = provider
    task.item = item
    task.attempt = orbitInteger(item.hdAttempt,99)
    task.requestId = requestId
    task.observeField("result","nextEpisodePrefetchResult")
    m.nextEpisodePrefetchTask = task
    m.nextEpisodePrefetchRequestId = requestId
    m.nextEpisodePrefetchParentRequestId = m.activePlaybackRequestId
    m.nextEpisodePrefetchParentItemId = orbitText(m.detail.id,180)
    m.nextEpisodePrefetchItemId = orbitText(item.id,180)
    print "[RokuPlus next-episode-prefetch] start provider="; provider; " season="; orbitInteger(item.season,999); " episode="; orbitInteger(item.episode,9999)
    task.control = "RUN"
end sub

sub nextEpisodePrefetchResult(event as object)
    if m.nextEpisodePrefetchTask = invalid then return
    if not m.nextEpisodePrefetchTask.isSameNode(event.getRoSGNode()) then return
    answer = event.getData()
    m.nextEpisodePrefetchTask.unobserveField("result")
    m.nextEpisodePrefetchTask = invalid
    if type(answer) <> "roAssociativeArray" then return
    if answer.requestId <> m.nextEpisodePrefetchRequestId then return
    if m.view <> "player" or m.activePlaybackRequestId <> m.nextEpisodePrefetchParentRequestId then return
    if type(m.detail) <> "roAssociativeArray" or orbitText(m.detail.id,180) <> m.nextEpisodePrefetchParentItemId then return
    if answer.ok = true
        m.nextEpisodePrefetchAnswer = {itemId:m.nextEpisodePrefetchItemId,parentRequestId:m.nextEpisodePrefetchParentRequestId,answer:answer}
        print "[RokuPlus next-episode-prefetch] ready=1 format="; orbitText(answer.streamFormat,12)
    else
        print "[RokuPlus next-episode-prefetch] ready=0 reason="; orbitText(answer.message,160)
    end if
    m.nextEpisodePrefetchRequestId = ""
    m.nextEpisodePrefetchItemId = ""
end sub

sub preparePlaybackEndScreen()
    if m.view <> "player" or m.detail = invalid then return
    if m.detail.kind = "episode"
        nextItem = rpFindNextEpisode()
        items = []
        heading = "SERIE FINALIZADA"
        if nextItem <> invalid
            items.push(nextItem)
            heading = "SIGUIENTE EPISODIO"
            startNextEpisodePrefetch(nextItem)
        end if
        if nextItem = invalid and m.series <> invalid and (usesOnlineHd() or rpIsOnlineHdItem(m.series))
            ' Continue Watching may restore an episode without its parent season cache.
            ' Load the current season once before declaring the series finished.
            for each currentSeasonEntry in m.series.seasons
                if currentSeasonEntry.number = m.detail.season
                    if currentSeasonEntry.loaded <> true and not m.endScreenNextEpisodePending
                        m.endScreenNextEpisodePending = true
                        m.player.endScreenData = {kind:"episode",heading:"SIGUIENTE EPISODIO",message:"Buscando el siguiente episodio...",items:[]}
                        fetch({operation:"episodes",item:m.series,season:currentSeasonEntry.number})
                        return
                    end if
                end if
            end for
            if m.series.seasons.count() > 1
                for seasonIndex = 0 to m.series.seasons.count()-2
                    currentSeason = m.series.seasons[seasonIndex]
                if currentSeason.number = m.detail.season
                    followingSeason = m.series.seasons[seasonIndex+1]
                    if followingSeason.loaded <> true and not m.endScreenNextEpisodePending
                        m.endScreenNextEpisodePending = true
                        m.player.endScreenData = {kind:"episode",heading:"SIGUIENTE EPISODIO",message:"Buscando el siguiente episodio...",items:[]}
                        fetch({operation:"episodes",item:m.series,season:followingSeason.number})
                        return
                    end if
                end if
                end for
            end if
        end if
        m.player.endScreenData = {kind:"episode",heading:heading,items:items}
    else if m.detail.kind = "movie"
        similar = rpSimilarMovies(m.detail)
        heading = "PELÍCULAS SIMILARES"
        if similar.count() = 0
            similar = rpFallbackMovies(m.detail)
            heading = "MÁS PELÍCULAS PARA VER"
        end if
        m.player.endScreenData = {kind:"movie",heading:heading,items:similar}
    end if
end sub

sub playerEndSelection(event as object)
    selection = event.getData()
    if m.view <> "player" or type(selection) <> "roAssociativeArray" then return
    if selection.requestId <> m.activePlaybackRequestId then return
    if type(selection.item) <> "roAssociativeArray" then return
    item = selection.item
    print "[RokuPlus end-screen] selected title="; orbitText(item.title,180); " kind="; orbitText(item.kind,20)
    ' Keep m.view="player" while metadata/source resolution runs so BACK and
    ' the player lifecycle continue to be routed to the active decoder.
    m.detail = item
    m.detail.hdAttempt = 0
    m.lastPlaybackProgress = invalid
    ' Keep the current request end-screen identity until launchVideo installs the next request.
    if item.kind = "episode"
        m.detailOrigin = "episodes"
        m.autoplay = false
        prefetched = invalid
        if type(m.nextEpisodePrefetchAnswer) = "roAssociativeArray"
            if m.nextEpisodePrefetchParentRequestId = selection.requestId and m.nextEpisodePrefetchAnswer.itemId = item.id
                prefetched = m.nextEpisodePrefetchAnswer.answer
            end if
        end if
        if type(prefetched) = "roAssociativeArray" and prefetched.ok = true
            print "[RokuPlus next-episode-prefetch] reuse=1 title="; orbitText(item.title,120)
            m.detail.hdAutoRetry = 0
            if type(prefetched.mediaHeaders) = "roAssociativeArray" then m.detail.mediaHeaders = prefetched.mediaHeaders
            m.detail.playbackEngine = "standard"
            if prefetched.doesExist("playbackEngine") and prefetched.playbackEngine = "host" then m.detail.playbackEngine = "host"
            m.detail.hdAttempt = orbitInteger(prefetched.attemptUsed,99)
            m.pendingSubtitleTracks = prefetched.subtitleTracks
            m.pendingSelectedSubtitleGroup = orbitText(prefetched.selectedSubtitleGroup,100)
            m.pendingSourceHost = orbitText(prefetched.sourceHost,24)
            m.pendingSegmentUrls = prefetched.segmentUrls
            m.pendingSegmentDurations = prefetched.segmentDurations
            m.pendingFallbackSegmentUrls = prefetched.fallbackSegmentUrls
            m.pendingFallbackSegmentDurations = prefetched.fallbackSegmentDurations
            m.pendingFallbackTsRelay = false
            if prefetched.fallbackTsRelayEnabled = true then m.pendingFallbackTsRelay = true
            m.pendingTsRelay = false
            if prefetched.tsRelayEnabled = true then m.pendingTsRelay = true
            m.nextEpisodePrefetchAnswer = invalid
            launchVideo(m.detail,prefetched.url,prefetched.streamFormat)
        else
            cancelNextEpisodePrefetch()
            playDetail()
        end if
    else if item.kind = "movie"
        m.detailOrigin = "home"
        if usesOnlineHd() or rpIsOnlineHdItem(item)
            m.autoplay = true
            fetch({operation:"meta",item:item})
        else
            m.autoplay = false
            playDetail()
        end if
    end if
end sub

function rpGenreNames(item as dynamic) as object
    values = []
    if type(item) <> "roAssociativeArray" then return values
    source = invalid
    if type(item.genres) = "roArray" then source = item.genres
    if source = invalid and type(item.genre) = "roArray" then source = item.genre
    if type(source) = "roArray"
        for each entry in source
            genreName = ""
            if GetInterface(entry,"ifString") <> invalid
                genreName = lcase(entry.trim())
            else if type(entry) = "roAssociativeArray" and GetInterface(entry.name,"ifString") <> invalid
                genreName = lcase(entry.name.trim())
            end if
            if genreName <> ""
                exists = false
                for each current in values
                    if current = genreName then exists = true
                end for
                if not exists then values.push(genreName)
            end if
        end for
    else if GetInterface(item.genre,"ifString") <> invalid
        genreName = lcase(item.genre.trim())
        if genreName <> "" then values.push(genreName)
    end if
    return values
end function

function rpSharedGenreScore(first as dynamic, second as dynamic) as integer
    leftGenres = rpGenreNames(first)
    rightGenres = rpGenreNames(second)
    score = 0
    for each leftGenre in leftGenres
        for each rightGenre in rightGenres
            if leftGenre = rightGenre then score++
        end for
    end for
    return score
end function

function rpSimilarMovies(current as object) as object
    candidates = []
    for each source in [m.features,m.pageTitles,m.titles]
        if type(source) = "roArray"
            for each candidate in source
                if type(candidate) = "roAssociativeArray"
                    if candidate.kind = "movie" and candidate.id <> current.id then candidates.push(candidate)
                end if
            end for
        end if
    end for
    uniqueCandidates = orbitUniqueCatalogItems(candidates)
    ranked = []
    for each candidate in uniqueCandidates
        score = rpSharedGenreScore(current,candidate)
        if score > 0 then ranked.push({item:candidate,score:score})
    end for
    for i = 1 to ranked.count()-1
        position = i
        while position > 0
            if ranked[position-1].score >= ranked[position].score then exit while
            swap = ranked[position-1]
            ranked[position-1] = ranked[position]
            ranked[position] = swap
            position--
        end while
    end for
    results = []
    for each entry in ranked
        results.push(entry.item)
        if results.count() >= 6 then exit for
    end for
    print "[RokuPlus end-screen] similar-movies="; results.count()
    return results
end function

function rpFallbackMovies(current as object) as object
    candidates = []
    for each source in [m.features,m.pageTitles,m.titles]
        if type(source) = "roArray"
            for each candidate in source
                if type(candidate) = "roAssociativeArray"
                    if candidate.kind = "movie" and candidate.id <> current.id then candidates.push(candidate)
                end if
            end for
        end if
    end for
    uniqueCandidates = orbitUniqueCatalogItems(candidates)
    results = []
    for each candidate in uniqueCandidates
        results.push(candidate)
        if results.count() >= 6 then exit for
    end for
    return results
end function

function rpFindNextEpisode() as dynamic
    if m.series = invalid or m.detail = invalid then return invalid
    if m.detail.kind <> "episode" then return invalid
    episodeSeriesId = ""
    if GetInterface(m.detail.imdbId,"ifString") <> invalid then episodeSeriesId = m.detail.imdbId
    if episodeSeriesId <> "" and m.series.doesExist("id")
        if episodeSeriesId <> m.series.id then return invalid
    end if
    episodeSeriesTitle = ""
    if GetInterface(m.detail.seriesTitle,"ifString") <> invalid then episodeSeriesTitle = m.detail.seriesTitle
    if episodeSeriesTitle <> ""
        if lcase(episodeSeriesTitle) <> lcase(m.series.title) then return invalid
    end if
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
    if type(m.detail) = "roAssociativeArray" and orbitText(m.detail.kind,16) = "episode" and rpHdOnlineProvider(m.detail.provider) <> "" and m.detail.hdFallbackTried <> true
        m.detail.hdFallbackTried = true
        m.pendingEpisodeFallback = {item:m.detail,origin:m.detailOrigin}
        m.recovering = false
        print "[RokuPlus source-fallback] trigger=playback-error provider="; orbitText(m.detail.provider,32); " season="; orbitInteger(m.detail.season,999); " episode="; orbitInteger(m.detail.episode,9999)
        m.player.callFunc("closePlayback")
        return
    end if
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
    result = lcase(result)
    ' Catalog providers may return genre names in English while the Roku UI
    ' displays Spanish category labels. Add equivalent labels for matching.
    genreAliases = [
        ["action","acción"], ["adventure","aventura"], ["animation","animación"],
        ["comedy","comedia"], ["crime","crimen"], ["documentary","documental"],
        ["drama","drama"], ["fantasy","fantasía"], ["history","historia"],
        ["mystery","misterio"], ["romance","romance"], ["science fiction","ciencia ficción"],
        ["sci-fi","ciencia ficción"], ["thriller","suspenso"], ["suspense","suspenso"],
        ["horror","terror"], ["war","bélica"], ["western","western"]
    ]
    for each alias in genreAliases
        if instr(1,result,alias[0]) > 0 and instr(1,result,alias[1]) = 0
            result += " " + alias[1]
        end if
    end for
    return result
end function

sub applyGenreFilter()
    m.titles = []
    genreMatchCount = 0
    genreLoggedCount = 0
    print "[RokuPlus genres] filter="; m.genreFilter; " catalog_items="; m.pageTitles.count()
    for each item in m.pageTitles
        itemGenres = browseItemGenres(item)
        include = true
        if m.genreFilter <> "Todos"
            include = instr(1,itemGenres,lcase(m.genreFilter)) > 0
        end if
        if include
            m.titles.push(item)
            genreMatchCount++
        end if
        if genreLoggedCount < 30
            print "[RokuPlus genres] provider="; orbitText(item.provider,24); " title="; orbitText(item.title,80); " genres="; itemGenres
            genreLoggedCount++
        end if
    end for
    print "[RokuPlus genres] matches="; genreMatchCount; " filter="; m.genreFilter
    ' The provider's default catalog order is its popularity ranking.
    ' Newest sorts by the year metadata supplied by the catalog.
    if m.catalogSort = "recent" and m.titles.count() > 1
        for i = 0 to m.titles.count()-2
            newest = i
            newestYear = orbitText(m.titles[i].year,4)
            for j = i+1 to m.titles.count()-1
                candidateYear = orbitText(m.titles[j].year,4)
                if candidateYear > newestYear
                    newest = j
                    newestYear = candidateYear
                end if
            end for
            if newest <> i
                swapItem = m.titles[i]
                m.titles[i] = m.titles[newest]
                m.titles[newest] = swapItem
            end if
        end for
    end if
    m.cursor = 0
end sub

sub openGenreFilter()
    choices = ["Más populares","Más recientes","Todos"]
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
    if choices.count() = 3
        m.note = "Esta página no contiene géneros disponibles para filtrar."
        drawScreen()
        return
    end if
    choices.push("Cancelar")
    m.genreChoices = choices
    dialog = CreateObject("roSGNode","StandardMessageDialog")
    dialog.title = "Categorías y orden"
    dialog.message = "Elige un género o cambia el orden de las películas cargadas."
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
        if selected = "Más recientes"
            m.catalogSort = "recent"
            m.genreFilter = "Todos"
        else if selected = "Más populares"
            m.catalogSort = "popular"
            m.genreFilter = "Todos"
        else
            m.genreFilter = selected
        end if
        applyGenreFilter()
        m.note = ""
    end if
    m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
end sub

sub genreFilterDismissed(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
end sub

sub searchDeleteHoldElapsed()
    if m.view <> "search-keyboard" or not m.searchDeleteHeld then return
    m.searchText = ""
    m.searchDeleteCleared = true
    refreshSearchSuggestions()
    drawScreen()
end sub

sub openMobileSearchInput()
    if m.view <> "search-keyboard" or m.dialogBox <> invalid then return
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    dialog.title = "Escribir desde el celular"
    dialog.message = ["Usa el teclado de Roku o la entrada de texto de la app móvil Roku."]
    dialog.keyboardDomain = "generic"
    dialog.text = m.searchText
    dialog.buttons = ["Usar texto","Cancelar"]
    dialog.observeField("buttonSelected","mobileSearchInputChosen")
    dialog.observeField("wasClosed","mobileSearchInputDismissed")
    m.dialogBox = dialog
    m.dialogPurpose = "mobile-search"
    m.top.dialog = dialog
end sub

sub mobileSearchInputChosen(event as object)
    if m.dialogBox = invalid or not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    choice = event.getData()
    entered = left(m.dialogBox.text.trim(),120)
    releaseDialog()
    if choice = 0
        m.searchText = entered
        refreshSearchSuggestions()
    end if
    if m.view = "search-keyboard"
        drawScreen()
        m.top.setFocus(true)
    end if
end sub

sub mobileSearchInputDismissed(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    if m.view = "search-keyboard"
        drawScreen()
        m.top.setFocus(true)
    end if
    scheduleDialogFocusRestore()
end sub

sub openSearch()
    cancelRequest()
    m.searchOriginView = m.view
    if m.searchOriginView <> "home" and m.searchOriginView <> "browse" then m.searchOriginView = "home"
    m.searchText = m.query
    m.searchCursor = 0
    m.searchSuggestions = []
    m.view = "search-keyboard"
    m.zone = "search-key"
    refreshSearchSuggestions()
    drawScreen()
    m.top.setFocus(true)
end sub

sub addSearchSuggestion(item as object, query as string)
    if type(item) <> "roAssociativeArray" or not item.doesExist("title") then return
    title = orbitText(item.title,180)
    if title = "" then return
    lowered = lcase(title)
    if instr(1,lowered,query) = 0 then return
    for each existing in m.searchSuggestions
        if lcase(orbitText(existing.title,180)) = lowered then return
    end for
    score = 2
    if left(lowered,len(query)) = query then score = 1
    insertAt = m.searchSuggestions.count()
    for i = 0 to m.searchSuggestions.count()-1
        if score < m.searchSuggestionScores[i]
            insertAt = i
            exit for
        end if
    end for
    if insertAt < 5
        ' roArray has no Insert() method. Append, then shift entries right.
        m.searchSuggestions.push(item)
        m.searchSuggestionScores.push(score)
        lastIndex = m.searchSuggestions.count()-1
        for moveIndex = lastIndex to insertAt+1 step -1
            m.searchSuggestions[moveIndex] = m.searchSuggestions[moveIndex-1]
            m.searchSuggestionScores[moveIndex] = m.searchSuggestionScores[moveIndex-1]
        end for
        m.searchSuggestions[insertAt] = item
        m.searchSuggestionScores[insertAt] = score
        if m.searchSuggestions.count() > 5
            m.searchSuggestions.delete(5)
            m.searchSuggestionScores.delete(5)
        end if
    end if
end sub

sub refreshSearchSuggestions()
    m.searchSuggestions = []
    m.searchSuggestionScores = []
    query = lcase(m.searchText.trim())
    if query = "" then return
    pools = [m.features,m.homeSeries,m.homeListItems,m.continueItems,m.pageTitles]
    for each pool in pools
        if type(pool) = "roArray"
            for each item in pool
                addSearchSuggestion(item,query)
            end for
        end if
    end for
    if type(m.hdLibrary) = "roAssociativeArray"
        for each field in ["movies","series"]
            if type(m.hdLibrary[field]) = "roArray"
                for each item in m.hdLibrary[field]
                    addSearchSuggestion(item,query)
                end for
            end if
        end for
    end if
end sub

sub chooseSearchSuggestion(index as integer)
    if index < 0 or index >= m.searchSuggestions.count() then return
    item = m.searchSuggestions[index]
    m.searchText = orbitText(item.title,120)
    m.searchCursor = index
    m.zone = "search-suggestion"
    ' Suggestions only complete the query. Global discovery must return Cinemeta
    ' records before a detail is opened, so Play can search all playback sources.
    print "[RokuPlus discovery] action=suggestion-submit title="; m.searchText
    submitGlobalSearch()
end sub

sub submitGlobalSearch()
    query = left(m.searchText.trim(),120)
    searchQuery = lcase(query)
    m.query = query
    m.genreFilter = "Todos"
    m.pageTitles = []
    m.titles = []
    m.offset = 0
    m.nextOffset = 0
    m.more = false
    m.cursor = 0
    m.view = "browse"
    m.zone = "grid"
    if query = ""
        m.kind = "movie"
        loadBrowsePage(0)
    else if m.catalogMode = "hd" and not usesOnlineHd()
        m.kind = "all"
        loadBrowsePage(0)
    else
        m.kind = "movie"
        cacheKey = m.catalogMode + "|" + m.hdProvider + "|all|" + searchQuery
        if type(m.searchCache) = "roAssociativeArray" and m.searchCache.key = cacheKey and m.searchCache.clock <> invalid
            cacheAge = m.searchCache.clock.totalMilliseconds()
            if cacheAge >= 0 and cacheAge < 120000
                m.pageTitles = orbitUniqueCatalogItems(m.searchCache.items)
                applyGenreFilter()
                m.offset = 0
                m.nextOffset = 0
                m.more = false
                m.cursor = 0
                m.note = ""
                drawScreen()
                m.top.setFocus(true)
                return
            end if
        end if
        fetch({operation:"search",kind:"all",query:searchQuery,offset:0})
    end if
    drawScreen()
    m.top.setFocus(true)
end sub

sub closeSearchKeyboard()
    m.view = m.searchOriginView
    if m.view = "home" then m.zone = "hero" else m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
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
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    if m.view <> "live" then return
    m.zone = "live-search"
    m.liveSearchCursor = 0
    if not m.livePreviewOpen and m.channels.count() > 0 then scheduleLivePreview()
    drawScreen()
    m.top.setFocus(true)
    scheduleDialogFocusRestore()
end sub

sub clearLiveSearch()
    m.liveQuery = ""
    m.liveSearchCursor = 0
    m.zone = "live-search"
    m.note = ""
    refreshLiveList(false)
    drawScreen()
end sub


sub scheduleDialogFocusRestore()
    if m.dialogFocusTimer = invalid then return
    m.dialogFocusTimer.control = "stop"
    m.dialogFocusTimer.duration = 0.2
    m.dialogFocusTimer.control = "start"
end sub

sub dialogFocusRestoreElapsed()
    ' Roku's native keyboard may release focus one event-loop turn after wasClosed.
    ' Restore focus only after the dialog node has been detached from the Scene.
    if m.dialogBox <> invalid then return
    if m.top.dialog <> invalid then return
    if m.view = "player" then return
    m.top.setFocus(true)
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
    m.searchText = left(m.dialogBox.text.trim(),120)
    choice = event.getData()
    releaseDialog()
    if choice = 0
        submitGlobalSearch()
    else if m.titles.count() = 0
        loadBrowsePage(0)
    end if
end sub

sub searchDismissed(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    if m.titles.count() = 0 then loadBrowsePage(0)
    m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
    scheduleDialogFocusRestore()
end sub

sub goHome(restoreHomeHero = false as boolean)
    stopLivePreview()
    if m.noteTimer <> invalid then m.noteTimer.control = "stop"
    cancelRequest()
    m.note = ""
    m.view = "home"
    m.nav = 0
    m.zone = "hero"
    m.hero = 0
    if restoreHomeHero
        m.discoveryOffset = m.detailHomeDiscoveryOffset
        if m.discoveryOffset < 0 then m.discoveryOffset = 0
        if m.features.count() > 0 and m.discoveryOffset >= m.features.count() then m.discoveryOffset = m.features.count()-1
        if m.detailHomeZone = "hero" and m.features.count() > 0
            m.zone = "hero"
            m.hero = m.detailHomeHero
            if m.hero < 0 or m.hero > 1 then m.hero = 0
        else if m.detailHomeZone = "continue" and m.continueItems.count() > 0
            m.zone = "continue"
            m.cover = m.detailHomeCover
            if m.cover < 0 then m.cover = 0
            if m.cover >= m.continueItems.count() then m.cover = m.continueItems.count()-1
        else if m.detailHomeZone = "covers" and m.features.count() > 0
            m.zone = "covers"
            m.cover = m.detailHomeCover
            if m.cover < 0 then m.cover = 0
            if m.cover > 5 then m.cover = 5
            if m.discoveryOffset + m.cover >= m.features.count() then m.cover = m.features.count()-1-m.discoveryOffset
            if m.cover < 0 then m.cover = 0
        else if m.detailHomeZone = "home-list" and m.homeListItems.count() > 0
            m.zone = "home-list"
            m.listCover = m.detailHomeListCover
            if m.listCover < 0 then m.listCover = 0
            if m.listCover >= m.homeListItems.count() then m.listCover = m.homeListItems.count()-1
        else if m.detailHomeZone = "home-series" and m.homeSeries.count() > 0
            m.zone = "home-series"
            m.seriesCover = m.detailHomeSeriesCover
            if m.seriesCover < 0 then m.seriesCover = 0
            if m.seriesCover >= m.homeSeries.count() then m.seriesCover = m.homeSeries.count()-1
        end if
    end if
    m.detailHomeHeroValid = false
    drawScreen()
    m.top.setFocus(true)
end sub

sub returnOneStep()
    m.note = ""
    if m.view = "source-resolving"
        m.sourceLaunchPending = false
        m.view = "detail"
        m.zone = "action"
        drawScreen()
        return
    end if
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
        else if m.detailOrigin = "search"
            m.view = "search-keyboard"
            m.zone = "search-suggestion"
        else
            goHome(m.detailOrigin = "home")
            return
        end if
    else if m.view = "episodes"
        if m.seriesOrigin = "browse"
            m.view = "browse"
            m.zone = "grid"
        else
            m.detail = m.series
            m.detailOrigin = m.seriesOrigin
            m.view = "detail"
            m.zone = "action"
            m.action = 0
        end if
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

sub refreshHomeListItems()
    m.homeListItems = []
    if type(m.watchState) <> "roArray" then return
    for each record in m.watchState
        if type(record) = "roAssociativeArray"
            if record.doesExist("listed")
                if record.listed = true
                    m.homeListItems.push(record)
                    if m.homeListItems.count() >= 6 then exit for
                end if
            end if
        end if
    end for
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
    refreshHomeListItems()
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
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    m.view = "profiles"
    m.zone = "profiles"
    drawScreen()
    m.top.setFocus(true)
    scheduleDialogFocusRestore()
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
    if not rpWatchSave(m.watchState,m.profileId)
        m.watchState = rpWatchLoad(m.profileId)
        m.continueItems = rpWatchContinue(m.watchState)
        refreshHomeListItems()
        openLibrary(m.libraryMode)
        m.note = "No se pudo eliminar el título. Se conservó el último historial guardado."
        drawScreen()
        return
    end if
    m.continueItems = rpWatchContinue(m.watchState)
    refreshHomeListItems()
    openLibrary(m.libraryMode)
    m.note = "Título eliminado de este perfil."
    drawScreen()
end sub


sub openInvidiousSearch()
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    if dialog = invalid then return
    dialog.title = "Buscar en YouTube · Invidious"
    dialog.text = m.invidiousQuery
    dialog.buttons = ["Buscar","Cancelar"]
    dialog.observeField("buttonSelected","invidiousSearchChosen")
    dialog.observeField("wasClosed","invidiousSearchDismissed")
    m.dialogBox = dialog
    m.dialogPurpose = "invidious-search"
    m.top.dialog = dialog
end sub

sub invidiousSearchChosen(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    query = left(m.dialogBox.text.trim(),100)
    choice = event.getData()
    releaseDialog()
    if choice <> 0 or query = "" then return
    m.invidiousQuery = query
    m.invidiousItems = []
    m.invidiousCursor = 0
    m.view = "invidious"
    m.zone = "invidious"
    m.note = ""
    m.request = CreateObject("roDeviceInfo").getRandomUUID()
    task = CreateObject("roSGNode","InvidiousTask")
    task.operation = "search"
    task.query = query
    task.requestId = m.request
    task.observeField("result","fetched")
    task.observeField("state","catalogState")
    m.job = task
    m.pending = {operation:"invidious-search"}
    m.busy = true
    m.deadline.duration = 45
    m.deadlineMs = 45000
    m.deadlineStart = CreateObject("roTimespan")
    m.deadlineStart.mark()
    drawScreen()
    m.deadline.control = "start"
    task.control = "RUN"
end sub

sub invidiousSearchDismissed(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    if m.view = "settings" then drawScreen()
    scheduleDialogFocusRestore()
end sub

sub startInvidiousResolve(item as object)
    if type(item) <> "roAssociativeArray" then return
    m.request = CreateObject("roDeviceInfo").getRandomUUID()
    task = CreateObject("roSGNode","InvidiousTask")
    task.operation = "resolve"
    task.videoId = item.id
    task.requestId = m.request
    task.observeField("result","fetched")
    task.observeField("state","catalogState")
    m.job = task
    m.pending = {operation:"invidious-resolve",item:item}
    m.busy = true
    m.note = ""
    m.deadline.duration = 45
    m.deadlineMs = 45000
    m.deadlineStart = CreateObject("roTimespan")
    m.deadlineStart.mark()
    drawScreen()
    m.deadline.control = "start"
    task.control = "RUN"
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
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    openSettings()
    scheduleDialogFocusRestore()
end sub

sub openApiKeySettings(service as string)
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    if dialog = invalid then return
    if service = "tmdb"
        dialog.title = "TMDB API Key"
        dialog.message = ["Pega tu clave API de TMDB. Se guarda localmente en este Roku."]
    else
        dialog.title = "Subtitle Search Engine API Key"
        dialog.message = ["Pega tu clave API de Subtitle Search Engine. Se guarda localmente en este Roku."]
    end if
    dialog.buttons = ["Guardar","Borrar","Cancelar"]
    dialog.keyboardDomain = "password"
    dialog.text = ""
    if dialog.textEditBox <> invalid
        dialog.textEditBox.secureMode = true
        dialog.textEditBox.secureLastCharacter = true
    end if
    dialog.observeField("buttonSelected","apiKeySettingsChosen")
    dialog.observeField("wasClosed","apiKeySettingsDismissed")
    m.dialogBox = dialog
    m.dialogPurpose = "api-key-" + service
    m.top.dialog = dialog
end sub

sub apiKeySettingsChosen(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    choice = event.getData()
    service = "tmdb"
    if m.dialogPurpose = "api-key-subtitle" then service = "subtitle"
    value = m.dialogBox.text
    if GetInterface(value,"ifString") = invalid then value = ""
    value = value.trim()
    message = ""
    if choice = 0
        if value = "" or len(value) > 512 or instr(1,value,chr(10)) > 0 or instr(1,value,chr(13)) > 0
            message = "La API Key está vacía o no es válida."
        else if service = "tmdb"
            if rpSaveTmdbApiKey(value) then message = "TMDB API Key guardada en este Roku." else message = "No se pudo guardar la clave de TMDB."
        else
            if rpSaveSubtitleSearchEngineApiKey(value) then message = "Subtitle Search Engine API Key guardada en este Roku." else message = "No se pudo guardar la clave de subtítulos."
        end if
    else if choice = 1
        if service = "tmdb"
            if rpClearTmdbApiKey() then message = "TMDB API Key borrada." else message = "No se pudo borrar la clave de TMDB."
        else
            if rpClearSubtitleSearchEngineApiKey() then message = "Subtitle Search Engine API Key borrada." else message = "No se pudo borrar la clave de subtítulos."
        end if
    end if
    releaseDialog()
    openSettings()
    m.note = message
    drawScreen()
    m.top.setFocus(true)
end sub

sub apiKeySettingsDismissed(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog(true)
    openSettings()
    scheduleDialogFocusRestore()
end sub

sub openCredits()
    m.creditsPages = []
    text = "ROKU PLUS - CATALOGO HD" + chr(10) + chr(10) + "CORTOS DE BLENDER STUDIO / BLENDER INSTITUTE" + chr(10) + "Caminandes: Llama Drama, Gran Dillama y Llamigos; Glass Half." + chr(10) + "Los cortos se enlazan desde las fuentes oficiales bajo licencia CC BY 4.0." + chr(10) + "https://creativecommons.org/licenses/by/4.0/" + chr(10) + chr(10) + "NASA EN ESPANOL - ARCHIVO 2023" + chr(10) + "Ocho capsulas documentales del archivo de NASA / Goddard Space Flight Center." + chr(10) + "El material de NASA puede incluir excepciones y contenido de terceros." + chr(10) + "Condiciones de uso: https://www.nasa.gov/nasa-brand-center/images-and-media/" + chr(10) + "NASA no patrocina ni respalda esta aplicacion."
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
    if not updateHomeHero() then drawScreen()
end sub

sub changeHero(direction as integer)
    if type(m.features) <> "roArray" or m.features.count() < 2 then return
    m.heroFeature = m.heroFeature + direction
    if m.heroFeature < 0 then m.heroFeature = m.features.count()-1
    if m.heroFeature >= m.features.count() then m.heroFeature = 0
    if m.heroRotation <> invalid then m.heroRotation.control = "stop": m.heroRotation.control = "start"
    if not updateHomeHero() then drawScreen()
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
    cacheKey = m.catalogMode + "|" + m.hdProvider + "|" + m.catalogSort
    if type(m.homeCache) = "roAssociativeArray" and m.homeCache.doesExist(cacheKey)
        cached = m.homeCache[cacheKey]
        if type(cached) = "roAssociativeArray" and cached.doesExist("hasMovies") and cached.doesExist("hasSeries") and cached.hasMovies and cached.hasSeries
            age = cached.clock.totalMilliseconds()
            if age >= 0 and age < 300000
                m.features = cached.movies
                m.homeSeries = cached.series
                m.discoveryOffset = 0
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
    m.discoveryOffset = 0
    startHomeCatalogTask("movie",0)
    startHomeCatalogTask("series",0)
end sub

sub startHomeCatalogTask(kind as string, skip as integer)
    taskName = "CatalogTask"
    if usesOnlineHd() then taskName = "HdCatalogTask"
    task = CreateObject("roSGNode",taskName)
    if usesOnlineHd() then task.provider = m.hdProvider
    request = CreateObject("roDeviceInfo").getRandomUUID()
    task.operation = "catalog"
    if usesOnlineHd()
        task.operation = "cinemeta-catalog"
        task.attempt = 0
        if m.catalogSort = "recent" then task.attempt = 1
    end if
    task.kind = kind
    task.skip = skip
    task.requestId = request
    task.observeField("result","homeFetched")
    task.observeField("state","homeStopped")
    m.homeJobs.push({node:task,request:request,kind:kind,skip:skip,mode:m.catalogMode,provider:m.hdProvider,sort:m.catalogSort})
    task.control = "RUN"
end sub

sub catalogPosterLoadStatusChanged(event as object)
    poster = event.getRoSGNode()
    status = event.getData()
    if type(m.catalogFadePosters) <> "roArray" then return
    for each entry in m.catalogFadePosters
        if entry.poster.isSameNode(poster)
            if status = "ready"
                entry.poster.unobserveField("loadStatus")
                entry.ready = true
                if m.catalogFadeTimer <> invalid then m.catalogFadeTimer.control = "start"
            else if status = "failed"
                entry.poster.unobserveField("loadStatus")
                entry.poster.opacity = 1.0
                entry.done = true
            end if
            return
        end if
    end for
end sub

sub catalogFadeTick(event as object)
    if type(m.catalogFadePosters) <> "roArray" or m.catalogFadePosters.count() = 0
        m.catalogFadeTimer.control = "stop"
        return
    end if
    m.catalogFadeStep = m.catalogFadeStep + 1
    allDone = true
    for each entry in m.catalogFadePosters
        if entry.ready and not entry.done
            if m.catalogFadeStep > entry.delay
                entry.step = entry.step + 1
                opacity = entry.step / 8.0
                if opacity >= 1.0
                    opacity = 1.0
                    entry.done = true
                else
                    allDone = false
                end if
                entry.poster.opacity = opacity
                entry.poster.translation = [28 - (entry.step * 3.5),0]
            else
                allDone = false
            end if
        else if not entry.done
            allDone = false
        end if
    end for
    if allDone
        m.catalogFadeTimer.control = "stop"
        m.catalogFadePosters = []
    end if
end sub

sub pageTransitionTick(event as object)
    if m.view = "player"
        m.pageTransitionTimer.control = "stop"
        return
    end if
    m.pageTransitionStep++
    if m.pageTransitionStep >= 6
        m.canvas.translation = [0,0]
        m.canvas.opacity = 1.0
        m.pageTransitionTimer.control = "stop"
        return
    end if
    m.canvas.translation = [48-m.pageTransitionStep*8,0]
    m.canvas.opacity = 0.70 + m.pageTransitionStep*0.05
end sub

sub settleDiscoveryForFocus()
    if not m.discoveryAnimating then return
    if m.discoveryRotation <> invalid then m.discoveryRotation.control = "stop"
    if type(m.discoveryPosters) = "roArray"
        for i = 0 to m.discoveryPosters.count()-1
            poster = m.discoveryPosters[i]
            if poster <> invalid then poster.translation = [258+i*270,m.discoveryRowY]
        end for
    end if
    m.discoverySlideStep = 0
    m.discoveryAnimating = false
    if m.discoveryRotation <> invalid
        m.discoveryRotation.duration = 3.5
        m.discoveryRotation.control = "start"
        m.discoveryRotationActive = true
    end if
end sub

sub discoveryRotationTick(event as object)
    if m.view <> "home" then return
    if type(m.features) <> "roArray" or m.features.count() <= 6 then return
    if m.zone = "covers" and not m.discoveryAnimating then return
    if type(m.discoveryPosters) <> "roArray" or m.discoveryPosters.count() <> 7 then return

    if not m.discoveryAnimating
        m.discoveryAnimating = true
        m.discoverySlideStep = 0
        m.discoveryRotation.duration = 0.08
    end if

    m.discoverySlideStep++
    for i = 0 to 6
        poster = m.discoveryPosters[i]
        poster.translation = [poster.translation[0]-45,m.discoveryRowY]
    end for

    if m.discoverySlideStep >= 6
        recycled = m.discoveryPosters[0]
        nextPosters = []
        for i = 1 to 6
            nextPosters.push(m.discoveryPosters[i])
        end for
        m.discoveryOffset++
        if m.discoveryOffset >= m.features.count() then m.discoveryOffset = 0
        nextIndex = (m.discoveryOffset+6) mod m.features.count()
        nextItem = m.features[nextIndex]
        nextUri = nextItem.background
        if nextUri = "" then nextUri = nextItem.poster
        recycled.uri = themeAsset(nextUri)
        recycled.translation = [1878,m.discoveryRowY]
        nextPosters.push(recycled)
        m.discoveryPosters = nextPosters
        m.discoverySlideStep = 0
        m.discoveryAnimating = false
        m.discoveryRotation.duration = 3.5
    end if
end sub

sub invalidateHomeCacheRow(entry as object)
    cacheKey = entry.mode + "|" + entry.provider + "|" + entry.sort
    cached = {movies: [], series: [], hasMovies: false, hasSeries: false, clock: CreateObject("roTimespan")}
    if type(m.homeCache) = "roAssociativeArray" and m.homeCache.doesExist(cacheKey)
        previousCache = m.homeCache[cacheKey]
        if type(previousCache) = "roAssociativeArray" then cached = previousCache
    end if
    if entry.kind = "movie"
        cached.hasMovies = false
    else
        cached.hasSeries = false
    end if
    m.homeCache[cacheKey] = cached
end sub

sub homeFetched(event as object)
    answer = event.getData()
    if type(answer) <> "roAssociativeArray" then return
    ' Later movie pages only extend the Home carousel pool. Patch the existing
    ' hero counter instead of rebuilding every Home node for each page.
    patchHomeHero = false
    for i = 0 to m.homeJobs.count()-1
        entry = m.homeJobs[i]
        if entry.node.isSameNode(event.getRoSGNode()) and answer.requestId = entry.request
            if entry.mode <> m.catalogMode then return
            if m.catalogMode = "hd" and entry.provider <> m.hdProvider then return
            if answer.ok
                if entry.kind = "movie"
                    ' Preserve the selected hero by identity when the first page replaces the pool.
                    selectedHeroId = ""
                    selectedHeroImdbId = ""
                    selectedHeroTitle = ""
                    selectedHeroYear = ""
                    if entry.skip = 0 and m.heroFeature >= 0 and m.heroFeature < m.features.count()
                        selectedHero = m.features[m.heroFeature]
                        selectedHeroId = orbitText(selectedHero.id,180)
                        selectedHeroImdbId = orbitText(selectedHero.imdbId,40)
                        selectedHeroTitle = lcase(orbitText(selectedHero.title,160))
                        selectedHeroYear = orbitText(selectedHero.year,4)
                    end if
                    mergedMovies = m.features
                    if entry.skip = 0 then mergedMovies = []
                    for each fetchedMovie in answer.items
                        mergedMovies.push(fetchedMovie)
                    end for
                    m.features = orbitUniqueCatalogItems(mergedMovies)
                    if entry.skip = 0 and m.features.count() > 0
                        restoredHero = -1
                        if selectedHeroId <> ""
                            for heroIndex = 0 to m.features.count()-1
                                if orbitText(m.features[heroIndex].id,180) = selectedHeroId
                                    restoredHero = heroIndex
                                    exit for
                                end if
                            end for
                        end if
                        if restoredHero < 0 and selectedHeroImdbId <> ""
                            for heroIndex = 0 to m.features.count()-1
                                if orbitText(m.features[heroIndex].imdbId,40) = selectedHeroImdbId
                                    restoredHero = heroIndex
                                    exit for
                                end if
                            end for
                        end if
                        if restoredHero < 0 and selectedHeroTitle <> ""
                            for heroIndex = 0 to m.features.count()-1
                                candidate = m.features[heroIndex]
                                if lcase(orbitText(candidate.title,160)) = selectedHeroTitle
                                    candidateYear = orbitText(candidate.year,4)
                                    if selectedHeroYear = "" or candidateYear = "" or candidateYear = selectedHeroYear
                                        restoredHero = heroIndex
                                        exit for
                                    end if
                                end if
                            end for
                        end if
                        if restoredHero >= 0 then m.heroFeature = restoredHero
                    end if
                    if m.heroFeature >= m.features.count() then m.heroFeature = 0
                    if m.discoveryOffset >= m.features.count() then m.discoveryOffset = 0
                    ' Load up to three Cinemeta/provider pages so the carousel has a deeper pool.
                    if answer.doesExist("hasMore") and answer.hasMore and entry.skip < 40
                        nextSkip = entry.skip + 20
                        if answer.doesExist("nextSkip") then nextSkip = answer.nextSkip
                        if nextSkip > entry.skip and nextSkip <= 40 then startHomeCatalogTask("movie",nextSkip)
                    end if
                else
                    m.homeSeries = orbitUniqueCatalogItems(answer.items)
                end if
                ' Partial provider responses remain visible, but invalidate this cache row.
                if answer.doesExist("partial") and answer.partial
                    invalidateHomeCacheRow(entry)
                else
                    cacheKey = entry.mode + "|" + entry.provider + "|" + entry.sort
                    cached = {movies: [], series: [], hasMovies: false, hasSeries: false, clock: CreateObject("roTimespan")}
                    if m.homeCache.doesExist(cacheKey)
                        previousCache = m.homeCache[cacheKey]
                        if type(previousCache) = "roAssociativeArray" then cached = previousCache
                    end if
                    if entry.kind = "movie"
                        cachedMovies = cached.movies
                        if entry.skip = 0 then cachedMovies = []
                        for each cachedMovie in answer.items
                            cachedMovies.push(cachedMovie)
                        end for
                        cached.movies = orbitUniqueCatalogItems(cachedMovies)
                        if entry.skip = 0 then cached.hasMovies = true
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
                end if
                patchHomeHero = entry.kind = "movie" and entry.skip > 0
            else
                invalidateHomeCacheRow(entry)
                m.note = "No se pudo actualizar una de las filas. Puedes explorar desde el menú o volver a intentar."
            end if
            entry.node.unobserveField("result")
            entry.node.unobserveField("state")
            m.homeJobs.delete(i)
            exit for
        end if
    end for
    m.homeLoading = m.homeJobs.count() > 0
    if m.view = "home"
        if patchHomeHero and updateHomeHero()
            syncHomeRotationTimers()
        else
            drawScreen()
        end if
    end if
end sub

sub homeStopped(event as object)
    if event.getData() <> "STOP" then return
    for i = 0 to m.homeJobs.count()-1
        entry = m.homeJobs[i]
        if entry.node.isSameNode(event.getRoSGNode())
            if type(entry.node.result) = "roAssociativeArray" then return
            invalidateHomeCacheRow(entry)
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
        if m.kind = "all"
            localMovies = rpHdCatalogItems(m.hdLibrary,"movie",m.query)
            localSeries = rpHdCatalogItems(m.hdLibrary,"series",m.query)
            combined = []
            for each localItem in localMovies
                combined.push(localItem)
            end for
            for each localItem in localSeries
                combined.push(localItem)
            end for
            m.pageTitles = orbitUniqueCatalogItems(combined)
        else
            m.pageTitles = orbitUniqueCatalogItems(rpHdCatalogItems(m.hdLibrary,m.kind,m.query))
        end if
        applyGenreFilter()
        m.offset = 0
        m.nextOffset = 0
        m.more = false
        m.cursor = 0
        if m.zone <> "categories" then m.zone = "grid"
        drawScreen()
    else
        browseOperation = "catalog"
        if m.catalogMode = "hd" and usesOnlineHd() then browseOperation = "cinemeta-catalog"
        pageKey = m.catalogMode + "|" + m.hdProvider + "|" + m.kind + "|" + orbitText(m.query,120) + "|" + m.genreFilter + "|" + m.catalogSort + "|" + browseOperation + "|" + offset.toStr()
        if type(m.catalogPageCache) = "roAssociativeArray" and m.catalogPageCache.key = pageKey and m.catalogPageCache.clock <> invalid
            pageAge = m.catalogPageCache.clock.totalMilliseconds()
            if pageAge >= 0 and pageAge < 90000
                previousVisibleCount = m.titles.count()
                if offset > 0
                    combinedPage = []
                    for each existingItem in m.pageTitles
                        combinedPage.push(existingItem)
                    end for
                    for each nextItem in m.catalogPageCache.items
                        combinedPage.push(nextItem)
                    end for
                    m.pageTitles = orbitUniqueCatalogItems(combinedPage)
                else
                    m.pageTitles = orbitUniqueCatalogItems(m.catalogPageCache.items)
                end if
                applyGenreFilter()
                m.offset = offset
                m.nextOffset = m.catalogPageCache.nextOffset
                m.more = m.catalogPageCache.hasMore
                if (browseOperation = "catalog" or browseOperation = "cinemeta-catalog") and m.genreFilter <> "Todos" and m.titles.count() < 30 and m.more and offset < 400
                    print "[RokuPlus genres] scan_cached_next=1 filter="; m.genreFilter; " source_offset="; m.nextOffset; " matches="; m.titles.count()
                    loadBrowsePage(m.nextOffset)
                    return
                end if
                if m.categoryInitialScan
                    ' Cached pages must preserve the same initial focus as network pages.
                    m.cursor = 0
                    m.categoryInitialScan = false
                else
                    m.cursor = 0
                    if offset > 0 and m.titles.count() > previousVisibleCount
                        m.cursor = previousVisibleCount
                    else if offset > 0 and m.titles.count() > 0
                        m.cursor = m.titles.count()-1
                    end if
                    if last then m.cursor = m.titles.count()-1
                    if m.cursor < 0 then m.cursor = 0
                end if
                m.catalogFadePending = false
                if m.zone <> "categories" then m.zone = "grid"
                m.note = ""
                drawScreen()
                return
            end if
        end if
        fetch({operation:browseOperation,offset:offset,last:last})
    end if
end sub

function detailActionCount() as integer
    if m.detail = invalid then return 0
    if m.detail.kind = "series" or m.catalogMode = "hd" then return 2
    if m.capabilities.hevcKnown and not m.capabilities.canDecodeHevc then return 2
    return 3
end function

function advanceSourceAlternativeAfterMiss() as boolean
    if not m.sourceAlternativeAutoActive then return false
    nextAlternativeIndex = m.sourceAlternativeAttemptIndex + 1
    if type(m.sourceAlternativeQueue) = "roArray" and nextAlternativeIndex >= 0 and nextAlternativeIndex < m.sourceAlternativeQueue.count()
        nextAlternative = m.sourceAlternativeQueue[nextAlternativeIndex]
        m.sourceAlternativeStatus = "Sin coincidencia con el título anterior. Reproduciendo el siguiente: "+orbitText(nextAlternative.title,100)
        print "[RokuPlus source-alternatives] no-match next="; nextAlternativeIndex+1; " title="; left(orbitText(nextAlternative.title,120),120)
        chooseSourceAlternative(nextAlternativeIndex,true)
        return true
    end if
    m.sourceAlternativeAutoActive = false
    m.sourceAlternativeStatus = "Sin coincidencia en los títulos similares. Puedes elegir otra portada o volver atrás."
    if type(m.sourceAlternativeQueue) = "roArray" then m.sourceAlternatives = m.sourceAlternativeQueue
    m.sourceAlternativeCursor = m.sourceAlternativeAttemptIndex
    if m.sourceAlternativeCursor < 0 then m.sourceAlternativeCursor = 0
    if type(m.sourceAlternatives) = "roArray" and m.sourceAlternativeCursor >= m.sourceAlternatives.count() then m.sourceAlternativeCursor = m.sourceAlternatives.count()-1
    m.sourceAlternativeQueue = []
    m.sourceAlternativeAttemptIndex = -1
    drawScreen()
    return true
end function

sub stopSourceAlternativeCountdown()
    if m.sourceAlternativeTimer <> invalid then m.sourceAlternativeTimer.control = "stop"
    m.sourceAlternativeCountdown = 0
end sub

sub startSourceAlternativeCountdown()
    stopSourceAlternativeCountdown()
    if type(m.sourceAlternatives) <> "roArray" or m.sourceAlternatives.count() = 0 then return
    m.sourceAlternativeCountdown = 30
    if m.sourceAlternativeTimer <> invalid then m.sourceAlternativeTimer.control = "start"
end sub

sub sourceAlternativeTimerTick()
    if m.view <> "source-resolving" or m.busy or type(m.sourceAlternatives) <> "roArray" or m.sourceAlternatives.count() = 0
        stopSourceAlternativeCountdown()
        return
    end if
    if m.sourceAlternativeCountdown > 0 then m.sourceAlternativeCountdown = m.sourceAlternativeCountdown - 1
    if m.sourceAlternativeCountdown <= 0
        stopSourceAlternativeCountdown()
        m.sourceAlternativeQueue = m.sourceAlternatives
        m.sourceAlternativeAutoActive = true
        m.sourceAlternativeAttemptIndex = -1
        m.sourceAlternativeStatus = ""
        print "[RokuPlus source-alternatives] autoplay=1 index=0"
        chooseSourceAlternative(0,true)
    else
        drawScreen()
    end if
end sub

sub chooseSourceAlternative(index as integer, automatic as boolean)
    selectedAlternative = invalid
    if automatic
        if type(m.sourceAlternativeQueue) <> "roArray" or index < 0 or index >= m.sourceAlternativeQueue.count() then return
        selectedAlternative = m.sourceAlternativeQueue[index]
        m.sourceAlternativeAttemptIndex = index
        m.sourceAlternativeAutoActive = true
    else
        if type(m.sourceAlternatives) <> "roArray" or index < 0 or index >= m.sourceAlternatives.count() then return
        selectedAlternative = m.sourceAlternatives[index]
        m.sourceAlternativeAutoActive = false
        m.sourceAlternativeQueue = []
        m.sourceAlternativeAttemptIndex = -1
        m.sourceAlternativeStatus = ""
    end if
    if type(selectedAlternative) <> "roAssociativeArray" then return
    stopSourceAlternativeCountdown()
    mode = "manual"
    if automatic then mode = "automatic"
    print "[RokuPlus source-alternatives] selected mode="; mode; " title="; left(orbitText(selectedAlternative.title,120),120); " provider="; orbitText(selectedAlternative.provider,32)
    m.detail = selectedAlternative
    m.sourceAlternatives = []
    m.sourceAlternativeCursor = 0
    playDetail()
end sub

sub playDetail()
    stopSourceAlternativeCountdown()
    if m.detail = invalid then return
    preloadStreamXImages(m.detail)
    if m.busy then return
    blockKey = rpVoeBlockKey(m.detail)
    if (m.detail.doesExist("voeBlocked") and m.detail.voeBlocked = true) or (blockKey <> "" and m.voeBlockedSession.doesExist(blockKey))
        m.detail.voeBlocked = true
        print "[RokuPlus voe] request_skipped=1 reason=blocked-session"
        m.note = "VOE está temporalmente protegido. Intenta más tarde o elige otra fuente."
        drawScreen()
        return
    end if
    m.playbackMode = "direct"
    m.sourceAlternatives = []
    m.sourceAlternativeCursor = 0
    m.sourceLaunchPending = true
    m.note = ""
    keepActiveEpisode = m.view = "player" and m.player.active = true and type(m.activePlaybackItem) = "roAssociativeArray" and m.detail.kind = "episode"
    if not keepActiveEpisode then m.view = "source-resolving"
    if orbitText(m.detail.discoverySource,32) = "cinemeta"
        fetch({operation:"find-source",item:m.detail,returnView:"detail",origin:m.detailOrigin})
        return
    end if
    if usesOnlineHd() or rpIsOnlineHdItem(m.detail)
        if lcase(orbitText(m.detail.provider,32)) = "seriesmetro" and m.detail.kind = "episode" and orbitText(m.detail.providerSlug,200) = "" and (orbitInteger(m.detail.seriesProviderId,999999999) > 0 or orbitInteger(m.detail.providerId,999999999) > 0)
            print "[RokuPlus series] resume-episode-recover id="; orbitText(m.detail.id,180); " parentId="; orbitInteger(m.detail.seriesProviderId,999999999); " providerId="; orbitInteger(m.detail.providerId,999999999); " season="; orbitInteger(m.detail.season,999); " episode="; orbitInteger(m.detail.episode,9999)
            fetch({operation:"resume-episode",item:m.detail})
        else
            fetch({operation:"resolve",item:m.detail})
        end if
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
    if orbitText(m.detail.discoverySource,32) = "cinemeta"
        m.note = ""
        fetch({operation:"find-source",item:m.detail,returnView:"detail",origin:m.detailOrigin})
        return
    end if
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
        m.episodeMode = "episodes"
        m.view = "episodes"
        m.zone = "seasons"
        selectLastWatchedEpisode()
    end if
    drawScreen()
    if m.view = "episodes" then loadEpisodeSeason()
end sub

function rpWatchLastEpisodeForSeries(series as object) as dynamic
    if type(series) <> "roAssociativeArray" or type(m.watchState) <> "roArray" then return invalid
    seriesId = orbitText(series.id,180)
    seriesImdbId = orbitText(series.imdbId,180)
    seriesTitle = lcase(orbitText(series.title,180))
    seriesProvider = lcase(orbitText(series.provider,32))
    for each saved in m.watchState
        if type(saved) = "roAssociativeArray" and orbitText(saved.kind,20) = "episode"
            if saved.doesExist("season") and saved.doesExist("episode")
                matches = false
                savedSeriesId = orbitText(saved.seriesId,180)
                savedImdbId = orbitText(saved.imdbId,180)
                if seriesId <> "" and savedSeriesId = seriesId then matches = true
                if seriesId <> "" and savedImdbId = seriesId then matches = true
                if seriesImdbId <> "" and savedImdbId = seriesImdbId then matches = true
                if not matches and seriesTitle <> ""
                    savedTitle = lcase(orbitText(saved.seriesTitle,180))
                    savedProvider = lcase(orbitText(saved.provider,32))
                    if savedTitle = seriesTitle and savedProvider = seriesProvider and seriesProvider <> "" then matches = true
                end if
                if matches then return saved
            end if
        end if
    end for
    return invalid
end function

sub selectLastWatchedEpisode()
    if m.series = invalid then return
    m.pendingResumeEpisode = invalid
    saved = rpWatchLastEpisodeForSeries(m.series)
    if type(saved) <> "roAssociativeArray" then return
    targetSeason = orbitInteger(saved.season,999,-1)
    targetEpisode = orbitInteger(saved.episode,9999,-1)
    if targetSeason < 0 or targetEpisode < 0 then return
    for i = 0 to m.series.seasons.count()-1
        if m.series.seasons[i].number = targetSeason
            m.season = i
            m.episode = 0
            m.pendingResumeEpisode = {season:targetSeason,episode:targetEpisode}
            m.zone = "episodes"
            applyPendingResumeEpisode()
            print "[RokuPlus series] last-watched-selection season="; targetSeason; " episode="; targetEpisode; " loaded="; m.series.seasons[i].loaded
            return
        end if
    end for
end sub

sub applyPendingResumeEpisode()
    if type(m.pendingResumeEpisode) <> "roAssociativeArray" or m.series = invalid then return
    if m.season < 0 or m.season >= m.series.seasons.count() then return
    season = m.series.seasons[m.season]
    if season.number <> m.pendingResumeEpisode.season then return
    if season.doesExist("loaded")
        if season.loaded <> true then return
    else
        if season.episodes.count() = 0 then return
    end if
    for i = 0 to season.episodes.count()-1
        if orbitInteger(season.episodes[i].episode,9999,-1) = m.pendingResumeEpisode.episode
            m.episode = i
            m.zone = "episodes"
            print "[RokuPlus series] last-watched-focused index="; i
            m.pendingResumeEpisode = invalid
            return
        end if
    end for
    print "[RokuPlus series] last-watched-not-found season="; season.number; " episode="; m.pendingResumeEpisode.episode
    m.pendingResumeEpisode = invalid
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
    if m.series = invalid then return
    if not usesOnlineHd() and not rpIsOnlineHdItem(m.series) then return
    if m.season < 0 or m.season >= m.series.seasons.count() then return
    season = m.series.seasons[m.season]
    ' A request for another season must not remain active when the newly
    ' selected season is already cached; otherwise its late result can reset
    ' the episode cursor after the user has moved on.
    if type(m.pending) = "roAssociativeArray" and m.pending.operation = "episodes"
        pendingSeason = -1
        if m.pending.doesExist("season") then pendingSeason = orbitInteger(m.pending.season,999,-1)
        pendingSeriesId = ""
        if type(m.pending.item) = "roAssociativeArray" then pendingSeriesId = orbitText(m.pending.item.id,180)
        currentSeriesId = orbitText(m.series.id,180)
        if pendingSeriesId = currentSeriesId and pendingSeason <> season.number then cancelRequest()
    end if
    if season.loaded = true then return
    fetch({operation:"episodes",item:m.series,season:season.number})
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    ' Route remote input directly to the Roku Plus experience.
    if key = "home" then return false
    if press
        print "[RokuPlus input] key="; key; " view="; m.view; " zone="; m.zone; " sceneFocus="; m.top.hasFocus(); " plusVisible="; m.plusExperience.visible
    end if
    if not press
        if key = "down" then m.ignoreBrowseDownUntilRelease = false
        if m.view = "search-keyboard" and key = "OK" and m.searchDeleteHeld
            m.searchDeleteTimer.control = "stop"
            if not m.searchDeleteCleared and len(m.searchText) > 0
                m.searchText = left(m.searchText,len(m.searchText)-1)
                refreshSearchSuggestions()
                drawScreen()
            end if
            m.searchDeleteHeld = false
            m.searchDeleteCleared = false
            return true
        end if
        return true
    end if
    if m.view = "player" or m.view = "invidious-player" then return false
    if m.view = "source-resolving" and not m.busy and type(m.sourceAlternatives) = "roArray" and m.sourceAlternatives.count() > 0
        if key = "left" and m.sourceAlternativeCursor > 0
            m.sourceAlternativeCursor--
            drawScreen()
            return true
        else if key = "right" and m.sourceAlternativeCursor < m.sourceAlternatives.count()-1
            m.sourceAlternativeCursor++
            drawScreen()
            return true
        else if key = "OK"
            chooseSourceAlternative(m.sourceAlternativeCursor,false)
            return true
        end if
    end if
    if m.view = "source-resolving" and not m.busy and key = "OK"
        m.sourceLaunchPending = false
        playDetail()
        return true
    end if
    if key = "down" and m.ignoreBrowseDownUntilRelease then return true
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
    if m.view = "search-keyboard"
        ' Play/Pause confirma la búsqueda desde el teclado personalizado.
        if key = "play" or key = "playpause" or key = "pause"
            submitGlobalSearch()
            return true
        end if
        ' Reload/Replay borra un carácter; Back conserva la función de volver/cerrar.
        if key = "reload" or key = "replay" or key = "instantreplay"
            if len(m.searchText) > 0 then m.searchText = left(m.searchText,len(m.searchText)-1)
            refreshSearchSuggestions()
            drawScreen()
            return true
        end if
        ' Options (*) inserta un espacio en el texto.
        if key = "options" or key = "*"
            if len(m.searchText) < 120 then m.searchText += " "
            refreshSearchSuggestions()
            drawScreen()
            return true
        end if
    end if
    if key = "back"
        if m.view = "source-resolving"
            stopSourceAlternativeCountdown()
            m.sourceAlternatives = []
            m.sourceAlternativeCursor = 0
            m.sourceAlternativeQueue = []
            m.sourceAlternativeAttemptIndex = -1
            m.sourceAlternativeAutoActive = false
            m.sourceAlternativeStatus = ""
        end if
        if m.view = "search-keyboard"
            closeSearchKeyboard()
            return true
        end if
        if m.busy
            pendingContext = m.pending
            cancelRequest()
            m.autoplay = false
            if m.sourceLaunchPending
                m.sourceLaunchPending = false
                m.view = "detail"
            else if type(pendingContext) = "roAssociativeArray" and pendingContext.operation = "find-source"
                m.view = "detail"
            end if
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
    if m.view = "invidious"
        previousCursor = m.invidiousCursor
        if key = "up" and m.invidiousCursor > 0 then m.invidiousCursor--
        if key = "down" and m.invidiousCursor+1 < m.invidiousItems.count() then m.invidiousCursor++
        if key = "OK" and m.invidiousItems.count() > 0
            if not m.busy
                selected = m.invidiousItems[m.invidiousCursor]
                startInvidiousResolve(selected)
            end if
            return true
        end if
        if key = "back"
            if m.busy then cancelRequest()
            m.view = "settings"
            m.zone = "settings"
            m.settingsCursor = 10
            drawScreen()
            m.top.setFocus(true)
            return true
        end if
        ' Invidious rows are drawn directly, not registered in m.focusItems.
        ' Redraw the view so the selected-row highlight follows the cursor.
        if previousCursor <> m.invidiousCursor
            drawScreen()
            m.top.setFocus(true)
        end if
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
    ' Roku remote * is reported as the "options" key.
    ' On Home it opens search; in movie/series grids it toggles Mi lista.
    if key = "options" or key = "*"
        if m.view = "home"
            openSearch()
            return true
        end if
        if m.view = "browse" and m.titles.count() > 0 and m.cursor >= 0 and m.cursor < m.titles.count()
            toggleWatchItem(m.titles[m.cursor],"listed")
            return true
        end if
        if m.view = "episodes" and m.episodeMode = "episodes"
            if type(m.series) = "roAssociativeArray" and type(m.series.seasons) = "roArray"
                if m.season >= 0 and m.season < m.series.seasons.count()
                    episodes = m.series.seasons[m.season].episodes
                    if type(episodes) = "roArray" and m.episode >= 0 and m.episode < episodes.count()
                        toggleWatchItem(episodes[m.episode],"listed")
                    end if
                end if
            end if
            return true
        end if
    end if
    if (key = "replay" or key = "instantreplay" or key = "reload") and m.view = "browse"
        openGenreFilter()
        return true
    end if
    if key = "info" and m.view = "browse"
        openGenreFilter()
        return true
    end if
    if (key = "options" or key = "info") and m.view <> "search-keyboard"
        if m.view = "library" and key = "options" then removeLibraryItem(): return true
        if m.view = "profiles" and key = "options" then openProfileEditor(m.profileCursor): return true
        if m.view = "browse" and key = "options" then openGenreFilter(): return true
        if m.view = "live" then toggleLiveFavorite(): return true
        if m.view = "profiles" and (key = "play" or key = "playpause" or key = "pause") then cycleProfileAvatar(m.profileCursor): return true
        if m.view = "detail"
            if key = "options" then toggleCurrentWatch("watched") else toggleCurrentWatch("listed")
            return true
        end if
        if m.view = "episodes" and m.episodeMode = "episodes"
            if type(m.series) = "roAssociativeArray" and type(m.series.seasons) = "roArray"
                if m.season >= 0 and m.season < m.series.seasons.count()
                    episodes = m.series.seasons[m.season].episodes
                    if type(episodes) = "roArray" and m.episode >= 0 and m.episode < episodes.count()
                        m.detail = episodes[m.episode]
                        if key = "options" then toggleCurrentWatch("watched") else toggleCurrentWatch("listed")
                    end if
                end if
            end if
            return true
        end if
        openSearch()
        return true
    end if
    if m.view = "search-keyboard" and left(key,4) = "Lit_"
        ' Literal characters sent by the Roku mobile app/ECP go straight into
        ' this custom keyboard; no StandardKeyboardDialog is required.
        literal = mid(key,5)
        if literal = "Backspace"
            if len(m.searchText) > 0 then m.searchText = left(m.searchText,len(m.searchText)-1)
        else if literal = "Space"
            if len(m.searchText) < 120 then m.searchText += " "
        else if len(literal) = 1 and len(m.searchText) < 120
            m.searchText += literal
        end if
        refreshSearchSuggestions()
        drawScreen()
        return true
    end if
    if m.view = "search-keyboard"
        rows = ["0123456789","ABCDEFGHIJ","KLMNOPQRST","UVWXYZ.-_⌫"]
        if m.zone = "search-suggestion"
            if key = "left" and m.searchCursor > 0 then m.searchCursor--
            if key = "right" and m.searchCursor+1 < m.searchSuggestions.count() then m.searchCursor++
            if key = "down" then m.zone = "search-key": m.searchCursor = 0
            if key = "OK" then chooseSearchSuggestion(m.searchCursor): return true
            if key = "up" then m.zone = "search-key": m.searchCursor = 30
        else if m.zone = "search-action"
            if key = "left" and m.searchCursor > 0 then m.searchCursor--
            if key = "right" and m.searchCursor < 2 then m.searchCursor++
            if key = "down" then m.zone = "search-key": m.searchCursor = 0
            if key = "OK"
                if m.searchCursor = 0
                    submitGlobalSearch()
                else if m.searchCursor = 1
                    closeSearchKeyboard()
                else
                    if len(m.searchText) < 120 then m.searchText += " "
                    refreshSearchSuggestions()
                    drawScreen()
                end if
                return true
            end if
            if key = "up" then m.zone = "search-key": m.searchCursor = 30
        else
            row = m.searchCursor \ 10
            col = m.searchCursor mod 10
            if key = "left" and col > 0 then m.searchCursor--
            if key = "right" and col < 9 then m.searchCursor++
            if key = "up"
                if row > 0 then m.searchCursor -= 10 else if m.searchSuggestions.count() > 0 then m.zone = "search-suggestion": m.searchCursor = 0 else m.zone = "search-action": m.searchCursor = 0
            end if
            if key = "down"
                if row < 3 then m.searchCursor += 10 else m.zone = "search-action": m.searchCursor = 0
                if m.searchCursor > 39 then m.searchCursor = 39
            end if
            if key = "OK"
                keyChar = mid(rows[row],col+1,1)
                if keyChar = "⌫"
                    if not m.searchDeleteHeld
                        m.searchDeleteHeld = true
                        m.searchDeleteCleared = false
                        m.searchDeleteTimer.duration = 0.75
                        m.searchDeleteTimer.control = "start"
                    end if
                    return true
                else if len(m.searchText) < 120
                    m.searchText += keyChar
                end if
                refreshSearchSuggestions()
                drawScreen()
                return true
            end if
        end if
        paintFocus()
        return true
    end if
    if m.busy and m.view <> "live" then return true
    if m.zone = "nav"
        if key = "up" and m.nav > 0 then m.nav--
        if key = "down" and m.nav < 8 then m.nav++
        if key = "OK" then activateNav(): return true
        if key = "right"
            if m.view = "home" then m.zone = "hero"
            if m.view = "library" then m.zone = "library"
            if m.view = "browse" then m.zone = "grid"
            if m.view = "live" then m.zone = "live-filters"
            if m.view = "detail" then m.zone = "action"
            if m.view = "episodes"
                m.zone = "episodes"
                if m.episodeMode = "seasons" then m.zone = "seasons"
            end if
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
        if key = "down" and m.settingsCursor < 10 then m.settingsCursor++
        if key = "OK"
            if m.settingsCursor = 0 then beginSetup(true,false)
            if m.settingsCursor = 1 then beginSetup(true,true)
            if m.settingsCursor = 2 then openHdSource()
            if m.settingsCursor = 3 then openCredits()
            if m.settingsCursor = 4 then openAppearance()
            if m.settingsCursor = 5 then openProfiles()
            if m.settingsCursor = 6 then openCompatSettings()
            if m.settingsCursor = 7 then openApiKeySettings("tmdb")
            if m.settingsCursor = 8 then openApiKeySettings("subtitle")
            if m.settingsCursor = 10 then openInvidiousSearch()
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
            if key = "down"
                if m.continueItems.count() > 0 then
                    m.zone = "continue"
                else
                    settleDiscoveryForFocus()
                    m.zone = "covers"
                end if
                m.cover = 0
            end if
            if key = "OK"
                if m.features.count() > 0 then openDetails(m.features[m.heroFeature],"home",m.hero=0) else refreshHome(): drawScreen()
                return true
            end if
        else if m.zone = "covers"
            if key = "left"
                if m.cover > 0
                    m.cover--
                else if m.discoveryOffset > 0
                    m.discoveryOffset--
                    drawScreen()
                    return true
                else
                    m.zone = "nav"
                    drawScreen()
                    return true
                end if
            end if
            if key = "right"
                if m.cover < 5 and m.discoveryOffset+m.cover+1 < m.features.count()
                    m.cover++
                else if m.cover = 5 and m.discoveryOffset+6 < m.features.count()
                    m.discoveryOffset++
                    drawScreen()
                    return true
                end if
            end if
            if key = "up"
                if m.continueItems.count() > 0 then m.zone = "continue" else m.zone = "hero"
            end if
            if key = "down"
                if m.homeListItems.count() > 0
                    m.zone = "home-list"
                    m.listCover = 0
                else if m.homeSeries.count() > 0
                    m.zone = "home-series"
                    m.seriesCover = 0
                end if
            end if
            if key = "OK" and m.features.count() > 0
                selectedIndex = (m.discoveryOffset+m.cover) mod m.features.count()
                openDetails(m.features[selectedIndex],"home")
                return true
            end if
        else if m.zone = "home-list"
            if key = "left"
                if m.listCover > 0 then m.listCover-- else m.zone = "nav": drawScreen(): return true
            end if
            if key = "right" and m.listCover < m.homeListItems.count()-1 and m.listCover < 5 then m.listCover++
            if key = "up"
                settleDiscoveryForFocus()
                m.zone = "covers"
            end if
            if key = "down"
                if m.homeSeries.count() > 0
                    m.zone = "home-series"
                    m.seriesCover = 0
                end if
            end if
            if key = "OK" and m.listCover < m.homeListItems.count()
                openDetails(m.homeListItems[m.listCover],"home")
                return true
            end if
        else if m.zone = "continue"
            ' Diagnostic: confirm the remote-control event reaches the Continue Watching handler.
            print "[RokuPlus continue] key="; key; " cover="; m.cover; " count="; m.continueItems.count()
            if key = "left"
                if m.cover > 0 then m.cover-- else m.zone = "nav": drawScreen(): return true
            end if
            if key = "right" and m.cover < m.continueItems.count()-1 and m.cover < 5 then m.cover++
            if key = "up" then m.zone = "hero"
            if key = "down"
                settleDiscoveryForFocus()
                m.zone = "covers"
            end if
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
                        if candidateProvider = "seriesmetro"
                            seriesMarker = instr(1,candidateId,"-s")
                            if seriesMarker > 1 then candidateId = left(candidateId,seriesMarker-1)
                        end if
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
                if saved.doesExist("seriesId") then resumeItem.seriesId = orbitText(saved.seriesId,180)
                if saved.doesExist("seriesProviderId") then resumeItem.seriesProviderId = saved.seriesProviderId
                if saved.doesExist("seriesProviderSlug") then resumeItem.seriesProviderSlug = orbitText(saved.seriesProviderSlug,200)
                if saved.doesExist("seriesProviderTmdbId") then resumeItem.seriesProviderTmdbId = orbitText(saved.seriesProviderTmdbId,40)
                if saved.doesExist("seriesProviderKind") then resumeItem.seriesProviderKind = orbitText(saved.seriesProviderKind,16)
                if saved.doesExist("seriesSeasonNumbers") and type(saved.seriesSeasonNumbers) = "roArray" then resumeItem.seriesSeasonNumbers = saved.seriesSeasonNumbers
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
            if key = "up"
                if m.homeListItems.count() > 0 then
                    m.zone = "home-list"
                else
                    settleDiscoveryForFocus()
                    m.zone = "covers"
                end if
            end if
            if key = "OK" and m.homeSeries.count() > 0 then openDetails(m.homeSeries[m.seriesCover],"home"): return true
        end if
    else if m.view = "browse"
        if m.zone = "categories"
            if key = "left" and m.categoryCursor > 0 then m.categoryCursor--
            if key = "right" and m.categoryCursor < 8 then m.categoryCursor++
            if key = "down"
                m.zone = "grid"
                ' Consume repeats from the same press; only a fresh press may move in the grid.
                m.ignoreBrowseDownUntilRelease = true
            end if
            if key = "up"
                m.zone = "nav"
                m.nav = 1
                if m.kind = "series" then m.nav = 2
            end if
            if key = "OK"
                categoryOptions = ["Más populares","Más recientes","Acción","Comedia","Drama","Terror","Ciencia ficción","Animación","Todos"]
                selectedCategory = categoryOptions[m.categoryCursor]
                if selectedCategory = "Más recientes"
                    m.catalogSort = "recent"
                    m.genreFilter = "Todos"
                else if selectedCategory = "Más populares"
                    m.catalogSort = "popular"
                    m.genreFilter = "Todos"
                else if selectedCategory = "Todos"
                    m.catalogSort = "all"
                    m.genreFilter = "Todos"
                else
                    m.catalogSort = "popular"
                    m.genreFilter = selectedCategory
                end if
                ' A category is a separate browse session: do not filter the
                ' previously loaded Todos pages. Start again at source page 1.
                m.pageTitles = []
                m.titles = []
                m.offset = 0
                m.nextOffset = 0
                m.more = false
                m.cursor = 0
                m.categoryInitialScan = true
                m.note = ""
                ' Selecting another category must not move focus to the poster grid.
                m.zone = "categories"
                if m.catalogMode = "hd" and not usesOnlineHd()
                    applyGenreFilter()
                    drawScreen()
                else
                    loadBrowsePage(0)
                end if
            end if
            drawScreen()
            return true
        end if
        previousCursor = m.cursor
        if key = "up" and m.cursor < 5
            m.zone = "categories"
            m.categoryCursor = 0
    m.ignoreBrowseDownUntilRelease = false
            categoryNames = ["Más populares","Más recientes","Acción","Comedia","Drama","Terror","Ciencia ficción","Animación","Todos"]
            if m.catalogSort = "recent" then m.categoryCursor = 1
            if m.catalogSort = "all" then m.categoryCursor = 8
            if m.genreFilter <> "Todos"
                for categoryIndex = 0 to categoryNames.count()-1
                    if categoryNames[categoryIndex] = m.genreFilter then m.categoryCursor = categoryIndex
                end for
            end if
            drawScreen()
            return true
        end if
        if key = "left"
            if m.cursor > 0
                m.cursor--
            else
                m.zone = "nav"
                m.nav = 1
                if m.kind = "series" then m.nav = 2
                drawScreen()
                return true
            end if
        else if key = "right"
            if m.cursor+1 < m.titles.count()
                m.cursor++
            else if m.more and not m.busy
                loadBrowsePage(m.nextOffset)
                return true
            end if
        else if key = "up"
            if m.cursor >= 5
                m.cursor -= 5
            else
                m.zone = "nav"
                m.nav = 1
                if m.kind = "series" then m.nav = 2
                drawScreen()
                return true
            end if
        else if key = "down"
            if m.cursor+5 < m.titles.count()
                m.cursor += 5
            else if m.more and not m.busy
                loadBrowsePage(m.nextOffset)
                return true
            end if
        else if key = "rewind"
            m.zone = "nav"
            m.nav = 1
            if m.kind = "series" then m.nav = 2
            drawScreen()
            return true
        else if key = "fastforward"
            if m.cursor+1 < m.titles.count()
                m.cursor++
            else if m.more and not m.busy
                loadBrowsePage(m.nextOffset)
                return true
            end if
        end if
        if key = "OK" and m.titles.count() > 0 then openDetails(m.titles[m.cursor],"browse"): return true
        if previousCursor <> m.cursor
            if (previousCursor \ 10) = (m.cursor \ 10) and updateBrowseSelection() then return true
            drawScreen()
            return true
        end if
    else if m.view = "detail"
        previousAction = m.action
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
        if previousAction <> m.action
            paintFocus()
            return true
        end if
    else if m.view = "episodes"
        previousSeason = m.season
        previousEpisode = m.episode
        previousZone = m.zone
        if m.zone = "seasons"
            if key = "up"
                m.zone = "nav"
                drawScreen()
                return true
            end if
            if key = "left"
                if m.season > 0
                    m.season--
                    m.episode = 0
                    loadEpisodeSeason()
                else
                    m.zone = "nav"
                end if
            end if
            if key = "right" and m.season+1 < m.series.seasons.count()
                m.season++
                m.episode = 0
                loadEpisodeSeason()
            end if
            if key = "down" or key = "OK" then m.zone = "episodes"
        else
            items = m.series.seasons[m.season].episodes
            if key = "up"
                m.zone = "seasons"
            else if key = "left" and m.episode > 0
                m.episode--
            else if key = "right" and m.episode+1 < items.count()
                m.episode++
            else if key = "OK"
                if items.count() > 0
                    openDetails(items[m.episode],"episodes")
                    return true
                else
                    loadEpisodeSeason()
                end if
            end if
        end if
        if m.season <> previousSeason
            drawScreen()
        else if m.zone <> previousZone
            if m.zone = "nav" or previousZone = "nav"
                drawScreen()
            else
                paintFocus()
            end if
        else if m.zone = "episodes" and previousEpisode <> m.episode
            if (previousEpisode \ 4) = (m.episode \ 4)
                paintFocus()
            else
                drawScreen()
            end if
        else
            paintFocus()
        end if
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
                if m.liveSearchCursor > 0
                    m.liveSearchCursor = 0
                else
                    m.zone = "nav"
                    m.nav = 3
                    drawScreen()
                    return true
                end if
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
            if key = "left"
                m.zone = "nav"
                m.nav = 3
                drawScreen()
                return true
            end if
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


function rpVoeBlockKey(item as dynamic) as string
    if type(item) <> "roAssociativeArray" then return ""
    provider = lcase(orbitText(item.provider,32))
    if provider = "" then return ""
    itemId = orbitText(item.id,180)
    if itemId = "" then itemId = orbitText(item.providerId,80)
    if itemId = ""
        itemId = orbitText(item.title,160) + "|s" + orbitInteger(item.season,999).toStr() + "|e" + orbitInteger(item.episode,9999).toStr()
    end if
    if itemId = "" then return ""
    return provider + "|" + lcase(itemId)
end function
