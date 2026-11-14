' Original RokuPlus player. The source URL is never included in diagnostics.
sub init()
    m.top.focusable = true
    m.top.visible = false
    m.decoder = m.top.findNode("decoder")
    m.videoViewport = m.top.findNode("videoViewport")
    m.tsStreamServer = m.top.findNode("tsStreamServer")
    if m.decoder.hasField("enableDecoderStats")
        m.decoder.enableDecoderStats = true
        print "[RokuPlus decoder] enableDecoderStats="; m.decoder.enableDecoderStats
    end if
    if m.decoder.hasField("decoderStats") then m.decoder.observeField("decoderStats", "onNativeDecoderStats")
    m.audioSelectionPreferenceSet = false
    ' Prefer Spanish audio when the stream exposes language metadata.
    ' Keep this before any Video control command, as required by Roku OS.
    if m.decoder.hasField("audioSelectionPreferences")
        m.decoder.audioSelectionPreferences = {values:[{language:["es-MX","es-419","es","es-*","spa"]}],overrideSystem:true}
        m.audioSelectionPreferenceSet = true
        print "[RokuPlus decoder] audioSelectionPreferences=Spanish es-MX,es-419,es,es-*,spa overrideSystem=true"
    else
        print "[RokuPlus decoder] audioSelectionPreferences=unsupported"
    end if
    if m.decoder.hasField("seamlessAudioTrackSelection")
        m.decoder.seamlessAudioTrackSelection = true
        print "[RokuPlus decoder] seamlessAudioTrackSelection=true"
    end if
    m.previewMask = m.top.findNode("previewMask")
    m.backdrop = m.top.findNode("backdrop")
    m.panel = m.top.findNode("transport")
    m.capsule = m.top.findNode("capsule")
    m.titleShade = m.top.findNode("titleShade")
    m.centerSurface = m.top.findNode("centerSurface")
    m.titleText = m.top.findNode("titleText")
    m.startupOverlay = m.top.findNode("startupOverlay")
    m.startupTitle = m.top.findNode("startupTitle")
    m.startupBanner = m.top.findNode("startupBanner")
    m.startupLogo = m.top.findNode("startupLogo")
    m.startupLogoPulse = m.top.findNode("startupLogoPulse")
    m.streamXTask = invalid
    m.streamXRequestId = ""
    m.startupLoadingText = m.top.findNode("startupLoadingText")
    m.startupTimer = m.top.findNode("startupTypeTimer")
    m.startupCharIndex = 0
    if m.startupTimer <> invalid then m.startupTimer.observeField("fire", "onStartupTypePulse")
    m.metaText = m.top.findNode("metaText")
    m.clockText = m.top.findNode("clockText")
    m.modeText = m.top.findNode("modeText")
    m.durationText = m.top.findNode("durationText")
    m.pauseText = m.top.findNode("pauseText")
    m.keyText = m.top.findNode("keyText")
    m.noticeText = m.top.findNode("noticeText")
    m.audioMenuGroup = m.top.findNode("audioMenu")
    m.audioMenuItems = m.top.findNode("audioMenuItems")
    m.audioMenuOpen = false
    m.audioTracks = []
    m.audioTrackIndex = 0
    m.subtitleMenuGroup = m.top.findNode("subtitleMenu")
    m.subtitleMenuItems = m.top.findNode("subtitleMenuItems")
    m.subtitleMenuOpen = false
    m.displayMenuGroup = m.top.findNode("displayMenu")
    m.displayMenuItems = m.top.findNode("displayMenuItems")
    m.displayMenuOpen = false
    m.displayMenuIndex = 0
    m.playerOptionsMenuGroup = m.top.findNode("playerOptionsMenu")
    m.playerOptionsMenuItems = m.top.findNode("playerOptionsMenuItems")
    m.endScreenGroup = m.top.findNode("playbackEndScreen")
    m.endScreenItemsLabel = m.top.findNode("playbackEndItems")
    m.endScreenOpen = false
    m.endScreenIndex = 0
    m.introDbData = invalid
    m.skipPromptGroup = m.top.findNode("skipSegmentPrompt")
    m.skipPromptText = m.top.findNode("skipSegmentText")
    m.skipPromptVisible = false
    m.skipPromptDismissed = false
    m.skipPromptTarget = invalid
    m.endScreenItems = []
    m.endCountdownActive = false
    m.endCountdownRemaining = 0
    m.endCountdownLastAt = 0
    m.playbackFinished = false
    m.endScreenHeading = m.top.findNode("endScreenHeading")
    m.endScreenMessage = m.top.findNode("endScreenMessage")
    m.endMovieLayout = m.top.findNode("endMovieLayout")
    m.endEpisodeLayout = m.top.findNode("endEpisodeLayout")
    m.endMoviePosters = []
    m.endMovieTitles = []
    for posterIndex = 1 to 6
        m.endMoviePosters.push(m.top.findNode("endMoviePoster" + posterIndex.toStr()))
        m.endMovieTitles.push(m.top.findNode("endMovieTitle" + posterIndex.toStr()))
    end for
    m.endMovieSelection = m.top.findNode("endMovieSelection")
    m.endEpisodePoster = m.top.findNode("endEpisodePoster")
    m.endEpisodeTitle = m.top.findNode("endEpisodeTitle")
    m.endEpisodeMeta = m.top.findNode("endEpisodeMeta")
    m.endCountdownText = m.top.findNode("endCountdownText")
    m.endCountdownDots = []
    for dotIndex = 1 to 10
        m.endCountdownDots.push(m.top.findNode("endCountdownDot" + dotIndex.toStr()))
    end for
    m.playerOptionsMenuOpen = false
    m.playerOptionsMenuIndex = 0
    m.playerOptionsLabels = ["Zoom / Imagen", "Subtítulos", "Audio", "Retroceder 10 segundos", "Adelantar 10 segundos", "Play / Pause"]
    m.zoomIndex = 0
    m.zoomLevels = [1.0, 1.10, 1.20, 1.33]
    m.zoomLabels = ["Original", "Zoom suave (1.10x)", "Zoom medio (1.20x)", "Zoom completo (1.33x)"]
    m.subtitleTracks = []
    m.subtitleTrackIndex = 0
    m.subtitleOnlineResults = []
    m.subtitleApiKeyDialog = invalid
    m.subtitleOnlineBusy = false
    m.subtitleOnlineOperation = ""
    m.subtitleOnlinePendingLabel = ""
    m.subtitleSearchTask = invalid
    m.externalSubtitleCues = []
    m.externalSubtitleIndex = 0
    m.externalSubtitleLastPosition = -1
    m.externalSubtitleSelectedIndex = 0
    m.externalSubtitleGroup = m.top.findNode("externalSubtitleOverlay")
    m.externalSubtitleLabel = m.top.findNode("externalSubtitleText")
    m.track = m.top.findNode("timeTrack")
    m.fill = m.top.findNode("timeFill")
    m.thumb = m.top.findNode("timeThumb")
    m.playGlyph = m.top.findNode("playGlyph")
    m.pauseGlyph = m.top.findNode("pauseGlyph")
    m.rewindControl = m.top.findNode("rewindControl")
    m.forwardControl = m.top.findNode("forwardControl")
    m.rewindSurface = m.top.findNode("rewindSurface")
    m.forwardSurface = m.top.findNode("forwardSurface")
    m.pulse = m.top.findNode("uiPulse")
    m.decoder.observeField("state", "onDecoderState")
    m.decoder.observeField("position", "onNativePosition")
    m.decoder.observeField("positionInfo", "onRenderedPosition")
    m.decoder.observeField("bufferingStatus", "onBufferDetails")
    if m.decoder.hasField("availableAudioTracks") then m.decoder.observeField("availableAudioTracks", "onNativeAudioTrackDetails")
    if m.decoder.hasField("currentAudioTrack") then m.decoder.observeField("currentAudioTrack", "onNativeAudioTrackDetails")
    if m.decoder.hasField("availableSubtitleTracks") then m.decoder.observeField("availableSubtitleTracks", "onNativeSubtitleTrackDetails")
    if m.decoder.hasField("currentSubtitleTrack") then m.decoder.observeField("currentSubtitleTrack", "onNativeSubtitleTrackDetails")
    if m.decoder.hasField("streamingSegment") then m.decoder.observeField("streamingSegment", "onNativeStreamDetails")
    if m.decoder.hasField("downloadedSegment") then m.decoder.observeField("downloadedSegment", "onNativeStreamDetails")
    if m.decoder.hasField("playStartInfo") then m.decoder.observeField("playStartInfo", "onNativeStreamDetails")
    if m.decoder.hasField("errorInfo") then m.decoder.observeField("errorInfo", "onNativeStreamDetails")
    ' Capture native HLS startup/error fields at the instant Roku changes them.
    for each field in ["errorCode","errorMsg","errorStr","streamInfo","videoFormat","audioFormat","timeToStartStreaming","contentIndex"]
        if m.decoder.hasField(field) then m.decoder.observeField(field, "onNativeStreamDetails")
    end for
    m.pulse.observeField("fire", "onPulse")
    m.monotonic = CreateObject("roTimespan")
    m.monotonic.mark()
    m.generation = 0
    m.mediaOpen = false
    m.closing = false
    m.alreadyClosed = true
    m.current = invalid
    m.ticket = invalid
    m.pendingSeek = invalid
    m.actionUntil = 0
    m.actionDirection = ""
    m.sequence = 0
    m.firstNative = invalid
    m.firstRendered = invalid
    m.lastBuffer = invalid
    m.watchdogReason = ""
    m.nativePollAt = -1000
    m.nativePollSignature = ""
    m.hlsStartupIsolation = false
    m.hlsPrebufferPending = false
    m.mediaNode = invalid
    m.hlsRetryCount = 0
    m.hlsRestartStage = 0
    m.hlsRestartAt = 0
    m.lastTransportDrawAt = -1000
    m.watch = invalid
    applyPlayerTheme()
end sub

function playerSurfaceUri(name as string) as string
    prefix = "pkg:/images/newplayer-"
    if m.top.theme = "classic" then prefix += "classic-"
    return prefix + name + ".png"
end function

' Changing material must not change decoder state, transport visibility, or
' focus. Callbacks before init are harmless; init reapplies once nodes exist.
sub applyPlayerTheme()
    if m.capsule <> invalid then m.capsule.uri = playerSurfaceUri("capsule")
    if m.titleShade <> invalid then m.titleShade.uri = playerSurfaceUri("title-shade")
    if m.centerSurface <> invalid then m.centerSurface.uri = playerSurfaceUri("control-focus")
    if m.previewMask <> invalid
        m.previewMask.uri = "pkg:/images/ui/live-preview-mask.png"
        if m.top.theme = "classic" then m.previewMask.uri = "pkg:/images/ui/live-preview-mask-classic.png"
    end if
    applyControlSurfaces()
end sub

sub applyControlSurfaces()
    if m.rewindSurface = invalid or m.forwardSurface = invalid then return
    m.rewindSurface.uri = playerSurfaceUri("control")
    m.forwardSurface.uri = playerSurfaceUri("control")
    if m.monotonic = invalid or m.actionUntil = invalid then return
    if m.monotonic.totalMilliseconds() < m.actionUntil
        if m.actionDirection = "left" then m.rewindSurface.uri = playerSurfaceUri("control-pressed")
        if m.actionDirection = "right" then m.forwardSurface.uri = playerSurfaceUri("control-pressed")
    end if
end sub

sub onActiveChanged()
    if m.closing then return
    if not m.top.active
        closePlayback()
    else if m.mediaOpen
        m.top.visible = true
        applyPresentation()
    end if
end sub

sub onPresentationChanged()
    applyPresentation()
end sub

sub onPreviewRectChanged()
    applyPresentation()
end sub

function isPreviewPresentation() as boolean
    return m.top.presentation = "preview"
end function

' Presentation changes only geometry and overlays. Keep the same native Video
' and ContentNode so opening/closing fullscreen does not reload a live stream.
sub applyPresentation()
    if m.decoder = invalid or m.panel = invalid or m.backdrop = invalid then return
    preview = isPreviewPresentation()
    m.top.focusable = not preview
    m.backdrop.visible = not preview
    if preview
        if m.displayMenuOpen then closeDisplayMenu()
        if m.playerOptionsMenuOpen then closePlayerOptionsMenu()
        if m.audioMenuOpen then closeAudioMenu()
        if m.subtitleMenuOpen then closeSubtitleMenu()
        rect = plusPreviewBounds(m.top.previewRect)
        if m.videoViewport <> invalid
            m.videoViewport.translation = [rect[0],rect[1]]
            m.videoViewport.clippingRect = [0,0,rect[2],rect[3]]
        end if
        m.decoder.translation = [0,0]
        m.decoder.width = rect[2]
        m.decoder.height = rect[3]
        m.decoder.scaleRotateCenter = [rect[2]/2,rect[3]/2]
        m.decoder.scale = [1.0,1.0]
        m.panel.visible = false
        if m.top.hasFocus() then m.top.setFocus(false)
    else
        if m.videoViewport <> invalid
            m.videoViewport.translation = [0,0]
            m.videoViewport.clippingRect = [0,0,1920,1080]
        end if
        m.decoder.translation = [0,0]
        m.decoder.width = 1920
        m.decoder.height = 1080
        applyVideoZoom()
        if m.mediaOpen
            if m.hlsStartupIsolation
                m.panel.visible = false
            else if m.phase = "playing"
                revealTransport()
            else
                m.panel.visible = false
            end if
            m.top.setFocus(true)
        end if
    end if
    if m.startupOverlay <> invalid
        m.startupOverlay.visible = not preview and m.mediaOpen and m.phase <> "playing" and not m.failed
    end if
    if m.previewMask <> invalid
        if preview
            rect = plusPreviewBounds(m.top.previewRect)
            m.previewMask.translation = [rect[0],rect[1]]
            m.previewMask.width = rect[2]
            m.previewMask.height = rect[3]
        else
            m.previewMask.translation = [0,0]
            m.previewMask.width = 1920
            m.previewMask.height = 1080
        end if
        m.previewMask.visible = preview and m.mediaOpen
    end if
    m.decoder.visible = false
    if m.mediaOpen
        m.top.visible = true
        m.decoder.visible = not m.failed
        publishProgress(true)
    end if
end sub

' Zoom is a presentation-only transform. The viewport clips the enlarged Video
' node to the screen, so the decoder and stream remain open and seeking is untouched.
sub applyVideoZoom()
    if m.decoder = invalid then return
    zoom = 1.0
    if m.zoomLevels <> invalid and m.zoomIndex >= 0 and m.zoomIndex < m.zoomLevels.count()
        zoom = m.zoomLevels[m.zoomIndex]
    end if
    width = m.decoder.width
    height = m.decoder.height
    if width <= 0 or height <= 0 then return
    m.decoder.scaleRotateCenter = [width/2,height/2]
    m.decoder.scale = [zoom,zoom]
    print "[RokuPlus display] zoom="; zoom
end sub

' Bounds are in the scene's 1920x1080 design coordinates, independent of the
' panel's physical resolution. Malformed rectangles fall back to the live card.
function plusPreviewBounds(value as dynamic) as object
    fallback = [294,206,1016,572]
    if GetInterface(value,"ifArray") = invalid then return fallback
    if value.count() <> 4 then return fallback
    for each coordinate in value
        if not plusNativeNumeric(coordinate) then return fallback
        if coordinate <> coordinate then return fallback
        if coordinate < 0 or coordinate > 1920 then return fallback
    end for
    if value[2] <= 0 or value[3] <= 0 then return fallback
    if value[0]+value[2] > 1920 or value[1]+value[3] > 1080 then return fallback
    return [value[0],value[1],value[2],value[3]]
end function

sub onIntroDbDataChanged(event as object)
    data = event.getData()
    if type(data) <> "roAssociativeArray" then return
    if type(m.current) <> "roAssociativeArray" then return
    if data.requestId <> m.current.requestId then return
    m.introDbData = data
    m.skipPromptDismissed = false
    updateSkipSegmentPrompt()
end sub

sub updateSkipSegmentPrompt()
    if m.skipPromptDismissed or type(m.introDbData) <> "roAssociativeArray" or m.introDbData.ok <> true
        m.skipPromptVisible = false
        m.skipPromptTarget = invalid
        if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = false
        return
    end if
    if m.live or m.failed or not m.mediaOpen
        m.skipPromptVisible = false
        if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = false
        return
    end if
    outro = m.introDbData.outro
    if type(outro) <> "roAssociativeArray"
        m.skipPromptVisible = false
        if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = false
        return
    end if
    confidence = outro.confidence
    if GetInterface(confidence,"ifFloat") <> invalid or GetInterface(confidence,"ifDouble") <> invalid
        if confidence < 0.55
            m.skipPromptVisible = false
            if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = false
            return
        end if
    end if
    startAt = -1.0
    endAt = -1.0
    if GetInterface(outro.start_sec,"ifFloat") <> invalid or GetInterface(outro.start_sec,"ifDouble") <> invalid or GetInterface(outro.start_sec,"ifInt") <> invalid or GetInterface(outro.start_sec,"ifLongInt") <> invalid then startAt = outro.start_sec
    if GetInterface(outro.end_sec,"ifFloat") <> invalid or GetInterface(outro.end_sec,"ifDouble") <> invalid or GetInterface(outro.end_sec,"ifInt") <> invalid or GetInterface(outro.end_sec,"ifLongInt") <> invalid then endAt = outro.end_sec
    if startAt < 0 and outro.start_ms <> invalid then startAt = outro.start_ms / 1000.0
    if endAt < 0 and outro.end_ms <> invalid then endAt = outro.end_ms / 1000.0
    position = playerPosition()
    if startAt < 0 or endAt <= startAt or position = invalid or position < startAt or position >= endAt
        m.skipPromptVisible = false
        m.skipPromptTarget = invalid
        if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = false
        return
    end if
    target = endAt
    label = "OK - SALTAR CRÉDITOS"
    post = m.introDbData.post_credits
    if type(post) = "roAssociativeArray"
        postStart = -1.0
        if GetInterface(post.start_sec,"ifFloat") <> invalid or GetInterface(post.start_sec,"ifDouble") <> invalid or GetInterface(post.start_sec,"ifInt") <> invalid or GetInterface(post.start_sec,"ifLongInt") <> invalid then postStart = post.start_sec
        if postStart < 0 and post.start_ms <> invalid then postStart = post.start_ms / 1000.0
        if postStart > position + 1
            target = postStart
            label = "OK - SALTAR A ESCENA POSTCRÉDITOS"
        end if
    end if
    if target <= position + 1
        m.skipPromptVisible = false
        m.skipPromptTarget = invalid
        if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = false
        return
    end if
    m.skipPromptTarget = target
    m.skipPromptVisible = true
    if m.skipPromptText <> invalid then m.skipPromptText.text = label
    if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = true
end sub

sub skipToDetectedSegment()
    target = plusClockValue(m.skipPromptTarget)
    origin = playerPosition()
    state = m.decoder.state
    if target = invalid or origin = invalid or target <= origin + 1 then return
    if state <> "playing" and state <> "paused" then return
    cancelPendingResumeForUserSeek()
    m.pendingSeek = {target:target,dueAt:m.monotonic.totalMilliseconds()+180}
    m.skipPromptDismissed = true
    m.skipPromptVisible = false
    m.skipPromptTarget = invalid
    if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = false
    m.notice = "Saltando a " + plusClockText(target)
    m.noticeUntil = m.monotonic.totalMilliseconds()+5000
    drawTransport()
end sub

sub onEndScreenDataChanged(event as object)
    data = event.getData()
    if type(data) <> "roAssociativeArray" then return
    m.endCountdownActive = false
    m.endCountdownRemaining = 0
    if type(data.items) = "roArray" then m.endScreenItems = data.items else m.endScreenItems = []
    m.endScreenIndex = 0
    ' Show the recommendation card over the live video; do not pause or stop
    ' the decoder, so the credits continue underneath the translucent panel.
    m.endScreenOpen = true
    if m.endScreenGroup <> invalid then m.endScreenGroup.visible = true
    drawPlaybackEndScreen()
end sub

sub drawPlaybackEndScreen()
    if m.endScreenHeading = invalid then return
    data = m.top.endScreenData
    heading = "PELÍCULAS SIMILARES"
    isEpisode = false
    if type(data) = "roAssociativeArray"
        isEpisode = data.kind = "episode"
        if isEpisode then heading = "SIGUIENTE EPISODIO"
        if GetInterface(data.heading,"ifString") <> invalid then heading = data.heading
    end if
    m.endScreenHeading.text = heading
    if isEpisode
        m.endScreenHeading.translation = [1510, 828]
        m.endScreenHeading.width = 360
        m.endScreenHeading.height = 36
        m.endScreenHeading.horizAlign = "center"
        m.endScreenHeading.vertAlign = "center"
    else
        m.endScreenHeading.translation = [0, 650]
        m.endScreenHeading.width = 1920
        m.endScreenHeading.height = 58
        m.endScreenHeading.horizAlign = "center"
        m.endScreenHeading.vertAlign = "center"
    end if
    if m.endScreenMessage <> invalid then m.endScreenMessage.text = ""
    if m.endMovieLayout <> invalid then m.endMovieLayout.visible = not isEpisode
    if m.endEpisodeLayout <> invalid then m.endEpisodeLayout.visible = isEpisode
    if isEpisode
        if m.endMovieSelection <> invalid then m.endMovieSelection.visible = false
        if m.endScreenItems.count() > 0
            item = m.endScreenItems[0]
            poster = ""
            title = "Siguiente episodio"
            seasonNumber = 0
            episodeNumber = 0
            if type(item) = "roAssociativeArray"
                if GetInterface(item.poster,"ifString") <> invalid then poster = item.poster
                if GetInterface(item.title,"ifString") <> invalid then title = item.title
                if item.doesExist("season") then seasonNumber = item.season
                if item.doesExist("episode") then episodeNumber = item.episode
            end if
            if m.endEpisodePoster <> invalid
                m.endEpisodePoster.uri = poster
                m.endEpisodePoster.visible = poster <> ""
            end if
            if m.endEpisodeTitle <> invalid then m.endEpisodeTitle.text = title
            if m.endEpisodeMeta <> invalid
                m.endEpisodeMeta.text = "Temporada " + seasonNumber.toStr() + "  ·  Episodio " + episodeNumber.toStr()
            end if
            if not m.playbackFinished and not m.endCountdownActive
                m.endCountdownRemaining = 10
                m.endCountdownLastAt = m.monotonic.totalMilliseconds()
                m.endCountdownActive = true
                m.pulse.control = "start"
            end if
            updateEndCountdownVisual()
        else
            m.endCountdownActive = false
            emptyMessage = "No hay más episodios disponibles."
            if type(data) = "roAssociativeArray"
                if GetInterface(data.message,"ifString") <> invalid and data.message <> "" then emptyMessage = data.message
            end if
            if m.endEpisodeTitle <> invalid then m.endEpisodeTitle.text = emptyMessage
            if m.endEpisodeMeta <> invalid then m.endEpisodeMeta.text = ""
            if m.endCountdownText <> invalid then m.endCountdownText.text = ""
        end if
    else
        m.endCountdownActive = false
        if m.endEpisodePoster <> invalid then m.endEpisodePoster.visible = false
        for posterIndex = 0 to 5
            posterNode = m.endMoviePosters[posterIndex]
            titleNode = m.endMovieTitles[posterIndex]
            if posterIndex < m.endScreenItems.count()
                item = m.endScreenItems[posterIndex]
                posterUri = ""
                titleText = "Película"
                if type(item) = "roAssociativeArray"
                    if GetInterface(item.poster,"ifString") <> invalid then posterUri = item.poster
                    if GetInterface(item.title,"ifString") <> invalid then titleText = item.title
                    if GetInterface(item.year,"ifString") <> invalid and item.year <> "" then titleText += chr(10) + item.year
                end if
                if posterNode <> invalid
                    posterNode.uri = posterUri
                    posterNode.visible = posterUri <> ""
                    posterNode.opacity = 1.0
                    if posterIndex <> m.endScreenIndex then posterNode.opacity = 0.72
                end if
                if titleNode <> invalid
                    titleNode.text = titleText
                    titleNode.visible = true
                    titleNode.opacity = 1.0
                    if posterIndex <> m.endScreenIndex then titleNode.opacity = 0.72
                end if
            else
                if posterNode <> invalid
                    posterNode.uri = ""
                    posterNode.visible = false
                end if
                if titleNode <> invalid
                    titleNode.text = ""
                    titleNode.visible = false
                end if
            end if
        end for
        if m.endMovieSelection <> invalid and m.endScreenItems.count() > 0
            xPositions = [0,190,380,570,760,950]
            m.endMovieSelection.translation = [xPositions[m.endScreenIndex],0]
            m.endMovieSelection.visible = false
        else if m.endMovieSelection <> invalid
            m.endMovieSelection.visible = false
        end if
        if m.endScreenItems.count() = 0
            emptyMessage = "No encontramos películas similares en el catálogo disponible."
            if type(data) = "roAssociativeArray"
                if GetInterface(data.message,"ifString") <> invalid and data.message <> "" then emptyMessage = data.message
            end if
            if m.endScreenMessage <> invalid then m.endScreenMessage.text = emptyMessage
        end if
    end if
    if m.endScreenMessage <> invalid
        m.endScreenMessage.text += chr(10) + "◀ / ▶ Elegir   OK Reproducir   BACK Salir"
    end if
end sub

sub updateEndCountdownVisual()
    if m.endCountdownText <> invalid then m.endCountdownText.text = m.endCountdownRemaining.toStr()
    if type(m.endCountdownDots) <> "roArray" then return
    dotsToShow = m.endCountdownRemaining
    if dotsToShow < 0 then dotsToShow = 0
    if dotsToShow > m.endCountdownDots.count() then dotsToShow = m.endCountdownDots.count()
    for i = 0 to m.endCountdownDots.count() - 1
        dot = m.endCountdownDots[i]
        if dot <> invalid then dot.visible = i < dotsToShow
    end for
end sub

sub movePlaybackEndSelection(direction as integer)
    if m.endScreenItems.count() = 0 then return
    m.endScreenIndex += direction
    if m.endScreenIndex < 0 then m.endScreenIndex = m.endScreenItems.count()-1
    if m.endScreenIndex >= m.endScreenItems.count() then m.endScreenIndex = 0
    drawPlaybackEndScreen()
end sub

sub selectPlaybackEndItem()
    if m.endScreenItems.count() = 0 then return
    if m.endScreenIndex < 0 or m.endScreenIndex >= m.endScreenItems.count() then return
    selected = m.endScreenItems[m.endScreenIndex]
    m.endCountdownActive = false
    m.endCountdownRemaining = 0
    m.pulse.control = "stop"
    m.endScreenItems = []
    m.endScreenIndex = 0
    m.endScreenOpen = true
    if m.endScreenItemsLabel <> invalid then m.endScreenItemsLabel.text = "ABRIENDO TÍTULO... " + chr(10) + "Espera un momento. BACK para salir."
    if m.endScreenMessage <> invalid then m.endScreenMessage.text = "ABRIENDO TÍTULO...  ·  BACK para salir."
    if m.endScreenGroup <> invalid then m.endScreenGroup.visible = true
    if m.endMovieLayout <> invalid then m.endMovieLayout.visible = false
    if m.endEpisodeLayout <> invalid then m.endEpisodeLayout.visible = false
    m.top.endSelection = {item:selected,requestId:m.current.requestId}
end sub

sub openRequest()
    supplied = m.top.request
    if type(supplied) <> "roAssociativeArray" then return
    if GetInterface(supplied.url, "ifString") = invalid then return
    if len(supplied.url) = 0 then return
    ' Stop the preceding decoder without emitting a close for the new request.
    m.mediaOpen = false
    m.endScreenOpen = false
    m.endScreenItems = []
    if m.endScreenGroup <> invalid then m.endScreenGroup.visible = false
    m.pulse.control = "stop"
    if m.startupTimer <> invalid then m.startupTimer.control = "stop"
    m.decoder.visible = false
    m.decoder.control = "stop"
    m.decoder.content = invalid
    m.generation++
    m.monotonic.mark()
    m.current = supplied
    cancelStreamXArtworkTask()
    m.streamXRequestId = m.generation.toStr()
    m.introDbData = invalid
    m.skipPromptVisible = false
    m.skipPromptDismissed = false
    m.skipPromptTarget = invalid
    if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = false
    m.mediaNode = invalid
    m.hlsRetryCount = 0
    m.hlsPrebufferPending = false
    m.hlsRestartStage = 0
    m.hlsRestartAt = 0
    m.segmentUrls = invalid
    m.segmentIndex = 0
    m.segmentTransitioning = false
    m.segmentRestartStage = 0
    m.segmentPendingContent = invalid
    m.segmentRestartAt = 0
    m.segmentMode = false
    m.nativePlaylistMode = false
    m.tsRelayMode = false
    m.tsRelayPending = false
    m.tsRelaySegments = invalid
    m.tsRelayDurations = invalid
    m.tsRelayDuration = invalid
    m.tsRelayPositionOffset = 0.0
    m.tsRelayLocalSeekPending = invalid
    m.tsRelayPrerollRetryUsed = false
    m.tsRelayRestartStage = 0
    m.tsRelayRestartAt = 0
    m.tsRelayRestartSegment = -1
    m.tsRelayLocalIp = ""
    if type(supplied.segmentUrls) = "roArray" and supplied.segmentUrls.count() > 1
        m.segmentUrls = supplied.segmentUrls
        m.segmentMode = true
        m.nativePlaylistMode = true
    end if
    m.ticket = invalid
    m.pendingSeek = invalid
    m.actionUntil = 0
    m.actionDirection = ""
    m.lastBuffer = invalid
    m.nativePollAt = -1000
    m.nativePollSignature = ""
    m.firstNative = invalid
    m.firstRendered = invalid
    m.watchdogReason = ""
    m.failed = false
    m.closing = false
    m.alreadyClosed = false
    m.live = supplied.kind = "live"
    m.wantPaused = supplied.startPaused = true
    m.panelUntil = 6000
    m.noticeUntil = 0
    m.notice = ""
    m.audioMenuOpen = false
    if m.audioMenuGroup <> invalid then m.audioMenuGroup.visible = false
    m.subtitleMenuOpen = false
    if m.subtitleMenuGroup <> invalid then m.subtitleMenuGroup.visible = false
    m.displayMenuOpen = false
    m.displayMenuIndex = m.zoomIndex
    if m.displayMenuGroup <> invalid then m.displayMenuGroup.visible = false
    m.audioTracks = []
    m.audioTrackIndex = 0
    cancelSubtitleSearchTask()
    m.subtitleTracks = []
    m.subtitleTrackIndex = 0
    m.subtitleOnlineResults = []
    m.subtitleOnlineBusy = false
    m.subtitleOnlineOperation = ""
    m.externalSubtitleCues = []
    m.externalSubtitleIndex = 0
    m.externalSubtitleLastPosition = -1
    m.externalSubtitleSelectedIndex = 0
    if m.externalSubtitleGroup <> invalid then m.externalSubtitleGroup.visible = false
    m.bufferSince = 0
    m.watch = plusWatchdogCreate(0)
    m.lastProgressAt = -1000
    m.phase = "opening"
    m.resumePending = invalid
    m.resumeStartedAt = m.monotonic.totalMilliseconds()
    m.resumeAttempts = 0
    m.resumeFailed = false
    m.resumeFailedPosition = invalid
    m.resumeFailedAt = 0
    resumeValue = plusClockValue(supplied.resumePosition)
    if (not m.segmentMode or supplied.tsRelayEnabled = true) and not m.live and resumeValue <> invalid and resumeValue > 15 and resumeValue < 172800 then m.resumePending = resumeValue
    m.titleText.text = "Reproducción"
    if GetInterface(supplied.title, "ifString") <> invalid then m.titleText.text = left(supplied.title, 130)
    if m.startupTitle <> invalid then m.startupTitle.text = UCase(m.titleText.text)
    if m.startupTitle <> invalid then m.startupTitle.visible = true
    if m.startupLogo <> invalid
        m.startupLogo.uri = ""
        m.startupLogo.visible = false
    end if
    if m.startupLogoPulse <> invalid then m.startupLogoPulse.control = "stop"
    if m.startupBanner <> invalid
        bannerUri = ""
        if GetInterface(supplied.background,"ifString") <> invalid then bannerUri = supplied.background
        if bannerUri = "" and GetInterface(supplied.poster,"ifString") <> invalid then bannerUri = supplied.poster
        m.startupBanner.uri = bannerUri
        m.startupBanner.visible = bannerUri <> ""
    end if
    if m.startupLoadingText <> invalid then m.startupLoadingText.text = "CARGANDO..."
    m.startupCharIndex = 0
    if m.startupTimer <> invalid then m.startupTimer.control = "stop"
    startStreamXArtwork(supplied)
    ' Compact metadata row: only display values supplied by the catalogue.
    metaParts = []
    if GetInterface(supplied.year, "ifString") <> invalid and len(supplied.year) > 0 then metaParts.push(supplied.year)
    if GetInterface(supplied.year, "ifInt") <> invalid then metaParts.push(supplied.year.toStr())
    if GetInterface(supplied.quality, "ifString") <> invalid and len(supplied.quality) > 0 then metaParts.push(supplied.quality)
    if GetInterface(supplied.episode, "ifString") <> invalid and len(supplied.episode) > 0 then metaParts.push(supplied.episode)
    m.metaText.text = ""
    for each metaPart in metaParts
        if m.metaText.text <> "" then m.metaText.text += "   ·   "
        m.metaText.text += metaPart
    end for
    format = "mp4"
    if GetInterface(supplied.streamFormat, "ifString") <> invalid then format = lcase(supplied.streamFormat)
    if format = "mpegts" then format = "ts"
    if format = "m3u8" then format = "hls"
    if supplied.tsRelayEnabled = true and type(supplied.segmentUrls) = "roArray" and supplied.segmentUrls.count() > 1
        m.tsRelayMode = true
        m.tsRelaySegments = supplied.segmentUrls
        m.tsRelayDurations = invalid
        m.tsRelayOffsets = invalid
        m.tsRelayDuration = invalid
        if type(supplied.segmentDurations) = "roArray" and supplied.segmentDurations.count() = m.tsRelaySegments.count()
            durationTotal = 0.0
            durationValid = true
            segmentOffsets = []
            for each segmentDuration in supplied.segmentDurations
                parsedDuration = plusClockValue(segmentDuration)
                if parsedDuration = invalid or parsedDuration <= 0 or parsedDuration > 3600
                    durationValid = false
                    exit for
                end if
                segmentOffsets.push(durationTotal)
                durationTotal += parsedDuration
            end for
            if durationValid and durationTotal > 0
                m.tsRelayDurations = supplied.segmentDurations
                m.tsRelayOffsets = segmentOffsets
                m.tsRelayDuration = durationTotal
                print "[RokuPlus ts-relay] seek_metadata segments="; m.tsRelayDurations.count(); " duration="; m.tsRelayDuration
            else
                print "[RokuPlus ts-relay] seek_metadata_invalid"
            end if
        else
            print "[RokuPlus ts-relay] seek_metadata_missing"
        end if
        m.segmentMode = false
        m.nativePlaylistMode = false
        format = "ts"
        print "[RokuPlus ts-relay] mode=single-http-connection segments="; m.tsRelaySegments.count()
    end if
    ' A clean-TS diagnostic is opt-in. Never replace a provider stream merely
    ' because a diagnostic URL happens to be present in a playback descriptor.
    diagnosticTs = false
    diagnosticUrl = ""
    diagnosticTsEnabled = false
    if supplied.doesExist("diagnosticTsEnabled") then diagnosticTsEnabled = supplied.diagnosticTsEnabled = true
    if diagnosticTsEnabled
        diagnosticUrl = supplied.hlsDiagnosticTsUrl
        if GetInterface(diagnosticUrl, "ifString") <> invalid
            if len(diagnosticUrl) > 0 and len(diagnosticUrl) <= 4096 and left(diagnosticUrl,8) = "https://"
                diagnosticTs = true
                format = "ts"
                m.segmentUrls = invalid
                m.segmentIndex = 0
                m.segmentMode = false
                m.nativePlaylistMode = false
                m.resumePending = invalid
                print "[RokuPlus hls-id3-test] mode=clean-ts-direct"
            end if
        end if
    end if
    m.diagnosticTsActive = diagnosticTs
    m.effectiveStreamFormat = format
    m.hlsStartupIsolation = format = "hls"
    m.hlsPrebufferPending = m.hlsStartupIsolation
    ' D213X diagnostic: apply the TV's native 720p ceiling to every stream
    ' format, including TS. This is isolated to the d213x test branch.
    if m.decoder.hasField("maxVideoDecodeResolution")
        m.decoder.maxVideoDecodeResolution = [1280, 720]
        print "[RokuPlus decoder-memory-test] maxVideoDecodeResolution=1280x720 format="; format
    else
        print "[RokuPlus decoder-memory-test] maxVideoDecodeResolution=unsupported format="; format
    end if
    if m.hlsStartupIsolation
        ' Keep startup diagnostics lightweight for HLS while testing the decoder memory cap.
        if m.decoder.hasField("enableDecoderStats") then m.decoder.enableDecoderStats = false
        print "[RokuPlus hls-minimal] decoderStats=disabled nativePoll=deferred"
        print "[RokuPlus hls-ui] startup isolation enabled"
    else
        if m.decoder.hasField("enableDecoderStats") then m.decoder.enableDecoderStats = true
    end if
    ' Keep the Spanish-first preference configured in init().
    ' Roku falls back when a matching Spanish rendition is not available.
    ' Do not overwrite the write-only Video preference for each title.
    if m.audioSelectionPreferenceSet
        print "[RokuPlus decoder] audioSelection=Spanish-preference-retained format="; format
    end if
    media = CreateObject("roSGNode", "ContentNode")
    ' 3.5.56: restore the real provider URL after the successful Mux media-playlist control test.
    ' Keep native startup polling and all HLS isolation diagnostics enabled.
    playbackUrl = supplied.url
    referenceHlsTest = diagnosticTs
    if diagnosticTs
        playbackUrl = diagnosticUrl
    end if
    if format = "hls" and not diagnosticTs
        print "[RokuPlus hls-test] source=provider-native"
    end if
    media.url = playbackUrl
    media.title = m.titleText.text
    media.streamFormat = format
    media.live = false
    media.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    ' Build headers in a local resizable array. SceneGraph node fields may
    ' expose a fixed-size copy after assignment, so do not mutate the field.
    requestHeaders = CreateObject("roArray", 2, true)
    requestHeaders.push("User-Agent: RokuPlus/1.0")
    if type(supplied.mediaHeaders) = "roAssociativeArray" and not referenceHlsTest
        agent = supplied.mediaHeaders["User-Agent"]
        if GetInterface(agent, "ifString") <> invalid
            if len(agent) > 0 and len(agent) <= 512 and instr(1,agent,chr(13)) = 0 and instr(1,agent,chr(10)) = 0 then requestHeaders[0] = "User-Agent: " + agent
        end if
        referer = supplied.mediaHeaders["Referer"]
        if GetInterface(referer, "ifString") <> invalid
            if len(referer) <= 2048 and instr(1,referer,chr(13)) = 0 and instr(1,referer,chr(10)) = 0
                if left(referer,7) = "http://" or left(referer,8) = "https://" then requestHeaders.push("Referer: " + referer)
            end if
        end if
    end if
    media.httpHeaders = requestHeaders

    if m.tsRelayMode
        m.tsStreamServer.segments = m.tsRelaySegments
        m.tsStreamServer.mediaHeaders = supplied.mediaHeaders
        m.tsRelayAccessKey = CreateObject("roDeviceInfo").getRandomUUID()
        m.tsStreamServer.accessKey = m.tsRelayAccessKey
        m.tsStreamServer.stopRequested = false
        m.tsStreamServer.segmentsSent = 0
        m.tsStreamServer.nextSegmentIndex = 0
        m.tsStreamServer.bytesSent = 0
        if m.tsStreamServer.status <> "listening"
            m.tsStreamServer.status = "starting"
            m.tsStreamServer.control = "RUN"
        end if
        m.tsRelayPending = true
        m.tsRelayStartedAt = m.monotonic.totalMilliseconds()
        m.decoder.contentIsPlaylist = false
        m.mediaNode = media
        m.mediaOpen = true
        m.top.visible = true
        m.top.active = true
        m.decoder.visible = true
        applyPresentation()
        m.pulse.duration = 0.25
        m.pulse.control = "start"
        startStartupTitleAnimation()
        emitDiagnostic("ts_relay_starting")
        return
    end if


    ' Use Roku's native Video playlist for sequential TS items. This lets the
    ' Video node own segment transitions instead of stopping/replacing content
    ' in BrightScript after every ~10-second segment.
    if m.nativePlaylistMode
        playlist = CreateObject("roSGNode", "ContentNode")
        playlistCount = 0
        for each segmentUrl in m.segmentUrls
            if GetInterface(segmentUrl,"ifString") <> invalid and left(segmentUrl,8) = "https://"
                child = CreateObject("roSGNode", "ContentNode")
                child.url = segmentUrl
                child.title = m.titleText.text
                child.streamFormat = "ts"
                child.live = false
                child.httpCertificatesFile = "common:/certs/ca-bundle.crt"
                child.httpHeaders = requestHeaders
                playlist.appendChild(child)
                playlistCount++
            end if
        end for
        if playlistCount > 1
            media = playlist
            print "[RokuPlus playlist] native=true children=";playlistCount
        else
            m.nativePlaylistMode = false
            print "[RokuPlus playlist] fallback=single-segment children=";playlistCount
        end if
    end if

    m.decoder.contentIsPlaylist = m.nativePlaylistMode
    if format = "hls"
        print "[RokuPlus hls-config] format="; media.streamFormat; " live="; media.live; " contentIsPlaylist="; m.decoder.contentIsPlaylist; " headers="; media.httpHeaders.count()
    end if
    m.decoder.enableUI = false
    m.decoder.enableTrickPlay = false
    m.decoder.notificationInterval = 0.5
    m.decoder.autoplayAfterSeek = true
    m.accuracyMode = "unavailable"
    if m.decoder.hasField("seekMode")
        m.decoder.seekMode = "accurate"
        m.accuracyMode = m.decoder.seekMode
    end if
    m.mediaNode = media
    m.decoder.content = media
    m.mediaOpen = true
    m.top.visible = true
    m.top.active = true
    applyPresentation()
    if m.hlsStartupIsolation
        m.decoder.control = "prebuffer"
        print "[RokuPlus hls-prebuffer] action=prebuffer"
    else
        m.decoder.control = "play"
    end if
    m.pulse.control = "start"
    startStartupTitleAnimation()
    emitDiagnostic("open")
    if not m.hlsStartupIsolation then drawTransport()
end sub

sub closePlayback()
    if m.closing then return
    if m.alreadyClosed
        m.top.visible = false
        if m.previewMask <> invalid then m.previewMask.visible = false
        return
    end if
    closedRequest = {generation:m.generation}
    if type(m.current) = "roAssociativeArray"
        if GetInterface(m.current.itemId,"ifString") <> invalid then closedRequest.itemId = m.current.itemId
        if GetInterface(m.current.requestId,"ifString") <> invalid then closedRequest.requestId = m.current.requestId
    end if
    m.closing = true
    emitDiagnostic("close")
    m.mediaOpen = false
    cancelStreamXArtworkTask()
    m.ticket = invalid
    m.pendingSeek = invalid
    m.tsRelayLocalSeekPending = invalid
    m.watch = invalid
    m.panel.visible = false
    m.decoder.visible = false
    m.endScreenOpen = false
    if m.endScreenGroup <> invalid then m.endScreenGroup.visible = false
    m.displayMenuOpen = false
    if m.displayMenuGroup <> invalid then m.displayMenuGroup.visible = false
    m.playerOptionsMenuOpen = false
    if m.playerOptionsMenuGroup <> invalid then m.playerOptionsMenuGroup.visible = false
    if m.previewMask <> invalid then m.previewMask.visible = false
    m.top.visible = false
    m.pulse.control = "stop"
    m.decoder.control = "stop"
    m.decoder.content = invalid
    cancelSubtitleSearchTask()
    if m.externalSubtitleGroup <> invalid then m.externalSubtitleGroup.visible = false
    m.externalSubtitleCues = []
    m.mediaNode = invalid
    m.hlsRestartStage = 0
    m.current = invalid
    m.top.request = invalid
    m.top.active = false
    m.alreadyClosed = true
    m.closing = false
    m.top.closedRequest = closedRequest
    m.top.closed = true
end sub

function advanceSequentialSegment() as boolean
    if m.nativePlaylistMode then return false
    if not m.segmentMode or type(m.segmentUrls) <> "roArray" then return false
    if m.segmentTransitioning then return true
    nextIndex = m.segmentIndex + 1
    if nextIndex >= m.segmentUrls.count() then return false
    nextUrl = m.segmentUrls[nextIndex]
    if GetInterface(nextUrl,"ifString") = invalid or left(nextUrl,8) <> "https://" then return false
    media = CreateObject("roSGNode","ContentNode")
    media.url = nextUrl
    media.title = m.titleText.text
    media.streamFormat = "ts"
    media.live = false
    media.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    requestHeaders = CreateObject("roArray",2,true)
    requestHeaders.push("User-Agent: RokuPlus/1.0")
    if type(m.current) = "roAssociativeArray" and type(m.current.mediaHeaders) = "roAssociativeArray"
        agent = m.current.mediaHeaders["User-Agent"]
        if GetInterface(agent,"ifString") <> invalid
            if len(agent) > 0 and len(agent) <= 512 and instr(1,agent,chr(13)) = 0 and instr(1,agent,chr(10)) = 0 then requestHeaders[0] = "User-Agent: "+agent
        end if
        referer = m.current.mediaHeaders["Referer"]
        if GetInterface(referer,"ifString") <> invalid
            if len(referer) <= 2048 and instr(1,referer,chr(13)) = 0 and instr(1,referer,chr(10)) = 0
                if left(referer,7) = "http://" or left(referer,8) = "https://" then requestHeaders.push("Referer: "+referer)
            end if
        end if
    end if
    media.httpHeaders = requestHeaders
    m.segmentIndex = nextIndex
    m.segmentTransitioning = true
    m.phase = "segment_transition"
    m.failed = false
    m.ticket = invalid
    m.pendingSeek = invalid
    m.resumePending = invalid
    m.wantPaused = false
    m.lastProgressAt = -1000
    m.lastBuffer = invalid
    m.bufferSince = 0
    m.decoder.visible = true
    m.segmentPendingContent = media
    m.segmentRestartStage = 1
    m.segmentRestartAt = 0
    m.decoder.control = "stop"
    print "[RokuPlus segment] queued index=";m.segmentIndex+1;" total=";m.segmentUrls.count()
    emitDiagnostic("segment_advance")
    return true
end function

sub onDecoderState()
    if not m.mediaOpen or m.closing then return
    m.phase = m.decoder.state
    if m.phase = "buffering"
        m.bufferSince = m.monotonic.totalMilliseconds()
        if m.ticket <> invalid
            m.ticket.sawBuffering = true
            ' A seek can legitimately take longer while Roku is buffering.
            ' Keep a hard 30-second limit for this buffering interval.
            m.ticket.deadlineAt = m.bufferSince + 30000
            m.ticket.bufferingTimeoutExtended = true
        end if
        if m.startupOverlay = invalid or not m.startupOverlay.visible
            if not m.hlsStartupIsolation then revealTransport()
        else
            m.panel.visible = false
        end if
    end if
    emitDiagnostic("state")
    if m.phase = "playing"
        if m.ticket <> invalid and m.ticket.bufferingTimeoutExtended = true
            ' Once playback resumes, allow a fresh 12 seconds for confirmation.
            m.ticket.deadlineAt = m.monotonic.totalMilliseconds() + 12000
            m.ticket.bufferingTimeoutExtended = false
        end if
        if m.startupTimer <> invalid then m.startupTimer.control = "stop"
        if m.startupLogoPulse <> invalid then m.startupLogoPulse.control = "stop"
        if m.startupOverlay <> invalid then m.startupOverlay.visible = false
        if m.hlsStartupIsolation
            m.hlsStartupIsolation = false
            revealTransport()
            print "[RokuPlus hls-ui] startup isolation released: playing"
        else
            revealTransport()
        end if
        m.segmentTransitioning = false
        m.bufferSince = invalid
        applyResumeSeek()
        ' Desired pause is persistent across rebuffering. A user Play clears
        ' it before resume, so a source that already stays paused is safe too.
        if m.wantPaused
            m.decoder.control = "pause"
            return
        end if
        m.panelUntil = m.monotonic.totalMilliseconds() + 6000
    else if m.phase = "paused"
        if m.ticket <> invalid and m.ticket.bufferingTimeoutExtended = true
            m.ticket.deadlineAt = m.monotonic.totalMilliseconds() + 12000
            m.ticket.bufferingTimeoutExtended = false
        end if
        m.bufferSince = invalid
        if not m.wantPaused
            m.decoder.control = "resume"
            return
        end if
        revealTransport()
    else if m.phase = "error"
        if m.effectiveStreamFormat = "hls" and type(m.current) = "roAssociativeArray" and m.current.fallbackTsRelayEnabled = true and type(m.current.fallbackSegmentUrls) = "roArray" and m.current.fallbackSegmentUrls.count() > 1
            fallbackRequest = {}
            for each fallbackKey in m.current
                fallbackRequest[fallbackKey] = m.current[fallbackKey]
            end for
            fallbackRequest.url = m.current.fallbackSegmentUrls[0]
            fallbackRequest.streamFormat = "ts"
            fallbackRequest.tsRelayEnabled = true
            fallbackRequest.segmentUrls = m.current.fallbackSegmentUrls
            fallbackRequest.segmentDurations = m.current.fallbackSegmentDurations
            fallbackRequest.fallbackTsRelayEnabled = false
            fallbackPosition = playerPosition()
            if fallbackPosition <> invalid and fallbackPosition > 0 then fallbackRequest.resumePosition = fallbackPosition
            print "[RokuPlus hls-fallback] action=ts-relay reason=native-hls-error position="; fallbackPosition
            m.top.request = fallbackRequest
            return
        end if
        m.hlsStartupIsolation = false
        if m.startupTimer <> invalid then m.startupTimer.control = "stop"
        if m.startupOverlay <> invalid then m.startupOverlay.visible = false
        m.failed = true
        m.ticket = invalid
        m.pendingSeek = invalid
        m.decoder.visible = false
        m.notice = "La fuente no respondió. OK para reintentar; Atrás para elegir otra."
        m.noticeUntil = 2147483647
        revealTransport()
    else if m.phase = "finished"
        ' Roku may follow a source error with finished. Keep the error/retry
        ' surface instead of treating that terminal event as a normal ending.
        if m.failed
            revealTransport()
        else
            if not m.nativePlaylistMode and advanceSequentialSegment() then return
            if m.live
                publishProgress(true)
                closePlayback()
                return
            end if
            publishProgress(true)
            if m.audioMenuOpen then closeAudioMenu()
            if m.subtitleMenuOpen then closeSubtitleMenu()
            if m.displayMenuOpen then closeDisplayMenu()
            if m.playerOptionsMenuOpen then closePlayerOptionsMenu()
            if m.externalSubtitleGroup <> invalid then m.externalSubtitleGroup.visible = false
            m.pulse.control = "stop"
            m.watch = invalid
            m.panel.visible = false
            m.playbackFinished = true
            m.endScreenOpen = true
            m.endScreenIndex = 0
            m.endCountdownActive = false
            m.endCountdownRemaining = 0
            if m.endScreenGroup <> invalid then m.endScreenGroup.visible = true
            drawPlaybackEndScreen()
            print "[RokuPlus playback] finished; showing in-player recommendations"
            return
        end if
    end if
    drawTransport()
    publishProgress(true)
end sub

sub applyResumeSeek()
    if m.resumePending = invalid or not m.mediaOpen or m.failed or m.live then return
    state = m.decoder.state
    if state <> "playing" and state <> "paused" then return
    if state = "paused" and not m.wantPaused then return
    if m.ticket <> invalid or m.pendingSeek <> invalid then return
    duration = playerDuration()
    if duration = invalid or duration <= 0 then return
    resumeAt = m.resumePending
    if duration <= resumeAt + 20
        m.resumePending = invalid
        emitDiagnostic("resume_out_of_range")
        return
    end if
    currentPosition = playerPosition()
    ' If the native clock is already at the saved point, avoid an unnecessary seek.
    ' Do not discard the bookmark merely because metadata arrived after playback began.
    if currentPosition <> invalid and abs(currentPosition-resumeAt) <= 1.25
        m.resumePending = invalid
        emitDiagnostic("resume_already_at_target")
        return
    end if
    m.resumePending = invalid
    m.resumeAttempts = 1
    m.pendingSeek = {target:resumeAt,dueAt:m.monotonic.totalMilliseconds()+150,isResume:true}
    emitDiagnostic("resume_queued")
end sub

sub onNativePosition()
    if not m.mediaOpen then return
    p = playerPosition()
    if m.firstNative = invalid and p <> invalid
        m.firstNative = p
        emitDiagnostic("first_native_position")
    end if
    if m.ticket <> invalid then emitDiagnostic("position")
    applyResumeSeek()
    verifySeekResult()
    publishProgress()
end sub

sub onRenderedPosition()
    if not m.mediaOpen then return
    sample = renderedFields()
    if m.firstRendered = invalid and sample.video <> invalid
        m.firstRendered = sample.video
        emitDiagnostic("first_rendered_position")
    end if
    if m.ticket <> invalid then emitDiagnostic("rendered")
    ' Some Roku firmware/stream combinations update positionInfo.video before
    ' the Video node's position field. Publish on this observer as well so the
    ' watch-state tracker receives the rendered media clock.
    publishProgress()
    verifySeekResult()
end sub

sub onBufferDetails()
    if not m.mediaOpen then return
    info = m.decoder.bufferingStatus
    if type(info) = "roAssociativeArray"
        sample = {observedAtMs: m.monotonic.totalMilliseconds(), seekId: 0}
        if m.ticket <> invalid then sample.seekId = m.ticket.id
        for each field in ["percentage", "isUnderrun", "prebufferDone", "actualStart"]
            if info[field] <> invalid then sample[field] = info[field]
        end for
        m.lastBuffer = sample
        if m.hlsStartupIsolation and m.hlsPrebufferPending and info.prebufferDone = true
            m.hlsPrebufferPending = false
            m.decoder.visible = true
            m.decoder.control = "play"
            print "[RokuPlus hls-prebuffer] action=play prebufferDone=true"
            emitDiagnostic("hls_prebuffer_ready_play")
        end if
        if m.ticket <> invalid
            actualStart = plusClockValue(info.actualStart)
            if actualStart <> invalid
                m.ticket.actualStart = actualStart
                m.ticket.actualStartAt = sample.observedAtMs
            end if
        end if
    else
        ' Roku clears bufferingStatus when startup/rebuffering completes.
        ' Do not report the last percentage as if it were still current.
        m.lastBuffer = invalid
    end if
    emitDiagnostic("buffering_status")
end sub

' Roku exposes per-segment download results and startup timing on Video.
' Keep this event compact and never print segment URLs or query tokens.
sub onNativeStreamDetails()
    if not m.mediaOpen or m.closing then return
    emitDiagnostic("native_stream_details")
end sub

sub onNativeDecoderStats()
    if not m.mediaOpen or m.closing then return
    emitDiagnostic("decoder_stats")
end sub

sub onNativeAudioTrackDetails()
    if not m.mediaOpen or m.closing then return
    refreshAudioTracks()
    print "[RokuPlus audio] native_tracks_changed count="; m.audioTracks.count(); " selected="; m.decoder.currentAudioTrack
    emitDiagnostic("native_audio_tracks")
end sub

' Build a safe, user-facing list from the tracks reported by Roku. The Track
' value is kept unchanged because it is the identifier required by Video.audioTrack.
sub refreshAudioTracks()
    if m.decoder = invalid then return
    tracks = []
    if m.decoder.hasField("availableAudioTracks") then tracks = m.decoder.availableAudioTracks
    updated = []
    if type(tracks) = "roArray"
        for each track in tracks
            if type(track) = "roAssociativeArray"
                trackId = track["Track"]
                if GetInterface(trackId,"ifString") <> invalid and trackId <> ""
                    language = ""
                    name = ""
                    if GetInterface(track["Language"],"ifString") <> invalid then language = track["Language"]
                    if GetInterface(track["Name"],"ifString") <> invalid then name = track["Name"]
                    label = name
                    if label = "" then label = plusAudioLanguageName(language)
                    if label = "" then label = "Pista de audio"
                    if language <> "" and lcase(label) = lcase(language) then label = plusAudioLanguageName(language)
                    updated.push({id:trackId,label:label,language:language})
                end if
            end if
        end for
    end if
    m.audioTracks = updated
    print "[RokuPlus audio] refresh native="; tracks.count(); " selectable="; updated.count()
    if m.audioTracks.count() > 0
        selected = m.decoder.currentAudioTrack
        if GetInterface(selected,"ifString") = invalid or selected = "" then selected = m.decoder.audioTrack
        found = false
        for i = 0 to m.audioTracks.count()-1
            if m.audioTracks[i].id = selected
                m.audioTrackIndex = i
                found = true
                exit for
            end if
        end for
        if not found and m.audioTrackIndex >= m.audioTracks.count() then m.audioTrackIndex = 0
    else
        m.audioTrackIndex = 0
    end if
    if m.audioMenuOpen then drawAudioMenu()
end sub

function plusAudioLanguageName(code as string) as string
    value = lcase(code)
    if value = "spa" or value = "es" or left(value,3) = "es-" then return "Español"
    if value = "eng" or value = "en" or left(value,3) = "en-" then return "Inglés"
    if value = "fra" or value = "fre" or value = "fr" or left(value,3) = "fr-" then return "Francés"
    if value = "por" or value = "pt" or left(value,3) = "pt-" then return "Portugués"
    if value = "deu" or value = "ger" or value = "de" or left(value,3) = "de-" then return "Alemán"
    if value = "ita" or value = "it" or left(value,3) = "it-" then return "Italiano"
    if value = "jpn" or value = "ja" or left(value,3) = "ja-" then return "Japonés"
    if value = "kor" or value = "ko" or left(value,3) = "ko-" then return "Coreano"
    if value = "zho" or value = "chi" or value = "zh" or left(value,3) = "zh-" then return "Chino"
    if value = "rus" or value = "ru" or left(value,3) = "ru-" then return "Ruso"
    return code
end function

sub openAudioMenu()
    if m.displayMenuOpen then closeDisplayMenu()
    if m.playerOptionsMenuOpen then closePlayerOptionsMenu()
    if m.subtitleMenuOpen then closeSubtitleMenu()
    refreshAudioTracks()
    print "[RokuPlus audio] menu_open tracks="; m.audioTracks.count(); " state="; m.decoder.state
    m.audioMenuOpen = true
    m.audioMenuGroup.visible = true
    revealTransport()
    drawAudioMenu()
end sub

sub drawAudioMenu()
    if m.audioMenuItems = invalid then return
    output = "IDIOMA DE AUDIO" + chr(10) + chr(10)
    if m.audioTracks.count() = 0
        output += "Roku no ha informado pistas seleccionables para esta fuente." + chr(10) + chr(10) + "El audio disponible puede estar integrado en el video."
        output += chr(10) + chr(10) + "BACK Cerrar"
        m.audioMenuItems.text = output
        return
    end if
    for i = 0 to m.audioTracks.count()-1
        prefix = "   "
        if i = m.audioTrackIndex then prefix = "▶  "
        output += prefix + m.audioTracks[i].label
        if m.audioTracks[i].language <> "" then output += "  (" + m.audioTracks[i].language + ")"
        if i < m.audioTracks.count()-1 then output += chr(10)
    end for
    output += chr(10) + chr(10) + "▲ / ▼ Elegir     OK Confirmar     BACK Cerrar"
    m.audioMenuItems.text = output
end sub

sub closeAudioMenu()
    m.audioMenuOpen = false
    if m.audioMenuGroup <> invalid then m.audioMenuGroup.visible = false
end sub

sub moveAudioMenuSelection(direction as integer)
    count = m.audioTracks.count()
    if count = 0 then return
    m.audioTrackIndex = m.audioTrackIndex + direction
    if m.audioTrackIndex < 0 then m.audioTrackIndex = count - 1
    if m.audioTrackIndex >= count then m.audioTrackIndex = 0
    drawAudioMenu()
end sub

sub selectAudioTrack()
    if m.audioTrackIndex < 0 or m.audioTrackIndex >= m.audioTracks.count() then return
    chosen = m.audioTracks[m.audioTrackIndex]
    beforeTrack = m.decoder.currentAudioTrack
    print "[RokuPlus audio] select_request label="; chosen.label; " language="; chosen.language; " id="; chosen.id; " currentBefore="; beforeTrack
    m.decoder.audioTrack = chosen.id
    afterTrack = m.decoder.currentAudioTrack
    requestedTrack = m.decoder.audioTrack
    print "[RokuPlus audio] select_write requested="; requestedTrack; " currentImmediatelyAfter="; afterTrack
    closeAudioMenu()
    m.notice = "Cambio solicitado: " + chosen.label
    m.noticeUntil = m.monotonic.totalMilliseconds() + 4500
    revealTransport()
    drawTransport()
end sub

sub onNativeSubtitleTrackDetails()
    if not m.mediaOpen or m.closing then return
    refreshSubtitleTracks()
    emitDiagnostic("native_subtitle_tracks")
end sub

' Roku reports subtitle identifiers through TrackName. Keep the identifier
' unchanged; Video.subtitleTrack expects that exact value.
sub refreshSubtitleTracks()
    if m.decoder = invalid or not m.decoder.hasField("availableSubtitleTracks") then return
    tracks = m.decoder.availableSubtitleTracks
    updated = []
    if type(tracks) = "roArray"
        for each track in tracks
            if type(track) = "roAssociativeArray"
                trackId = track["TrackName"]
                if GetInterface(trackId,"ifString") = invalid or trackId = "" then trackId = track["Name"]
                if GetInterface(trackId,"ifString") = invalid or trackId = "" then trackId = track["Track"]
                if GetInterface(trackId,"ifString") <> invalid and trackId <> ""
                    language = ""
                    label = ""
                    if GetInterface(track["Language"],"ifString") <> invalid then language = track["Language"]
                    if GetInterface(track["Description"],"ifString") <> invalid then label = track["Description"]
                    if label = "" and GetInterface(track["Name"],"ifString") <> invalid then label = track["Name"]
                    if label = "" then label = plusAudioLanguageName(language)
                    if label = "" then label = "Subtítulos"
                    updated.push({id:trackId,label:label,language:language})
                end if
            end if
        end for
    end if
    m.subtitleTracks = updated
    selected = ""
    if m.decoder.hasField("currentSubtitleTrack") then selected = m.decoder.currentSubtitleTrack
    if (GetInterface(selected,"ifString") = invalid or selected = "") and m.decoder.hasField("subtitleTrack") then selected = m.decoder.subtitleTrack
    found = false
    for i = 0 to m.subtitleTracks.count()-1
        if m.subtitleTracks[i].id = selected
            m.subtitleTrackIndex = i + 4
            found = true
            exit for
        end if
    end for
    if not found
        if m.externalSubtitleCues.count() > 0
            m.subtitleTrackIndex = m.externalSubtitleSelectedIndex
        else
            m.subtitleTrackIndex = 0
        end if
    end if
    if m.subtitleMenuOpen then drawSubtitleMenu()
end sub

sub openSubtitleMenu()
    if m.displayMenuOpen then closeDisplayMenu()
    if m.playerOptionsMenuOpen then closePlayerOptionsMenu()
    refreshSubtitleTracks()
    if m.subtitleMenuGroup = invalid then return
    m.subtitleMenuOpen = true
    m.subtitleMenuGroup.visible = true
    if m.audioMenuOpen then closeAudioMenu()
    revealTransport()
    drawSubtitleMenu()
end sub

sub drawSubtitleMenu()
    if m.subtitleMenuItems = invalid then return
    output = "SUBTÍTULOS" + chr(10) + chr(10)
    prefix = "   "
    if m.subtitleTrackIndex = 0 then prefix = "▶  "
    output += prefix + "Desactivados"
    output += chr(10)
    prefix = "   "
    if m.subtitleTrackIndex = 1 then prefix = "▶  "
    keyStatus = "Sin configurar"
    if subtitleApiKeyLoad() <> "" then keyStatus = "Configurada"
    output += prefix + "Configurar API Key Subtitle Search Engine (" + keyStatus + ")"
    output += chr(10)
    prefix = "   "
    if m.subtitleTrackIndex = 2 then prefix = "▶  "
    subdlKeyStatus = "Sin configurar"
    if subdlApiKeyLoad() <> "" then subdlKeyStatus = "Configurada"
    output += prefix + "Configurar API Key SubDL (" + subdlKeyStatus + ")"
    output += chr(10)
    prefix = "   "
    if m.subtitleTrackIndex = 3 then prefix = "▶  "
    searchLabel = "Buscar subtítulos en línea (Español)"
    if m.subtitleOnlineBusy
        if m.subtitleOnlineOperation = "download" then searchLabel = "Descargando subtítulo..."
        if m.subtitleOnlineOperation = "search" then searchLabel = "Buscando en línea..."
    end if
    output += prefix + searchLabel
    for i = 0 to m.subtitleOnlineResults.count()-1
        output += chr(10)
        prefix = "   "
        if i + 4 = m.subtitleTrackIndex then prefix = "▶  "
        output += prefix + m.subtitleOnlineResults[i].label + "  (ES · en línea)"
    end for
    nativeOffset = 4 + m.subtitleOnlineResults.count()
    for i = 0 to m.subtitleTracks.count()-1
        output += chr(10)
        prefix = "   "
        if nativeOffset + i = m.subtitleTrackIndex then prefix = "▶  "
        output += prefix + m.subtitleTracks[i].label
        if m.subtitleTracks[i].language <> "" then output += "  (" + m.subtitleTracks[i].language + ")"
    end for
    output += chr(10) + chr(10) + "▲ / ▼ Elegir     OK Confirmar     BACK Cerrar"
    if m.subtitleTracks.count() = 0 and m.subtitleOnlineResults.count() = 0 then output += chr(10) + "También puedes buscar subtítulos en línea."
    m.subtitleMenuItems.text = output
end sub

sub closeSubtitleMenu()
    if m.subtitleSearchTask <> invalid then cancelSubtitleSearchTask()
    m.subtitleOnlineBusy = false
    m.subtitleOnlineOperation = ""
    m.subtitleMenuOpen = false
    if m.subtitleMenuGroup <> invalid then m.subtitleMenuGroup.visible = false
end sub

sub moveSubtitleMenuSelection(direction as integer)
    count = 4 + m.subtitleOnlineResults.count() + m.subtitleTracks.count()
    m.subtitleTrackIndex = m.subtitleTrackIndex + direction
    if m.subtitleTrackIndex < 0 then m.subtitleTrackIndex = count - 1
    if m.subtitleTrackIndex >= count then m.subtitleTrackIndex = 0
    drawSubtitleMenu()
end sub

sub selectSubtitleTrack()
    if m.subtitleOnlineBusy then return
    if m.subtitleTrackIndex = 0
        if m.decoder.hasField("subtitleTrack") then m.decoder.subtitleTrack = ""
        if m.decoder.hasField("globalCaptionMode") then m.decoder.globalCaptionMode = "Off"
        m.externalSubtitleCues = []
        m.externalSubtitleIndex = 0
        m.externalSubtitleLastPosition = -1
        m.externalSubtitleSelectedIndex = 0
        if m.externalSubtitleGroup <> invalid then m.externalSubtitleGroup.visible = false
        closeSubtitleMenu()
        m.notice = "Subtítulos desactivados."
        print "[RokuPlus subtitles] selected=off"
    else if m.subtitleTrackIndex = 1
        openSubtitleApiKeyDialog()
        return
    else if m.subtitleTrackIndex = 2
        openSubDlApiKeyDialog()
        return
    else if m.subtitleTrackIndex = 3
        m.subtitleOnlineBusy = true
        m.subtitleOnlineOperation = "search"
        drawSubtitleMenu()
        startSubtitleSearchTask("search","")
        return
    else if m.subtitleTrackIndex < 4 + m.subtitleOnlineResults.count()
        onlineIndex = m.subtitleTrackIndex - 4
        if onlineIndex < 0 or onlineIndex >= m.subtitleOnlineResults.count() then return
        m.subtitleOnlinePendingLabel = m.subtitleOnlineResults[onlineIndex].label
        m.subtitleOnlineBusy = true
        m.subtitleOnlineOperation = "download"
        drawSubtitleMenu()
        startSubtitleSearchTask("download",m.subtitleOnlineResults[onlineIndex].id)
        return
    else
        nativeIndex = m.subtitleTrackIndex - 4 - m.subtitleOnlineResults.count()
        if nativeIndex < 0 or nativeIndex >= m.subtitleTracks.count() then return
        chosen = m.subtitleTracks[nativeIndex]
        if not m.decoder.hasField("subtitleTrack")
            m.notice = "Este Roku no permite seleccionar subtítulos en esta reproducción."
        else
            m.decoder.subtitleTrack = chosen.id
            if m.decoder.hasField("globalCaptionMode") then m.decoder.globalCaptionMode = "On"
            m.externalSubtitleCues = []
            m.externalSubtitleIndex = 0
            m.externalSubtitleLastPosition = -1
            m.externalSubtitleSelectedIndex = 0
            if m.externalSubtitleGroup <> invalid then m.externalSubtitleGroup.visible = false
            m.notice = "Subtítulos: " + chosen.label
            print "[RokuPlus subtitles] selected="; chosen.label; " language="; chosen.language
        end if
        closeSubtitleMenu()
    end if
    m.noticeUntil = m.monotonic.totalMilliseconds() + 4500
    revealTransport()
    drawTransport()
end sub

sub openPlayerOptionsMenu()
    if m.playerOptionsMenuGroup = invalid or m.playerOptionsMenuItems = invalid then return
    if m.audioMenuOpen then closeAudioMenu()
    if m.subtitleMenuOpen then closeSubtitleMenu()
    if m.displayMenuOpen then closeDisplayMenu()
    m.playerOptionsMenuOpen = true
    m.playerOptionsMenuIndex = 0
    m.playerOptionsMenuGroup.visible = true
    revealTransport()
    drawPlayerOptionsMenu()
end sub

sub drawPlayerOptionsMenu()
    if m.playerOptionsMenuItems = invalid then return
    output = "CONTROLES DEL REPRODUCTOR" + chr(10) + chr(10)
    for i = 0 to m.playerOptionsLabels.count()-1
        prefix = "   "
        if i = m.playerOptionsMenuIndex then prefix = "▶  "
        output += prefix + m.playerOptionsLabels[i]
        if i < m.playerOptionsLabels.count()-1 then output += chr(10)
    end for
    output += chr(10) + chr(10) + "▲ / ▼ Mover     OK Seleccionar     BACK Cerrar"
    m.playerOptionsMenuItems.text = output
end sub

sub closePlayerOptionsMenu()
    m.playerOptionsMenuOpen = false
    if m.playerOptionsMenuGroup <> invalid then m.playerOptionsMenuGroup.visible = false
end sub

sub movePlayerOptionsMenuSelection(direction as integer)
    m.playerOptionsMenuIndex += direction
    if m.playerOptionsMenuIndex < 0 then m.playerOptionsMenuIndex = m.playerOptionsLabels.count()-1
    if m.playerOptionsMenuIndex >= m.playerOptionsLabels.count() then m.playerOptionsMenuIndex = 0
    drawPlayerOptionsMenu()
end sub

sub selectPlayerOptionsMenu()
    selected = m.playerOptionsMenuIndex
    if selected = 0
        closePlayerOptionsMenu()
        openDisplayMenu()
    else if selected = 1
        closePlayerOptionsMenu()
        openSubtitleMenu()
    else if selected = 2
        closePlayerOptionsMenu()
        openAudioMenu()
    else if selected = 3
        shiftTen(true)
        drawPlayerOptionsMenu()
    else if selected = 4
        shiftTen(false)
        drawPlayerOptionsMenu()
    else if selected = 5
        togglePause()
        drawPlayerOptionsMenu()
    end if
end sub

sub openDisplayMenu()
    if m.displayMenuGroup = invalid or m.displayMenuItems = invalid then return
    if m.playerOptionsMenuOpen then closePlayerOptionsMenu()
    if m.audioMenuOpen then closeAudioMenu()
    if m.subtitleMenuOpen then closeSubtitleMenu()
    m.displayMenuOpen = true
    m.displayMenuIndex = m.zoomIndex
    m.displayMenuGroup.visible = true
    revealTransport()
    drawDisplayMenu()
end sub

sub drawDisplayMenu()
    if m.displayMenuItems = invalid then return
    output = "IMAGEN Y ZOOM" + chr(10) + chr(10)
    for i = 0 to m.zoomLabels.count()-1
        prefix = "   "
        if i = m.displayMenuIndex then prefix = "▶  "
        output += prefix + m.zoomLabels[i]
        if i < m.zoomLabels.count()-1 then output += chr(10)
    end for
    showSkip = false
    if not m.live and m.current <> invalid and m.current.doesExist("introStart") and m.current.doesExist("introEnd")
        introStart = plusClockValue(m.current.introStart)
        introEnd = plusClockValue(m.current.introEnd)
        currentAt = playerPosition()
        if introStart <> invalid and introEnd <> invalid and currentAt <> invalid
            showSkip = introEnd > introStart and currentAt >= introStart and currentAt < introEnd
        end if
    end if
    if showSkip
        output += chr(10) + "   Saltar introducción"
    end if
    output += chr(10) + chr(10) + "▲ / ▼ Elegir     OK Aplicar     BACK Cerrar"
    m.displayMenuItems.text = output
end sub

sub closeDisplayMenu()
    m.displayMenuOpen = false
    if m.displayMenuGroup <> invalid then m.displayMenuGroup.visible = false
end sub

sub moveDisplayMenuSelection(direction as integer)
    count = m.zoomLabels.count()
    if not m.live and m.current <> invalid and m.current.doesExist("introStart") and m.current.doesExist("introEnd")
        introStart = plusClockValue(m.current.introStart)
        introEnd = plusClockValue(m.current.introEnd)
        currentAt = playerPosition()
        if introStart <> invalid and introEnd <> invalid and currentAt <> invalid
            if introEnd > introStart and currentAt >= introStart and currentAt < introEnd then count++
        end if
    end if
    m.displayMenuIndex += direction
    if m.displayMenuIndex < 0 then m.displayMenuIndex = count - 1
    if m.displayMenuIndex >= count then m.displayMenuIndex = 0
    drawDisplayMenu()
end sub

sub selectDisplayMenu()
    if m.displayMenuIndex < m.zoomLevels.count()
        m.zoomIndex = m.displayMenuIndex
        applyVideoZoom()
        selectedLabel = m.zoomLabels[m.zoomIndex]
        closeDisplayMenu()
        m.notice = "Pantalla: " + selectedLabel
        m.noticeUntil = m.monotonic.totalMilliseconds() + 4500
        revealTransport()
        drawTransport()
    else
        closeDisplayMenu()
        skipIntro()
    end if
end sub

sub openSubtitleApiKeyDialog()
    scene = m.top.getScene()
    if scene = invalid then
        m.notice = "No se pudo abrir la configuración de la API Key."
        m.noticeUntil = m.monotonic.totalMilliseconds() + 4500
        return
    end if
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    if dialog = invalid then return
    dialog.title = "API Key · Subtitle Search Engine"
    dialog.message = ["Pega tu API Key. Se guarda únicamente en este Roku."]
    dialog.buttons = ["Guardar","Borrar","Cancelar"]
    dialog.keyboardDomain = "password"
    dialog.text = ""
    if dialog.textEditBox <> invalid
        dialog.textEditBox.secureMode = true
        dialog.textEditBox.secureLastCharacter = true
    end if
    dialog.observeField("buttonSelected","onSubtitleApiKeyDialogButton")
    m.subtitleApiKeyDialog = dialog
    scene.dialog = dialog
end sub

sub onSubtitleApiKeyDialogButton()
    dialog = m.subtitleApiKeyDialog
    if dialog = invalid then return
    selected = dialog.buttonSelected
    scene = m.top.getScene()
    if selected = 0
        value = dialog.text
        if GetInterface(value,"ifString") = invalid then value = ""
        value = value.trim()
        if value <> "" and len(value) <= 512 and instr(1,value,chr(10)) = 0 and instr(1,value,chr(13)) = 0
            if subtitleApiKeySave(value)
                m.notice = "API Key guardada en este Roku."
            else
                m.notice = "No se pudo guardar la API Key."
            end if
        else
            m.notice = "La API Key está vacía o no es válida."
        end if
    else if selected = 1
        if subtitleApiKeyClear()
            m.notice = "API Key borrada de este Roku."
        else
            m.notice = "No se pudo borrar la API Key."
        end if
    end if
    m.subtitleApiKeyDialog = invalid
    if scene <> invalid then scene.dialog = invalid
    m.noticeUntil = m.monotonic.totalMilliseconds() + 5000
    drawSubtitleMenu()
    revealTransport()
    drawTransport()
end sub

function subtitleApiKeyLoad() as string
    section = CreateObject("roRegistrySection","RokuPlusSubtitleSecrets")
    if GetInterface(section,"ifRegistrySection") = invalid then return ""
    value = section.read("subtitleSearchEngineApiKey")
    if GetInterface(value,"ifString") = invalid then return ""
    return value
end function

function subtitleApiKeySave(value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    candidate = value.trim()
    if candidate = "" or len(candidate) > 512 then return false
    if instr(1,candidate,chr(10)) > 0 or instr(1,candidate,chr(13)) > 0 then return false
    section = CreateObject("roRegistrySection","RokuPlusSubtitleSecrets")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    previous = section.read("subtitleSearchEngineApiKey")
    if section.write("subtitleSearchEngineApiKey",candidate) <> true then return false
    if section.flush() = true then return true
    if previous = "" then section.delete("subtitleSearchEngineApiKey") else section.write("subtitleSearchEngineApiKey",previous)
    section.flush()
    return false
end function

function subtitleApiKeyClear() as boolean
    section = CreateObject("roRegistrySection","RokuPlusSubtitleSecrets")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    previous = section.read("subtitleSearchEngineApiKey")
    if previous = "" then return true
    section.delete("subtitleSearchEngineApiKey")
    if section.flush() = true then return true
    section.write("subtitleSearchEngineApiKey",previous)
    section.flush()
    return false
end function

sub openSubDlApiKeyDialog()
    scene = m.top.getScene()
    if scene = invalid then
        m.notice = "No se pudo abrir la configuración de SubDL."
        m.noticeUntil = m.monotonic.totalMilliseconds() + 4500
        return
    end if
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    if dialog = invalid then return
    dialog.title = "API Key · SubDL"
    dialog.message = ["Pega tu API Key de SubDL. Se guarda únicamente en este Roku."]
    dialog.buttons = ["Guardar","Borrar","Cancelar"]
    dialog.keyboardDomain = "password"
    dialog.text = ""
    if dialog.textEditBox <> invalid
        dialog.textEditBox.secureMode = true
        dialog.textEditBox.secureLastCharacter = true
    end if
    dialog.observeField("buttonSelected","onSubDlApiKeyDialogButton")
    m.subtitleApiKeyDialog = dialog
    scene.dialog = dialog
end sub

sub onSubDlApiKeyDialogButton()
    dialog = m.subtitleApiKeyDialog
    if dialog = invalid then return
    selected = dialog.buttonSelected
    scene = m.top.getScene()
    if selected = 0
        value = dialog.text
        if GetInterface(value,"ifString") <> invalid then value = value.trim() else value = ""
        if value <> "" and len(value) <= 512 and instr(1,value,chr(10)) = 0 and instr(1,value,chr(13)) = 0
            if subdlApiKeySave(value) then m.notice = "API Key de SubDL guardada en este Roku." else m.notice = "No se pudo guardar la API Key de SubDL."
        else
            m.notice = "La API Key está vacía o no es válida."
        end if
    else if selected = 1
        if subdlApiKeyClear() then m.notice = "API Key de SubDL borrada de este Roku." else m.notice = "No se pudo borrar la API Key de SubDL."
    end if
    m.subtitleApiKeyDialog = invalid
    if scene <> invalid then scene.dialog = invalid
    m.noticeUntil = m.monotonic.totalMilliseconds() + 5000
    drawSubtitleMenu()
    revealTransport()
    drawTransport()
end sub

function subdlApiKeyLoad() as string
    section = CreateObject("roRegistrySection","RokuPlusSubtitleSecrets")
    if GetInterface(section,"ifRegistrySection") = invalid then return ""
    value = section.read("subdlApiKey")
    if GetInterface(value,"ifString") = invalid then return ""
    return value
end function

function subdlApiKeySave(value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    candidate = value.trim()
    if candidate = "" or len(candidate) > 512 or instr(1,candidate,chr(10)) > 0 or instr(1,candidate,chr(13)) > 0 then return false
    section = CreateObject("roRegistrySection","RokuPlusSubtitleSecrets")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    previous = section.read("subdlApiKey")
    if section.write("subdlApiKey",candidate) <> true then return false
    if section.flush() = true then return true
    if previous = "" then section.delete("subdlApiKey") else section.write("subdlApiKey",previous)
    section.flush()
    return false
end function

function subdlApiKeyClear() as boolean
    section = CreateObject("roRegistrySection","RokuPlusSubtitleSecrets")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    previous = section.read("subdlApiKey")
    if previous = "" then return true
    section.delete("subdlApiKey")
    if section.flush() = true then return true
    section.write("subdlApiKey",previous)
    section.flush()
    return false
end function

sub startSubtitleSearchTask(operation as string, subtitleId as string)
    cancelSubtitleSearchTask()
    task = CreateObject("roSGNode","SubtitleSearchTask")
    task.operation = operation
    task.title = m.titleText.text
    if type(m.current) = "roAssociativeArray"
        if m.current.doesExist("title")
            if GetInterface(m.current.title,"ifString") <> invalid and m.current.title <> "" then task.title = m.current.title
        end if
        if m.current.doesExist("kind") and m.current.kind = "episode" and m.current.doesExist("seriesTitle")
            if GetInterface(m.current.seriesTitle,"ifString") <> invalid and m.current.seriesTitle <> "" then task.title = m.current.seriesTitle
        end if
        if m.current.doesExist("imdbId")
            if GetInterface(m.current.imdbId,"ifString") <> invalid then task.imdbId = m.current.imdbId
        end if
    end if
    task.subtitleId = subtitleId
    task.apiKey = subtitleApiKeyLoad()
    task.subdlApiKey = subdlApiKeyLoad()
    if type(m.current) = "roAssociativeArray"
        if m.current.doesExist("kind") then task.kind = m.current.kind
        if m.current.doesExist("season")
            if GetInterface(m.current.season,"ifString") <> invalid then task.seasonNumber = m.current.season
            if GetInterface(m.current.season,"ifInt") <> invalid then task.seasonNumber = m.current.season.toStr()
        end if
        if m.current.doesExist("episodeNumber")
            if GetInterface(m.current.episodeNumber,"ifString") <> invalid then task.episodeNumber = m.current.episodeNumber
            if GetInterface(m.current.episodeNumber,"ifInt") <> invalid then task.episodeNumber = m.current.episodeNumber.toStr()
        else if m.current.doesExist("episode")
            if GetInterface(m.current.episode,"ifString") <> invalid then task.episodeNumber = m.current.episode
            if GetInterface(m.current.episode,"ifInt") <> invalid then task.episodeNumber = m.current.episode.toStr()
        end if
    end if
    task.language = "es"
    task.observeField("result","onSubtitleSearchTaskResult")
    m.subtitleSearchTask = task
    m.top.appendChild(task)
    task.control = "RUN"
    print "[RokuPlus subtitles-online] operation="; operation
end sub

sub cancelSubtitleSearchTask()
    if m.subtitleSearchTask <> invalid
        m.subtitleSearchTask.unobserveField("result")
        m.subtitleSearchTask.control = "STOP"
        m.top.removeChild(m.subtitleSearchTask)
        m.subtitleSearchTask = invalid
    end if
end sub

sub onSubtitleSearchTaskResult()
    if m.subtitleSearchTask = invalid then return
    task = m.subtitleSearchTask
    result = task.result
    cancelSubtitleSearchTask()
    m.subtitleOnlineBusy = false
    m.subtitleOnlineOperation = ""
    if type(result) <> "roAssociativeArray"
        m.notice = "La búsqueda de subtítulos devolvió una respuesta inválida."
        m.noticeUntil = m.monotonic.totalMilliseconds() + 5500
        drawSubtitleMenu()
        revealTransport()
        drawTransport()
        return
    end if
    if result.ok <> true
        message = "No se pudo obtener subtítulos en línea."
        if GetInterface(result.message,"ifString") <> invalid and result.message <> "" then message = result.message
        m.notice = message
        m.noticeUntil = m.monotonic.totalMilliseconds() + 5500
        drawSubtitleMenu()
        revealTransport()
        drawTransport()
        return
    end if
    if result.operation = "search"
        m.subtitleOnlineResults = result.items
        if m.subtitleOnlineResults.count() > 0
            m.subtitleTrackIndex = 3
            m.notice = "Subtítulos encontrados: " + m.subtitleOnlineResults.count().toStr()
        else
            m.subtitleTrackIndex = 3
            m.notice = result.message
        end if
        m.noticeUntil = m.monotonic.totalMilliseconds() + 5000
        drawSubtitleMenu()
        revealTransport()
        drawTransport()
        return
    end if
    if result.operation = "download"
        cues = plusParseSrt(result.subtitleText)
        if cues.count() = 0
            m.notice = "El archivo no contiene subtítulos SRT válidos."
        else
            m.externalSubtitleCues = cues
            m.externalSubtitleIndex = 0
            m.externalSubtitleLastPosition = -1
            m.externalSubtitleSelectedIndex = m.subtitleTrackIndex
            if m.decoder.hasField("subtitleTrack") then m.decoder.subtitleTrack = ""
            if m.decoder.hasField("globalCaptionMode") then m.decoder.globalCaptionMode = "Off"
            m.notice = "Subtítulos en español activados: " + m.subtitleOnlinePendingLabel
            print "[RokuPlus subtitles-online] active cues="; cues.count()
            closeSubtitleMenu()
            updateExternalSubtitle()
        end if
        m.noticeUntil = m.monotonic.totalMilliseconds() + 5500
        revealTransport()
        drawTransport()
    end if
end sub

function plusParseSrt(body as dynamic) as object
    cues = []
    if GetInterface(body,"ifString") = invalid then return cues
    if len(body) = 0 or len(body) > 2097152 then return cues
    normalized = body.replace(chr(13),"")
    lines = normalized.split(chr(10))
    timingRegex = CreateObject("roRegex","^([0-9]{2}:[0-9]{2}:[0-9]{2}[,.][0-9]{3})[ ]+-->[ ]+([0-9]{2}:[0-9]{2}:[0-9]{2}[,.][0-9]{3})","")
    i = 0
    while i < lines.count() and cues.count() < 5000
        match = timingRegex.match(lines[i].trim())
        if match.count() >= 3
            startAt = plusSrtTime(match[1])
            endAt = plusSrtTime(match[2])
            i++
            textLines = []
            while i < lines.count() and lines[i].trim() <> ""
                if textLines.count() < 8 then textLines.push(left(lines[i].trim(),240))
                i++
            end while
            caption = ""
            for each line in textLines
                if caption <> "" then caption += chr(10)
                caption += line
            end for
            if startAt >= 0 and endAt > startAt and caption <> ""
                cues.push({start:startAt,finish:endAt,text:caption})
            end if
        else
            i++
        end if
    end while
    return cues
end function

function plusSrtTime(value as string) as float
    normalized = value.replace(".",",")
    parts = normalized.split(":")
    if parts.count() <> 3 then return -1
    seconds = parts[2].split(",")
    if seconds.count() <> 2 then return -1
    hours = val(parts[0])
    minutes = val(parts[1])
    whole = val(seconds[0])
    millis = val(seconds[1])
    if hours < 0 or hours > 99 or minutes < 0 or minutes > 59 or whole < 0 or whole > 59 or millis < 0 or millis > 999 then return -1
    return hours * 3600 + minutes * 60 + whole + millis / 1000.0
end function

sub updateExternalSubtitle()
    if m.externalSubtitleGroup = invalid or m.externalSubtitleLabel = invalid then return
    if m.externalSubtitleCues.count() = 0
        m.externalSubtitleGroup.visible = false
        return
    end if
    position = playerPosition()
    if position = invalid
        m.externalSubtitleGroup.visible = false
        return
    end if
    if position < m.externalSubtitleLastPosition then m.externalSubtitleIndex = 0
    m.externalSubtitleLastPosition = position
    while m.externalSubtitleIndex < m.externalSubtitleCues.count()
        if m.externalSubtitleCues[m.externalSubtitleIndex].finish < position
            m.externalSubtitleIndex++
        else
            exit while
        end if
    end while
    if m.externalSubtitleIndex < m.externalSubtitleCues.count()
        cue = m.externalSubtitleCues[m.externalSubtitleIndex]
        if position >= cue.start and position <= cue.finish
            m.externalSubtitleLabel.text = cue.text
            m.externalSubtitleGroup.visible = true
            return
        end if
    end if
    m.externalSubtitleGroup.visible = false
end sub

function nativeStreamSnapshot() as object
    snapshot = {}
    if m.decoder = invalid then return snapshot
    ' Report field support separately from populated values.
    snapshot.errorCodeSupported = m.decoder.hasField("errorCode")
    snapshot.errorInfoSupported = m.decoder.hasField("errorInfo")
    snapshot.errorMsgSupported = m.decoder.hasField("errorMsg")
    snapshot.errorStrSupported = m.decoder.hasField("errorStr")
    snapshot.completedStreamInfoSupported = m.decoder.hasField("completedStreamInfo")
    snapshot.decoderStatsSupported = m.decoder.hasField("decoderStats")
    snapshot.decoderStatsEnabledSupported = m.decoder.hasField("enableDecoderStats")
    if m.decoder.hasField("enableDecoderStats") then snapshot.decoderStatsEnabled = m.decoder.enableDecoderStats
    snapshot.audioFormatSupported = m.decoder.hasField("audioFormat")
    snapshot.audioSelectionPreferencesSupported = m.decoder.hasField("audioSelectionPreferences")
    snapshot.audioSelectionPreferencesSet = m.audioSelectionPreferenceSet
    snapshot.seamlessAudioTrackSelectionSupported = m.decoder.hasField("seamlessAudioTrackSelection")
    if m.decoder.hasField("seamlessAudioTrackSelection") then snapshot.seamlessAudioTrackSelection = m.decoder.seamlessAudioTrackSelection
    snapshot.availableAudioTracksSupported = m.decoder.hasField("availableAudioTracks")
    snapshot.availableAudioTrackCount = -1
    snapshot.currentAudioTrackPresent = false
    snapshot.currentAudioTrackSupported = m.decoder.hasField("currentAudioTrack")
    snapshot.playStartInfoSupported = m.decoder.hasField("playStartInfo")
    snapshot.streamingSegmentSupported = m.decoder.hasField("streamingSegment")
    snapshot.streamingSegmentPresent = false
    snapshot.downloadedSegmentSupported = m.decoder.hasField("downloadedSegment")
    snapshot.downloadedSegmentPresent = false
    snapshot.streamInfoSupported = m.decoder.hasField("streamInfo")
    snapshot.videoFormatSupported = m.decoder.hasField("videoFormat")
    snapshot.timeToStartStreamingSupported = m.decoder.hasField("timeToStartStreaming")
    snapshot.maxVideoDecodeResolutionSupported = m.decoder.hasField("maxVideoDecodeResolution")
    snapshot.enableUiSupported = m.decoder.hasField("enableUI")
    snapshot.enableTrickPlaySupported = m.decoder.hasField("enableTrickPlay")
    snapshot.seekModeSupported = m.decoder.hasField("seekMode")
    snapshot.notificationIntervalSupported = m.decoder.hasField("notificationInterval")
    snapshot.autoplayAfterSeekSupported = m.decoder.hasField("autoplayAfterSeek")
    if m.decoder.hasField("maxVideoDecodeResolution")
        resolution = m.decoder.maxVideoDecodeResolution
        if type(resolution) = "roArray" and resolution.count() >= 2
            snapshot.maxVideoDecodeResolution = [resolution[0],resolution[1]]
        end if
    end if
    if m.decoder.hasField("enableUI") then snapshot.enableUI = m.decoder.enableUI
    if m.decoder.hasField("enableTrickPlay") then snapshot.enableTrickPlay = m.decoder.enableTrickPlay
    if m.decoder.hasField("seekMode") then snapshot.seekMode = m.decoder.seekMode
    if m.decoder.hasField("notificationInterval") then snapshot.notificationInterval = m.decoder.notificationInterval
    if m.decoder.hasField("autoplayAfterSeek") then snapshot.autoplayAfterSeek = m.decoder.autoplayAfterSeek

    if m.decoder.hasField("errorCode")
        value = m.decoder.errorCode
        if value <> invalid then snapshot.errorCode = value
    end if
    if m.decoder.hasField("errorMsg")
        value = plusSafeNativeText(m.decoder.errorMsg)
        if value <> "" then snapshot.errorMsg = value
    end if
    if m.decoder.hasField("errorStr")
        value = plusSafeNativeText(m.decoder.errorStr)
        if value <> "" then snapshot.errorStr = value
    end if
    if m.decoder.hasField("errorInfo")
        info = m.decoder.errorInfo
        if type(info) = "roAssociativeArray"
            error = {}
            for each field in ["category","clipId","ignored","source","errcode","drmerrcode"]
                if info[field] <> invalid then error[field] = info[field]
            end for
            if GetInterface(info.dbgmsg,"ifString") <> invalid
                ' Do not expose a URL or token if Roku includes one in debug text.
                if instr(1,lcase(info.dbgmsg),"http") = 0 then error.dbgmsg = left(info.dbgmsg,240)
            end if
            if error.count() > 0 then snapshot.errorInfo = error
        end if
    end if
    if m.decoder.hasField("playStartInfo")
        info = m.decoder.playStartInfo
        snapshot.playStartInfoPresent = type(info) = "roAssociativeArray" and info.count() > 0
        if type(info) = "roAssociativeArray"
            startup = {}
            for each field in ["total_dur","manifest_dur","drm_load_dur","drm_lic_acq_dur","prebuf_dur","manifest_start","drm_load_start","drm_lic_acq_start","prebuf_start"]
                if info[field] <> invalid then startup[field] = info[field]
            end for
            if startup.count() > 0 then snapshot.playStartInfo = startup
        end if
    end if
    if m.decoder.hasField("streamingSegment")
        segment = m.decoder.streamingSegment
        snapshot.streamingSegmentPresent = type(segment) = "roAssociativeArray" and segment.count() > 0
        if type(segment) = "roAssociativeArray"
            sample = {}
            for each field in ["hdrModeStr","segBitrateBps","segSequence","segStart","segType","segTypeStr","latency","width","height"]
                if segment[field] <> invalid then sample[field] = segment[field]
            end for
            if sample.count() > 0 then snapshot.streamingSegment = sample
        end if
    end if
    if m.decoder.hasField("downloadedSegment")
        segment = m.decoder.downloadedSegment
        snapshot.downloadedSegmentPresent = type(segment) = "roAssociativeArray" and segment.count() > 0
        if type(segment) = "roAssociativeArray"
            sample = {}
            for each field in ["Status","SegSequence","DownloadDuration","SegSize","SegType","BitrateBPS","SegStart","SegDuration","Width","Height"]
                if segment[field] <> invalid then sample[field] = segment[field]
            end for
            if sample.count() > 0 then snapshot.downloadedSegment = sample
        end if
    end if
    if m.decoder.hasField("streamInfo")
        info = m.decoder.streamInfo
        if type(info) = "roAssociativeArray"
            stream = {}
            for each field in ["isUnderrun","isResume","measuredBItrate","streamBitrate"]
                if info[field] <> invalid then stream[field] = info[field]
            end for
            if stream.count() > 0 then snapshot.streamInfo = stream
        end if
    end if
    if m.decoder.hasField("videoFormat")
        value = m.decoder.videoFormat
        if GetInterface(value,"ifString") <> invalid and value <> "" then snapshot.videoFormat = value
    end if
    if m.decoder.hasField("audioFormat")
        value = m.decoder.audioFormat
        if GetInterface(value,"ifString") <> invalid and value <> "" then snapshot.audioFormat = value
    end if
    if m.decoder.hasField("currentAudioTrack")
        value = m.decoder.currentAudioTrack
        if GetInterface(value,"ifString") <> invalid and value <> ""
            snapshot.currentAudioTrack = left(value,120)
            snapshot.currentAudioTrackPresent = true
        end if
    end if
    if m.decoder.hasField("availableAudioTracks")
        tracks = m.decoder.availableAudioTracks
        if type(tracks) = "roArray"
            snapshot.availableAudioTrackCount = tracks.count()
            audioTracks = []
            for each track in tracks
                if type(track) = "roAssociativeArray"
                    audioTrack = {}
                    for each field in ["Language","Name","Track"]
                        value = track[field]
                        if GetInterface(value,"ifString") <> invalid and value <> "" then audioTrack[field] = left(value,120)
                    end for
                    if audioTrack.count() > 0 then audioTracks.push(audioTrack)
                end if
            end for
            if audioTracks.count() > 0 then snapshot.availableAudioTracks = audioTracks
        end if
    end if
    if m.decoder.hasField("decoderStats")
        stats = m.decoder.decoderStats
        snapshot.decoderStatsType = type(stats)
        if type(stats) = "roAssociativeArray"
            sample = {}
            for each field in ["frameDropCount","renderCount","repeatCount","streamErrorCount"]
                if stats[field] <> invalid then sample[field] = stats[field]
            end for
            if sample.count() > 0 then snapshot.decoderStats = sample
        end if
    end if
    if m.decoder.hasField("completedStreamInfo")
        info = m.decoder.completedStreamInfo
        if type(info) = "roAssociativeArray"
            completed = {}
            for each field in ["isFullResult","isUnderrun","isResume","measuredBItrate","streamBitrate"]
                if info[field] <> invalid then completed[field] = info[field]
            end for
            if completed.count() > 0 then snapshot.completedStreamInfo = completed
        end if
    end if
    if m.decoder.hasField("timeToStartStreaming")
        value = m.decoder.timeToStartStreaming
        if value <> invalid and value > 0 then snapshot.timeToStartStreaming = value
    end if
    return snapshot
end function

sub publishProgress(force = false as boolean)
    if m.segmentMode and m.segmentIndex < m.segmentUrls.count()-1 then return
    now = m.monotonic.totalMilliseconds()
    if not force and now - m.lastProgressAt < 500 then return
    m.lastProgressAt = now
    state = m.decoder.state
    if m.phase = "opening" then state = "opening"
    presentation = "fullscreen"
    if isPreviewPresentation() then presentation = "preview"
    nativePosition = playerPosition()
    nativeDuration = playerDuration()
    resumeInFlight = m.resumePending <> invalid
    if m.pendingSeek <> invalid
        if m.pendingSeek.doesExist("isResume") and m.pendingSeek.isResume = true then resumeInFlight = true
    end if
    if m.ticket <> invalid
        if m.ticket.doesExist("isResume") and m.ticket.isResume = true then resumeInFlight = true
    end if
    ' Do not let startup zeroes or stale positionInfo overwrite the saved bookmark.
    if resumeInFlight then return
    if m.tsRelayMode and (m.ticket <> invalid or m.pendingSeek <> invalid or m.tsRelayRestartStage > 0) then return
    if m.resumeFailed
        if nativePosition = invalid or nativePosition <= 15 then return
        if m.resumeFailedPosition <> invalid
            if nativePosition <= m.resumeFailedPosition + 1 then return
        end if
        if now - m.resumeFailedAt < 1000 then return
        m.resumeFailed = false
        m.resumeFailedPosition = invalid
        m.resumeFailedAt = 0
    end if
    rendered = renderedFields()
    renderedPosition = invalid
    if rendered.doesExist("video") then renderedPosition = plusClockValue(rendered.video)
    ' Prefer the native clock; use the rendered video timestamp only when the
    ' native clock is absent or stuck at zero while rendered playback advances.
    position = nativePosition
    if renderedPosition <> invalid
        if position = invalid or (position <= 0 and renderedPosition > 0) then position = renderedPosition
    end if
    duration = nativeDuration
    progress = {generation: m.generation, state: state, position: 0, duration: 0, nativePosition: 0, renderedPosition: 0, live: m.live, presentation: presentation, failed: m.failed, notice: m.notice}
    if nativePosition <> invalid then progress.nativePosition = nativePosition
    if renderedPosition <> invalid then progress.renderedPosition = renderedPosition
    if position <> invalid then progress.position = position
    if duration <> invalid then progress.duration = duration
    if type(m.current) = "roAssociativeArray"
        if GetInterface(m.current.itemId,"ifString") <> invalid then progress.itemId = m.current.itemId
        if GetInterface(m.current.provider,"ifString") <> invalid then progress.provider = m.current.provider
        if GetInterface(m.current.requestId,"ifString") <> invalid then progress.requestId = m.current.requestId
    end if
    m.top.progress = progress
end sub

sub revealTransport()
    if isPreviewPresentation()
        m.panel.visible = false
        return
    end if
    m.panel.visible = true
    m.panelUntil = m.monotonic.totalMilliseconds() + 6000
end sub

sub drawTransport()
    if not m.mediaOpen then return
    m.lastTransportDrawAt = m.monotonic.totalMilliseconds()
    state = m.decoder.state
    mode = "Reproduciendo"
    if state = "paused" then mode = "En pausa"
    if state = "buffering" or state = "none" or state = "stopped" then mode = "Preparando"
    if m.ticket <> invalid or m.pendingSeek <> invalid then mode = "Buscando posición"
    if m.failed then mode = "No se pudo reproducir"
    clock = plusClockText(playerPosition())
    d = playerDuration()
    p = playerPosition()
    ' Show the last requested destination while a command is queued; this is
    ' a preview only and is never substituted for the decoder's media clock.
    if m.pendingSeek <> invalid
        clock = plusClockText(m.pendingSeek.target)
    else if m.ticket <> invalid
        clock = plusClockText(m.ticket.target)
    end if
    showBar = false
    if d <> invalid and p <> invalid then showBar = d > 0
    m.track.visible = showBar and not m.live
    m.fill.visible = showBar and not m.live
    m.thumb.visible = showBar and not m.live
    if showBar
        fraction = p / d
        if fraction < 0 then fraction = 0
        if fraction > 1 then fraction = 1
        m.fill.width = fraction * 1348
        m.thumb.translation = [277 + fraction * 1348,176]
    end if
    if m.live then clock = "En vivo"
    m.modeText.text = mode
    m.clockText.text = clock
    m.durationText.text = ""
    if showBar and not m.live then m.durationText.text = plusClockText(d)
    m.pauseText.text = "OK / Play · Pausar"
    if m.wantPaused then m.pauseText.text = "OK / Play · Reanudar"
    if m.failed then m.pauseText.text = "OK · Reintentar"
    m.playGlyph.visible = m.wantPaused or m.failed
    m.pauseGlyph.visible = not m.playGlyph.visible
    m.rewindControl.visible = not m.live
    m.forwardControl.visible = not m.live
    applyControlSurfaces()
    m.keyText.text = "↓ Ajustes: Audio · Subtítulos · Imagen y zoom"
    if not m.live and m.current <> invalid and m.current.doesExist("introStart") and m.current.doesExist("introEnd")
        introStart = plusClockValue(m.current.introStart)
        introEnd = plusClockValue(m.current.introEnd)
        currentPosition = playerPosition()
        if introStart <> invalid and introEnd <> invalid and currentPosition <> invalid
            if currentPosition >= introStart and currentPosition < introEnd then m.keyText.text = "↓ Ajustes · Zoom / Saltar intro"
        end if
    end if
    m.keyText.text += "   ·   ↑ Audio   ·   ↓ Subtítulos"
    m.noticeText.text = ""
    if m.monotonic.totalMilliseconds() < m.noticeUntil then m.noticeText.text = m.notice
end sub

sub advanceSegmentRestart(now as integer)
    if m.segmentRestartStage = 1
        if m.decoder.state = "stopped"
            m.decoder.content = m.segmentPendingContent
            m.segmentRestartStage = 2
            m.segmentRestartAt = now
            emitDiagnostic("segment_content_set")
        end if
    else if m.segmentRestartStage = 2
        if now - m.segmentRestartAt >= 300
            m.decoder.control = "play"
            m.segmentPendingContent = invalid
            m.segmentRestartStage = 0
            emitDiagnostic("segment_play")
        end if
    end if
end sub

' Retry one stalled native HLS startup by fully detaching and reattaching
' the same ContentNode to the Video node. This is deliberately limited to one
' retry per request; the second timeout returns to the normal error surface.
sub beginHlsSoftRestart(now as integer)
    if m.mediaNode = invalid
        m.hlsStartupIsolation = false
        m.failed = true
        m.watchdogReason = "hls_restart_missing_content"
        m.notice = "No se pudo reiniciar la fuente. Atrás para volver."
        m.noticeUntil = 2147483647
        revealTransport()
        emitDiagnostic("hls_soft_restart_missing_content")
        return
    end if
    m.hlsRetryCount++
    m.hlsRestartStage = 1
    m.hlsRestartAt = now
    m.watch = plusWatchdogCreate(now)
    m.lastBuffer = invalid
    m.nativePollAt = -1000
    m.nativePollSignature = ""
    m.decoder.visible = false
    m.decoder.control = "stop"
    m.decoder.content = invalid
    print "[RokuPlus hls-retry] attempt="; m.hlsRetryCount; " action=detach"
    emitDiagnostic("hls_soft_restart_begin")
end sub

sub advanceHlsSoftRestart(now as integer)
    if m.hlsRestartStage = 0 or not m.mediaOpen then return
    if m.hlsRestartStage = 1
        if m.decoder.state = "stopped"
            ' Rebuild a fresh ContentNode so Video cannot retain a stale HLS parser/session.
            source = m.mediaNode
            freshMedia = CreateObject("roSGNode", "ContentNode")
            freshMedia.url = source.url
            freshMedia.title = source.title
            freshMedia.streamFormat = source.streamFormat
            freshMedia.live = source.live
            freshMedia.httpCertificatesFile = source.httpCertificatesFile
            freshHeaders = CreateObject("roArray", 2, true)
            if type(source.httpHeaders) = "roArray"
                for each header in source.httpHeaders
                    freshHeaders.push(header)
                end for
            end if
            freshMedia.httpHeaders = freshHeaders
            m.mediaNode = freshMedia
            m.decoder.contentIsPlaylist = false
            m.decoder.content = freshMedia
            m.hlsPrebufferPending = true
            print "[RokuPlus hls-retry] action=fresh-content format="; freshMedia.streamFormat; " headers="; freshHeaders.count()
            m.hlsRestartStage = 2
            m.hlsRestartAt = now
            emitDiagnostic("hls_soft_restart_fresh_content")
        else if now - m.hlsRestartAt >= 5000
            m.hlsRestartStage = 0
            m.hlsStartupIsolation = false
            m.failed = true
            m.watchdogReason = "hls_restart_stop_timeout"
            m.notice = "No se pudo reiniciar el reproductor. Atrás para volver."
            m.noticeUntil = 2147483647
            revealTransport()
            emitDiagnostic("hls_soft_restart_stop_timeout")
        end if
    else if m.hlsRestartStage = 2 and now - m.hlsRestartAt >= 500
        m.decoder.visible = true
        m.hlsPrebufferPending = true
        m.decoder.control = "prebuffer"
        print "[RokuPlus hls-prebuffer] action=retry-prebuffer"
        m.hlsRestartStage = 0
        m.hlsRestartAt = 0
        m.watch = plusWatchdogCreate(now)
        print "[RokuPlus hls-retry] attempt="; m.hlsRetryCount; " action=reattach-prebuffer"
        emitDiagnostic("hls_soft_restart_play")
    end if
end sub

sub startStreamXArtwork(supplied as object)
    if type(supplied) <> "roAssociativeArray" then return
    imdbId = ""
    if GetInterface(supplied.imdbId,"ifString") <> invalid then imdbId = supplied.imdbId.trim()
    if imdbId = "" and GetInterface(supplied.imdb_id,"ifString") <> invalid then imdbId = supplied.imdb_id.trim()
    mediaType = "movie"
    kind = ""
    if GetInterface(supplied.kind,"ifString") <> invalid then kind = LCase(supplied.kind)
    if kind = "series" or kind = "episode" or kind = "tv" then mediaType = "series"
    if m.streamXTask <> invalid then m.streamXTask.cancelRequested = true
    task = CreateObject("roSGNode","StreamXImageTask")
    if task = invalid then return
    task.imdbId = imdbId
    task.mediaType = mediaType
    artworkTitle = ""
    if GetInterface(supplied.title,"ifString") <> invalid then artworkTitle = supplied.title.trim()
    if kind = "episode" and GetInterface(supplied.seriesTitle,"ifString") <> invalid and supplied.seriesTitle.trim() <> "" then artworkTitle = supplied.seriesTitle.trim()
    task.title = left(artworkTitle,160)
    if GetInterface(supplied.year,"ifString") <> invalid then task.year = left(supplied.year,16)
    if GetInterface(supplied.year,"ifInt") <> invalid then task.year = supplied.year.toStr()
    task.requestId = m.streamXRequestId
    task.observeField("result","onStreamXArtworkChanged")
    m.streamXTask = task
    task.control = "RUN"
end sub

sub cancelStreamXArtworkTask()
    if m.streamXTask <> invalid
        m.streamXTask.cancelRequested = true
        m.streamXTask = invalid
    end if
    if m.startupLogoPulse <> invalid then m.startupLogoPulse.control = "stop"
end sub

sub onStreamXArtworkChanged(event as object)
    data = event.getData()
    if type(data) <> "roAssociativeArray" then return
    if data.requestId <> m.streamXRequestId then return
    if type(m.current) <> "roAssociativeArray" then return
    if data.ok <> true then return
    if GetInterface(data.background,"ifString") <> invalid and left(data.background,8) = "https://"
        if m.startupBanner <> invalid then m.startupBanner.uri = data.background
    end if
    if GetInterface(data.logo,"ifString") <> invalid and left(data.logo,8) = "https://"
        if m.startupLogo <> invalid
            m.startupLogo.uri = data.logo
            m.startupLogo.visible = true
            if m.startupTitle <> invalid then m.startupTitle.visible = false
            if m.startupOverlay <> invalid and m.startupOverlay.visible and not isPreviewPresentation()
                if m.startupLogoPulse <> invalid then m.startupLogoPulse.control = "start"
            end if
        end if
    end if
end sub

sub startStartupTitleAnimation()
    if m.startupTimer <> invalid then m.startupTimer.control = "stop"
    if isPreviewPresentation() then return
    if m.startupOverlay = invalid or not m.startupOverlay.visible then return
    if m.startupLogo <> invalid and m.startupLogo.visible
        if m.startupLogoPulse <> invalid then m.startupLogoPulse.control = "start"
    else
        if m.startupTitle <> invalid
            fullTitle = m.titleText.text
            if GetInterface(fullTitle, "ifString") = invalid then fullTitle = "CARGANDO"
            m.startupTitle.text = UCase(fullTitle)
            m.startupTitle.visible = true
        end if
    end if
end sub

sub onStartupTypePulse()
    if m.startupTimer <> invalid then m.startupTimer.control = "stop"
end sub

sub onPulse()
    if not m.mediaOpen then return
    if m.endScreenOpen
        if m.endCountdownActive
            nowEnd = m.monotonic.totalMilliseconds()
            elapsedSeconds = int((nowEnd - m.endCountdownLastAt) / 1000)
            if elapsedSeconds > 0
                m.endCountdownLastAt += elapsedSeconds * 1000
                m.endCountdownRemaining = m.endCountdownRemaining - elapsedSeconds
                if m.endCountdownRemaining <= 0
                    m.endCountdownRemaining = 0
                    m.endCountdownActive = false
                    selectPlaybackEndItem()
                    return
                end if
                updateEndCountdownVisual()
            end if
        end if
    end if
    if m.tsRelayPending
        relayStatus = m.tsStreamServer.status
        nowRelay = m.monotonic.totalMilliseconds()
        if relayStatus = "listening"
            deviceInfo = CreateObject("roDeviceInfo")
            connectionInfo = deviceInfo.GetConnectionInfo()
            localIp = ""
            if type(connectionInfo) = "roAssociativeArray"
                if GetInterface(connectionInfo.ip,"ifString") <> invalid then localIp = connectionInfo.ip
            end if
            if localIp = "" or localIp = "0.0.0.0"
                m.tsRelayPending = false
                m.failed = true
                m.watchdogReason = "ts_relay_ip_unavailable"
                m.notice = "No se pudo obtener la dirección local del Roku."
                m.noticeUntil = 2147483647
                revealTransport()
                emitDiagnostic("ts_relay_ip_unavailable")
                return
            end if
            m.tsRelayLocalIp = localIp
            relayMedia = CreateObject("roSGNode","ContentNode")
            relayMedia.url = "http://" + localIp + ":49322/stream.ts?key=" + m.tsRelayAccessKey
            relayMedia.title = m.titleText.text
            relayMedia.streamFormat = "ts"
            relayMedia.live = false
            relayMedia.httpHeaders = CreateObject("roArray",0,true)
            m.mediaNode = relayMedia
            m.decoder.contentIsPlaylist = false
            m.decoder.content = relayMedia
            m.decoder.control = "play"
            m.tsRelayPending = false
            m.tsRelayActive = true
            print "[RokuPlus ts-relay] player_attached format=ts segments="; m.tsRelaySegments.count()
            emitDiagnostic("ts_relay_attached")
        else if relayStatus = "address_error" or relayStatus = "bind_error" or relayStatus = "listen_error" or nowRelay - m.tsRelayStartedAt >= 10000
            m.tsRelayPending = false
            m.failed = true
            m.watchdogReason = "ts_relay_server_failed"
            m.notice = "No se pudo iniciar el flujo TS local. OK para reintentar."
            m.noticeUntil = 2147483647
            revealTransport()
            print "[RokuPlus ts-relay] server_failed status="; relayStatus
            emitDiagnostic("ts_relay_server_failed")
        end if
        return
    end if
    updateExternalSubtitle()
    verifySeekResult()
    now = m.monotonic.totalMilliseconds()
    advanceTsRelayRestart(now)
    advanceSegmentRestart(now)
    advanceHlsSoftRestart(now)
    ' 3.5.55: sample native Video fields during HLS startup as well as normal playback.
    ' This diagnostic build intentionally trades a small amount of polling work for visibility.
    if now - m.nativePollAt >= 1000
        m.nativePollAt = now
        nativeSample = nativeStreamSnapshot()
        nativeSignature = FormatJson(nativeSample)
        if nativeSignature <> m.nativePollSignature
            m.nativePollSignature = nativeSignature
            emitDiagnostic("native_poll")
        end if
    end if
    if m.resumePending <> invalid and now - m.resumeStartedAt >= 15000
        m.resumePending = invalid
        m.resumeFailed = true
        m.resumeFailedPosition = playerPosition()
        m.resumeFailedAt = now
        emitDiagnostic("resume_metadata_timeout")
    end if
    if m.ticket <> invalid
        timeoutAt = m.ticket.issuedAt + 12000
        if m.ticket.doesExist("deadlineAt") then timeoutAt = m.ticket.deadlineAt
        if now >= timeoutAt
            isResumeSeek = false
            resumeTarget = m.ticket.target
            if m.ticket.doesExist("requestedTarget") then resumeTarget = m.ticket.requestedTarget
            if m.ticket.doesExist("isResume") then isResumeSeek = m.ticket.isResume = true
            if isResumeSeek
                emitDiagnostic("resume_seek_timeout")
                m.ticket = invalid
                scheduleResumeRetry(resumeTarget,"timeout")
            else
                emitDiagnostic("seek_timeout")
                m.notice = "El destino no se confirmó. Puedes seguir reproduciendo o volver."
                m.noticeUntil = now + 6000
                m.ticket = invalid
                ' A newer remote seek may be queued behind this timed-out seek.
                ' Keep that explicit user intent and let dispatchPendingSeek run it.
            end if
        end if
    end if
    dispatchPendingSeek()
    if not m.failed and m.watch <> invalid and m.hlsRestartStage = 0
        sample = renderedFields()
        reason = plusWatchdogObserve(m.watch,m.decoder.state,m.decoder.position,sample.video,m.wantPaused,m.ticket <> invalid,now)
        if reason <> ""
            if reason = "loading_timeout" and m.hlsStartupIsolation and m.hlsRetryCount < 1
                beginHlsSoftRestart(now)
            else
                m.watchdogReason = reason
                m.hlsStartupIsolation = false
                m.failed = true
                m.ticket = invalid
                m.pendingSeek = invalid
                m.decoder.visible = false
                m.notice = "La fuente dejó de avanzar. OK para reintentar; Atrás para elegir otra."
                if reason = "loading_timeout" then m.notice = "La fuente tardó demasiado. OK para reintentar; Atrás para elegir otra."
                m.noticeUntil = 2147483647
                revealTransport()
                emitDiagnostic(reason)
                publishProgress(true)
                m.decoder.control = "stop"
            end if
        end if
    end if
    if not m.failed and m.ticket = invalid and m.pendingSeek = invalid and m.decoder.state = "playing" and now >= m.panelUntil then m.panel.visible = false
    ' During initial buffering, avoid redrawing the full transport at 4 Hz.
    if not m.hlsStartupIsolation
        if m.decoder.state <> "buffering" or now - m.lastTransportDrawAt >= 1000 then drawTransport()
    end if
    updateSkipSegmentPrompt()
    publishProgress()
end sub

sub togglePause()
    if m.failed
        retry = {kind: m.current.kind}
        if m.current.itemId <> invalid then retry.itemId = m.current.itemId
        if GetInterface(m.current.requestId,"ifString") <> invalid then retry.requestId = m.current.requestId
        m.top.retryRequested = retry
        return
    end if
    ' Intent survives intermediate buffering / seek states. Reading only the
    ' current decoder state loses a quick second Play before pause completes.
    m.wantPaused = not m.wantPaused
    m.decoder.autoplayAfterSeek = not m.wantPaused
    if m.ticket <> invalid then m.ticket.paused = m.wantPaused
    if m.wantPaused and m.decoder.state = "playing" then m.decoder.control = "pause"
    if not m.wantPaused and m.decoder.state = "paused" then m.decoder.control = "resume"
    revealTransport()
    drawTransport()
end sub

sub skipIntro()
    if m.live or m.current = invalid then return
    if not m.current.doesExist("introStart") or not m.current.doesExist("introEnd") then return
    startAt = plusClockValue(m.current.introStart)
    endAt = plusClockValue(m.current.introEnd)
    currentAt = playerPosition()
    if startAt = invalid or endAt = invalid or currentAt = invalid or endAt <= startAt then return
    if currentAt < startAt or currentAt >= endAt then return
    if m.failed then return
    cancelPendingResumeForUserSeek()
    m.pendingSeek = {target:endAt,dueAt:m.monotonic.totalMilliseconds()+100}
    m.notice = "Saltando introducción…"
    m.noticeUntil = m.monotonic.totalMilliseconds()+4000
    revealTransport()
    drawTransport()
end sub

sub shiftTen(backwards as boolean)
    revealTransport()
    if m.live
        m.notice = "Este canal está en vivo."
        m.noticeUntil = m.monotonic.totalMilliseconds() + 5000
        drawTransport()
        return
    end if
    state = m.decoder.state
    origin = playerPosition()
    if m.failed then return
    ' During an outstanding seek a source normally buffers. Keep accepting
    ' remote intent there, but never start a seek during initial loading.
    if (state <> "playing" and state <> "paused" and m.ticket = invalid) or origin = invalid
        m.notice = "Espera a que termine de cargar."
        m.noticeUntil = m.monotonic.totalMilliseconds() + 5000
        drawTransport()
        return
    end if
    base = origin
    if m.ticket <> invalid then base = m.ticket.target
    if m.pendingSeek <> invalid then base = m.pendingSeek.target
    target = plusShiftDestination(base, playerDuration(), backwards)
    if target = invalid then return
    if abs(target - base) < 0.05 then return
    cancelPendingResumeForUserSeek()
    now = m.monotonic.totalMilliseconds()
    ' Collapse a short burst into one absolute destination and serialize it
    ' behind the decoder's existing request. No overlapping decoder.seek calls.
    m.pendingSeek = {target:target,dueAt:now+180}
    m.actionDirection = "right"
    if backwards then m.actionDirection = "left"
    m.actionUntil = now + 450
    m.notice = "Ir a " + plusClockText(target)
    m.noticeUntil = now + 6000
    drawTransport()
end sub

sub cancelPendingResumeForUserSeek()
    m.resumePending = invalid
    if m.pendingSeek <> invalid
        if m.pendingSeek.doesExist("isResume") and m.pendingSeek.isResume = true then m.pendingSeek = invalid
    end if
    if m.ticket <> invalid
        if m.ticket.doesExist("isResume") and m.ticket.isResume = true then m.ticket.isResume = false
    end if
    m.resumeFailed = false
    m.resumeFailedPosition = invalid
    m.resumeFailedAt = 0
end sub

function playerPosition() as dynamic
    nativePosition = plusClockValue(m.decoder.position)
    if nativePosition = invalid then return invalid
    if m.tsRelayMode
        offset = plusClockValue(m.tsRelayPositionOffset)
        if offset = invalid then offset = 0.0
        return offset + nativePosition
    end if
    return nativePosition
end function

function plusTsRelayOffsetForSegment(segmentIndex as integer) as dynamic
    if type(m.tsRelayOffsets) <> "roArray" then return invalid
    if segmentIndex < 0 or segmentIndex >= m.tsRelayOffsets.count() then return invalid
    return plusClockValue(m.tsRelayOffsets[segmentIndex])
end function

function playerDuration() as dynamic
    if m.tsRelayMode and m.tsRelayDuration <> invalid and m.tsRelayDuration > 0 then return m.tsRelayDuration
    return plusClockValue(m.decoder.duration)
end function

function plusTsRelaySegmentIndex(target as dynamic) as integer
    if not m.tsRelayMode or type(m.tsRelaySegments) <> "roArray" or type(m.tsRelayDurations) <> "roArray" then return -1
    if m.tsRelaySegments.count() < 2 or m.tsRelayDurations.count() <> m.tsRelaySegments.count() then return -1
    targetTime = plusClockValue(target)
    if targetTime = invalid or targetTime < 0 then return -1
    elapsed = 0.0
    for index = 0 to m.tsRelayDurations.count()-1
        segmentDuration = plusClockValue(m.tsRelayDurations[index])
        if segmentDuration = invalid or segmentDuration <= 0 then return -1
        if targetTime < elapsed + segmentDuration then return index
        elapsed += segmentDuration
    end for
    return m.tsRelayDurations.count()-1
end function

sub beginTsRelaySeek(segmentIndex as integer, target as dynamic)
    if segmentIndex < 0 or segmentIndex >= m.tsRelaySegments.count() then return
    m.tsRelayPrerollRetryUsed = false
    ' Resume from the beginning of the target TS segment. The segment boundary
    ' provides a nearby landing point; do not issue a native seek on the relay
    ' connection because this HTTP endpoint does not implement byte ranges.
    startSegmentIndex = segmentIndex
    m.tsRelayRestartSegment = startSegmentIndex
    m.tsRelayRestartStage = 1
    m.tsRelayRestartAt = m.monotonic.totalMilliseconds() + 450
    m.tsStreamServer.nextSegmentIndex = startSegmentIndex
    print "[RokuPlus ts-relay] seek_restart_requested target="; target; " targetSegment="; segmentIndex; " startSegment="; startSegmentIndex
    emitDiagnostic("ts_relay_seek_restart_requested")
    ' Stop the old HTTP response first. The relay task accepts the replacement
    ' connection after Roku closes the previous socket.
    m.decoder.control = "stop"
end sub

sub advanceTsRelayRestart(now as integer)
    if m.tsRelayRestartStage <> 1 or now < m.tsRelayRestartAt then return
    if not m.mediaOpen or not m.tsRelayMode or m.tsRelayRestartSegment < 0 or m.ticket = invalid then
        m.tsRelayRestartStage = 0
        m.tsRelayRestartAt = 0
        m.tsRelayRestartSegment = -1
        return
    end if
    if m.tsRelayLocalIp = ""
        m.ticket = invalid
        m.failed = true
        m.notice = "No se pudo recuperar la dirección local del servidor TS."
        m.noticeUntil = 2147483647
        m.decoder.visible = false
        revealTransport()
        emitDiagnostic("ts_relay_restart_ip_unavailable")
        m.tsRelayRestartStage = 0
        return
    end if
    relayOffset = plusTsRelayOffsetForSegment(m.tsRelayRestartSegment)
    if relayOffset = invalid
        m.ticket = invalid
        m.failed = true
        m.notice = "No se pudo calcular el tiempo global del segmento."
        m.noticeUntil = 2147483647
        m.decoder.visible = false
        revealTransport()
        emitDiagnostic("ts_relay_restart_offset_unavailable")
        m.tsRelayRestartStage = 0
        return
    end if
    ' The relay can only restart at a segment boundary. Verify against that
    ' actual landing point while retaining the originally requested position
    ' for diagnostics and user-facing context.
    if m.ticket.doesExist("requestedTarget") = false then m.ticket.requestedTarget = m.ticket.target
    m.ticket.target = relayOffset
    m.tsRelayLocalSeekPending = invalid
    m.tsRelayPositionOffset = relayOffset
    relayMedia = CreateObject("roSGNode","ContentNode")
    relayMedia.url = "http://" + m.tsRelayLocalIp + ":49322/stream.ts?key=" + m.tsRelayAccessKey + "&segment=" + m.tsRelayRestartSegment.toStr()
    relayMedia.title = m.titleText.text
    relayMedia.streamFormat = "ts"
    relayMedia.live = false
    relayMedia.httpHeaders = CreateObject("roArray",0,true)
    m.mediaNode = relayMedia
    m.decoder.contentIsPlaylist = false
    m.decoder.content = relayMedia
    m.decoder.autoplayAfterSeek = not m.wantPaused
    m.decoder.control = "play"
    print "[RokuPlus ts-relay] seek_restart segment="; m.tsRelayRestartSegment; " landingOffset="; relayOffset; " requestedTarget="; m.ticket.requestedTarget
    emitDiagnostic("ts_relay_seek_restart")
    m.tsRelayRestartStage = 0
    m.tsRelayRestartAt = 0
    m.tsRelayRestartSegment = -1
end sub

sub advanceTsRelayLocalSeek(now as integer)
    if m.tsRelayLocalSeekPending = invalid or not m.mediaOpen or not m.tsRelayMode then return
    if m.ticket = invalid
        m.tsRelayLocalSeekPending = invalid
        emitDiagnostic("ts_relay_local_seek_without_ticket")
        return
    end if
    state = m.decoder.state
    if state <> "playing" and state <> "paused" then return

    ' Decoder startup can spend several seconds buffering before its clock is usable.
    ' Start the readiness timeout only after playback actually enters playing/paused.
    if m.tsRelayLocalSeekPending.clockWaitStartedAt = 0
        m.tsRelayLocalSeekPending.clockWaitStartedAt = now
    end if

    localTarget = m.tsRelayLocalSeekPending.target
    segmentIndex = m.tsRelayLocalSeekPending.segment
    elapsed = now - m.tsRelayLocalSeekPending.clockWaitStartedAt
    nativePosition = plusClockValue(m.decoder.position)
    ready = false
    reason = "clock_advancing"

    if nativePosition <> invalid
        if m.tsRelayLocalSeekPending.firstPosition = invalid
            m.tsRelayLocalSeekPending.firstPosition = nativePosition
            m.tsRelayLocalSeekPending.lastPosition = nativePosition
            m.tsRelayLocalSeekPending.firstSampleAt = now
        else
            previousPosition = m.tsRelayLocalSeekPending.lastPosition
            if nativePosition > previousPosition + 0.05
                m.tsRelayLocalSeekPending.advanceCount++
            end if
            m.tsRelayLocalSeekPending.lastPosition = nativePosition
        end if

        if state = "playing" and m.tsRelayLocalSeekPending.advanceCount >= 2 and now - m.tsRelayLocalSeekPending.firstSampleAt >= 500
            ready = true
        else if state = "paused" and m.wantPaused and elapsed >= 600
            ready = true
            reason = "paused_clock_ready"
        end if
    end if

    ' If the restarted stream has not established a moving clock, try one
    ' deeper decoder preroll before issuing a local seek into an uninitialized
    ' transport stream. Keep the same absolute ticket target; restart computes
    ' the new local offset from the earlier segment.
    if not ready and elapsed >= 2500 and m.tsRelayLocalSeekPending.advanceCount = 0 and not m.tsRelayPrerollRetryUsed
        deeperStartSegment = segmentIndex - 5
        if deeperStartSegment < 0 then deeperStartSegment = 0
        if deeperStartSegment < segmentIndex
            m.tsRelayPrerollRetryUsed = true
            m.tsRelayLocalSeekPending = invalid
            m.tsRelayRestartSegment = deeperStartSegment
            m.tsRelayRestartStage = 1
            m.tsRelayRestartAt = now + 450
            m.tsStreamServer.nextSegmentIndex = deeperStartSegment
            print "[RokuPlus ts-relay] preroll_retry oldSegment="; segmentIndex; " newSegment="; deeperStartSegment; " waitMs="; elapsed
            emitDiagnostic("ts_relay_preroll_retry")
            m.decoder.control = "stop"
            return
        end if
    end if

    ' Never issue a native seek while the restarted TS decoder clock is stalled.
    ' The deeper-preroll retry above is the only restart attempt for this seek.
    if not ready and elapsed < 2500 then return

    beforePosition = nativePosition
    advanceCount = m.tsRelayLocalSeekPending.advanceCount
    m.tsRelayLocalSeekPending = invalid

    if not ready
        isResume = false
        if m.ticket.doesExist("isResume") then isResume = m.ticket.isResume = true
        m.ticket = invalid
        if isResume
            m.resumeFailed = true
            m.resumeFailedPosition = playerPosition()
            m.resumeFailedAt = now
            m.notice = "No se pudo confirmar la reanudación. La reproducción seguirá desde el preroll."
        else
            m.notice = "El reloj TS no avanzó. La reproducción seguirá desde el preroll."
        end if
        m.noticeUntil = now + 7000
        print "[RokuPlus ts-relay] local_seek_skipped segment="; segmentIndex; " reason=clock_stalled waitMs="; elapsed; " nativePosition="; beforePosition; " advances="; advanceCount
        emitDiagnostic("ts_relay_clock_stalled_no_local_seek")
        return
    end if

    m.tsRelayLocalSeekPending = invalid
    m.ticket.issuedAt = now
    m.ticket.deadlineAt = now + 12000
    m.ticket.bufferingTimeoutExtended = false
    m.ticket.sawBuffering = false
    m.ticket.actualStart = invalid
    m.ticket.landingAt = invalid
    m.ticket.landingPosition = invalid
    m.ticket.sawClockJump = false
    print "[RokuPlus ts-relay] local_seek_ready segment="; segmentIndex; " reason="; reason; " waitMs="; elapsed; " nativePosition="; beforePosition; " advances="; advanceCount
    m.decoder.seek = localTarget
    print "[RokuPlus ts-relay] local_seek segment="; segmentIndex; " target="; localTarget; " nativeBefore="; beforePosition
    emitDiagnostic("ts_relay_local_seek")
end sub

sub dispatchPendingSeek()
    if m.pendingSeek = invalid or m.ticket <> invalid or m.failed or not m.mediaOpen then return
    if m.monotonic.totalMilliseconds() < m.pendingSeek.dueAt then return
    state = m.decoder.state
    if state <> "playing" and state <> "paused" then return
    origin = playerPosition()
    if origin = invalid then return
    target = m.pendingSeek.target
    isResumeSeek = false
    if m.pendingSeek.doesExist("isResume") then isResumeSeek = m.pendingSeek.isResume = true
    m.pendingSeek = invalid
    if abs(target-origin) < 0.05
        if isResumeSeek
            m.resumeFailed = false
            emitDiagnostic("resume_already_at_target")
            publishProgress(true)
        end if
        return
    end if
    m.sequence++
    sample = renderedFields()
    v = plusClockValue(sample.video)
    verifyRendered = m.tsRelayMode
    if not m.tsRelayMode and v <> invalid then verifyRendered = abs(v-origin) <= 2
    seekIssuedAt = m.monotonic.totalMilliseconds()
    if m.tsRelayMode
        relaySegment = plusTsRelaySegmentIndex(target)
        if relaySegment < 0
            if isResumeSeek then scheduleResumeRetry(target,"segment_metadata_unavailable")
            m.notice = "No se pudo calcular el segmento para esa posición."
            m.noticeUntil = m.monotonic.totalMilliseconds()+6000
            drawTransport()
            return
        end if
    end if
    m.ticket = {id:m.sequence,origin:origin,target:target,paused:m.wantPaused,issuedPaused:state="paused",issuedAt:seekIssuedAt,deadlineAt:seekIssuedAt+12000,bufferingTimeoutExtended:false,sawBuffering:false,logs:0,verifyRendered:verifyRendered,verifyRenderedLocal:m.tsRelayMode,landingAt:invalid,landingPosition:invalid,sawClockJump:false,isResume:isResumeSeek}
    m.decoder.autoplayAfterSeek = not m.wantPaused
    emitDiagnostic("seek_request")
    if m.tsRelayMode
        beginTsRelaySeek(relaySegment,target)
    else
        m.decoder.seek = target
    end if
    drawTransport()
end sub

sub verifySeekResult()
    if m.ticket = invalid or not m.mediaOpen then return
    now = m.monotonic.totalMilliseconds()
    if now - m.ticket.issuedAt < 200 then return
    state = m.decoder.state
    if state <> "playing" and state <> "paused" then return
    if m.wantPaused and state <> "paused" then return
    p = playerPosition()
    if p = invalid then return
    sample = renderedFields()
    nativePosition = plusClockValue(m.decoder.position)
    candidate = plusSeekLanding(m.ticket,p,sample.video,now,state,nativePosition)
    if not candidate.ready then return
    requestedTarget = m.ticket.target
    if m.ticket.doesExist("requestedTarget") then requestedTarget = m.ticket.requestedTarget
    result = {id: m.ticket.id, requested: requestedTarget, observed: p, difference: p - m.ticket.target, pauseRequested: m.ticket.paused, state: state}
    result.withinOneSecond = abs(result.difference) <= 1
    m.ticket.result = result
    isResumeSeek = false
    resumeTarget = requestedTarget
    if m.ticket.doesExist("isResume") then isResumeSeek = m.ticket.isResume = true
    emitDiagnostic("seek_result")
    m.ticket = invalid
    if isResumeSeek
        if result.withinOneSecond
            m.resumeFailed = false
            emitDiagnostic("resume_seek_confirmed")
        else
            scheduleResumeRetry(resumeTarget,"landing_mismatch")
        end if
    else if not result.withinOneSecond
        m.notice = "La fuente ajustó el salto a " + plusClockText(p)
        m.noticeUntil = now + 5000
    end if
end sub

sub scheduleResumeRetry(target as dynamic, reason as string)
    if m.resumeAttempts < 2 and not m.failed and m.mediaOpen
        m.resumeAttempts = m.resumeAttempts + 1
        m.pendingSeek = {target:target,dueAt:m.monotonic.totalMilliseconds()+700,isResume:true}
        emitDiagnostic("resume_retry")
    else
        m.resumeFailed = true
        m.resumeFailedPosition = playerPosition()
        m.resumeFailedAt = m.monotonic.totalMilliseconds()
        m.pendingSeek = invalid
        m.notice = "No se pudo recuperar la posición guardada. La reproducción continuará desde el inicio."
        m.noticeUntil = m.monotonic.totalMilliseconds()+6000
        emitDiagnostic("resume_failed")
    end if
end sub

' A requested point can also be reached by ordinary playback after an ignored
' seek. Require a clock discontinuity or a fresh native actualStart indication
' before proximity can confirm anything; buffering by itself is not an ACK.
function plusSeekLanding(ticket as object, position as dynamic, video as dynamic, now as integer, state = "" as string, localPosition = invalid as dynamic) as object
    p = plusClockValue(position)
    answer = {ready:false}
    if p = invalid then return answer
    elapsed = (now-ticket.issuedAt)/1000.0
    if elapsed < 0.2 then return answer
    distance = abs(ticket.target-ticket.origin)
    movementEpsilon = distance/4
    if movementEpsilon > 0.05 then movementEpsilon = 0.05
    if abs(p-ticket.origin) < movementEpsilon then return answer
    v = plusClockValue(video)
    if ticket.verifyRendered
        if v = invalid then return answer
        renderedReference = p
        if ticket.doesExist("verifyRenderedLocal") and ticket.verifyRenderedLocal
            renderedReference = plusClockValue(localPosition)
            if renderedReference = invalid then return answer
        end if
        if abs(v-renderedReference) > 2 then return answer
    end if
    nativePaused = ticket.paused
    if state <> "" then nativePaused = state = "paused"
    previousPosition = ticket.origin
    previousAt = ticket.issuedAt
    previousPaused = ticket.paused
    if ticket.issuedPaused <> invalid then previousPaused = ticket.issuedPaused
    if ticket.observedPosition <> invalid then previousPosition = ticket.observedPosition
    if ticket.observedAt <> invalid then previousAt = ticket.observedAt
    if ticket.observedPaused <> invalid then previousPaused = ticket.observedPaused
    sampleElapsed = (now-previousAt)/1000.0
    if sampleElapsed < 0 then return answer
    naturalCeiling = sampleElapsed
    if previousPaused and nativePaused then naturalCeiling = 0.0
    jumpTolerance = distance/4
    if jumpTolerance > 2 then jumpTolerance = 2.0
    if jumpTolerance < 0.02 then jumpTolerance = 0.02
    delta = p-previousPosition
    if delta < -jumpTolerance or delta > naturalCeiling+jumpTolerance then ticket.sawClockJump = true
    ticket.observedPosition = p
    ticket.observedAt = now
    ticket.observedPaused = nativePaused
    actualStart = plusClockValue(ticket.actualStart)
    nativeAck = false
    if actualStart <> invalid and ticket.actualStartAt <> invalid and ticket.sawBuffering
        if ticket.actualStartAt >= ticket.issuedAt and ticket.actualStartAt <= now
            if ticket.doesExist("verifyRenderedLocal") and ticket.verifyRenderedLocal
                ' TS relay restarts the decoder on a new local clock. Compare
                ' bufferingStatus.actualStart with the local decoder position,
                ' not with the previous/global player timeline.
                localReference = plusClockValue(localPosition)
                if localReference <> invalid then nativeAck = abs(actualStart-localReference) <= 1.25
            else
                nativeAck = abs(actualStart-ticket.origin) >= movementEpsilon and abs(actualStart-p) <= 1.25
            end if
        end if
    end if
    if ticket.sawClockJump <> true and not nativeAck then return answer
    nearTarget = abs(p-ticket.target) <= 1.25
    if nearTarget
        answer.ready = true
        return answer
    end if
    if ticket.landingAt = invalid
        ticket.landingAt = now
        ticket.landingPosition = p
        return answer
    end if
    settledFor = (now-ticket.landingAt)/1000.0
    expectedLandingMotion = settledFor
    if nativePaused then expectedLandingMotion = 0.0
    if abs((p-ticket.landingPosition)-expectedLandingMotion) > 1.5
        ticket.landingAt = now
        ticket.landingPosition = p
        return answer
    end if
    answer.ready = settledFor >= 0.8
    return answer
end function

function renderedFields() as object
    output = {}
    source = m.decoder.positionInfo
    if type(source) = "roAssociativeArray"
        for each field in ["audio", "video", "epoch", "clip_id", "clipId"]
            if source[field] <> invalid then output[field] = source[field]
        end for
    end if
    return output
end function

sub emitDiagnostic(reason as string)
    if m.current = invalid then return
    entry = {event: reason, generation: m.generation, ms: m.monotonic.totalMilliseconds(), state: m.decoder.state, position: m.decoder.position, duration: m.decoder.duration, seekMode: m.accuracyMode, live: m.live, wantPaused: m.wantPaused, rendered: renderedFields()}
    itemId = plusSafePlaybackIdentity(m.current.itemId)
    provider = plusSafePlaybackIdentity(m.current.provider,true)
    if itemId <> "" then entry.itemId = itemId
    if provider <> "" then entry.provider = provider
    if GetInterface(m.current.streamFormat,"ifString") <> invalid
        entry.streamFormat = lcase(m.current.streamFormat)
        entry.requestedStreamFormat = lcase(m.current.streamFormat)
    end if
    if m.effectiveStreamFormat <> "" then entry.effectiveStreamFormat = m.effectiveStreamFormat
    entry.diagnosticTsActive = m.diagnosticTsActive
    entry.playerVisible = m.top.visible
    entry.decoderVisible = m.decoder.visible
    entry.transportVisible = m.panel.visible
    entry.phase = m.phase
    entry.hlsStartupIsolation = m.hlsStartupIsolation
    entry.hlsRetryCount = m.hlsRetryCount
    entry.hlsRestartStage = m.hlsRestartStage
    if m.mediaNode <> invalid
        entry.mediaStreamFormat = m.mediaNode.streamFormat
        entry.mediaLive = m.mediaNode.live
        if type(m.mediaNode.httpHeaders) = "roArray" then entry.mediaHeaderCount = m.mediaNode.httpHeaders.count()
    end if
    if m.decoder.hasField("contentIsPlaylist") then entry.contentIsPlaylist = m.decoder.contentIsPlaylist
    entry.failed = m.failed
    if m.watchdogReason <> "" then entry.watchdogReason = m.watchdogReason
    if m.decoder.state = "error" then entry.nativeError = plusSafeNativeError(m.decoder.errorCode,m.decoder.errorInfo)
    nativeDetails = nativeStreamSnapshot()
    if nativeDetails.count() > 0 then entry.native = nativeDetails
    if m.firstNative <> invalid then entry.firstNativePosition = m.firstNative
    if m.firstRendered <> invalid then entry.firstRenderedVideo = m.firstRendered
    if m.lastBuffer <> invalid then entry.buffer = m.lastBuffer
    if m.ticket <> invalid
        entry.seek = {id: m.ticket.id, origin: m.ticket.origin, target: m.ticket.target, issuedAt: m.ticket.issuedAt, deadlineAt: m.ticket.deadlineAt, bufferingTimeoutExtended: m.ticket.bufferingTimeoutExtended, paused: m.ticket.paused, sawBuffering: m.ticket.sawBuffering}
        if m.ticket.actualStart <> invalid then entry.seek.actualStart = m.ticket.actualStart
        if m.ticket.result <> invalid then entry.seek.result = m.ticket.result
        if reason = "position" or reason = "rendered"
            m.ticket.logs++
            if m.ticket.logs > 120 then return
        end if
    else if reason = "position" or reason = "rendered"
        return
    end if
    m.top.diagnostics = entry
    print "[RokuPlus] "; FormatJson(entry)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if key = "home" then return false
    if not m.mediaOpen then return false
    if isPreviewPresentation() then return false
    if not press then return true
    if m.skipPromptVisible and key = "OK"
        skipToDetectedSegment()
        return true
    end if
    if m.endScreenOpen
        if m.skipPromptVisible and (key = "up" or key = "down" or key = "left" or key = "right")
            m.skipPromptDismissed = true
            m.skipPromptVisible = false
            if m.skipPromptGroup <> invalid then m.skipPromptGroup.visible = false
        end if
        if key = "up"
            movePlaybackEndSelection(-1)
        else if key = "down"
            movePlaybackEndSelection(1)
        else if key = "OK" or key = "play"
            selectPlaybackEndItem()
        else if key = "left" or key = "rewind" or key = "right" or key = "fastforward"
            direction = 1
            if key = "left" or key = "rewind" then direction = -1
            movePlaybackEndSelection(direction)
        else if key = "back"
            closePlayback()
        end if
        return true
    end if
    if m.subtitleMenuOpen
        if key = "up"
            moveSubtitleMenuSelection(-1)
        else if key = "down"
            moveSubtitleMenuSelection(1)
        else if key = "OK" or key = "play"
            selectSubtitleTrack()
        else if key = "back"
            closeSubtitleMenu()
            revealTransport()
            drawTransport()
        end if
        return true
    end if
    if m.playerOptionsMenuOpen
        if key = "up"
            movePlayerOptionsMenuSelection(-1)
        else if key = "down"
            movePlayerOptionsMenuSelection(1)
        else if key = "OK" or key = "play"
            selectPlayerOptionsMenu()
        else if key = "back"
            closePlayerOptionsMenu()
            revealTransport()
            drawTransport()
        end if
        return true
    end if
    if m.displayMenuOpen
        if key = "up"
            moveDisplayMenuSelection(-1)
        else if key = "down"
            moveDisplayMenuSelection(1)
        else if key = "OK" or key = "play"
            selectDisplayMenu()
        else if key = "back"
            closeDisplayMenu()
            revealTransport()
            drawTransport()
        end if
        return true
    end if
    if m.audioMenuOpen
        if key = "up"
            moveAudioMenuSelection(-1)
        else if key = "down"
            moveAudioMenuSelection(1)
        else if key = "OK" or key = "play"
            selectAudioTrack()
        else if key = "back"
            closeAudioMenu()
            revealTransport()
            drawTransport()
        end if
        return true
    end if
    if key = "back"
        if m.live and m.top.allowPreviewReturn = true
            m.top.presentation = "preview"
            applyPresentation()
            m.top.previewReturned = true
        else
            closePlayback()
        end if
    else if key = "play"
        revealTransport()
        togglePause()
    else if key = "options" or key = "down"
        openPlayerOptionsMenu()
    else if key = "up"
        openAudioMenu()
    else if key = "OK"
        if m.panel.visible
            revealTransport()
            togglePause()
        else
            revealTransport()
        end if
    else if key = "left" or key = "rewind" or key = "replay"
        if m.segmentMode
            revealTransport()
        else
            shiftTen(true)
        end if
    else if key = "right" or key = "fastforward"
        if m.segmentMode
            revealTransport()
        else
            shiftTen(false)
        end if
    else
        revealTransport()
    end if
    return true
end function
