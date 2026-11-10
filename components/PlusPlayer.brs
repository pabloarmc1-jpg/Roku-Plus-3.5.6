' Original RokuPlus player. The source URL is never included in diagnostics.
sub init()
    m.top.focusable = true
    m.top.visible = false
    m.decoder = m.top.findNode("decoder")
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
        rect = plusPreviewBounds(m.top.previewRect)
        m.decoder.translation = [rect[0],rect[1]]
        m.decoder.width = rect[2]
        m.decoder.height = rect[3]
        m.panel.visible = false
        if m.top.hasFocus() then m.top.setFocus(false)
    else
        m.decoder.translation = [0,0]
        m.decoder.width = 1920
        m.decoder.height = 1080
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
        m.previewMask.translation = m.decoder.translation
        m.previewMask.width = m.decoder.width
        m.previewMask.height = m.decoder.height
        m.previewMask.visible = preview and m.mediaOpen
    end if
    m.decoder.visible = false
    if m.mediaOpen
        m.top.visible = true
        m.decoder.visible = not m.failed
        publishProgress(true)
    end if
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

sub openRequest()
    supplied = m.top.request
    if type(supplied) <> "roAssociativeArray" then return
    if GetInterface(supplied.url, "ifString") = invalid then return
    if len(supplied.url) = 0 then return
    ' Stop the preceding decoder without emitting a close for the new request.
    m.mediaOpen = false
    m.pulse.control = "stop"
    if m.startupTimer <> invalid then m.startupTimer.control = "stop"
    m.decoder.visible = false
    m.decoder.control = "stop"
    m.decoder.content = invalid
    m.generation++
    m.monotonic.mark()
    m.current = supplied
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
    if m.startupTitle <> invalid then m.startupTitle.text = ""
    m.startupCharIndex = 0
    if m.startupTimer <> invalid then m.startupTimer.control = "stop"
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
        m.tsRelayDuration = invalid
        if type(supplied.segmentDurations) = "roArray" and supplied.segmentDurations.count() = m.tsRelaySegments.count()
            durationTotal = 0.0
            durationValid = true
            for each segmentDuration in supplied.segmentDurations
                parsedDuration = plusClockValue(segmentDuration)
                if parsedDuration = invalid or parsedDuration <= 0 or parsedDuration > 3600
                    durationValid = false
                    exit for
                end if
                durationTotal += parsedDuration
            end for
            if durationValid and durationTotal > 0
                m.tsRelayDurations = supplied.segmentDurations
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
    m.ticket = invalid
    m.pendingSeek = invalid
    m.watch = invalid
    m.panel.visible = false
    m.decoder.visible = false
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
            publishProgress(true)
            closePlayback()
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
    currentPosition = plusClockValue(m.decoder.position)
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
    p = plusClockValue(m.decoder.position)
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
    if m.decoder = invalid or not m.decoder.hasField("availableAudioTracks") then return
    tracks = m.decoder.availableAudioTracks
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
            m.subtitleTrackIndex = i + 3
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
    output += prefix + "Configurar API Key (" + keyStatus + ")"
    output += chr(10)
    prefix = "   "
    if m.subtitleTrackIndex = 2 then prefix = "▶  "
    searchLabel = "Buscar subtítulos en línea (Español)"
    if m.subtitleOnlineBusy
        if m.subtitleOnlineOperation = "download" then searchLabel = "Descargando subtítulo..."
        if m.subtitleOnlineOperation = "search" then searchLabel = "Buscando en línea..."
    end if
    output += prefix + searchLabel
    for i = 0 to m.subtitleOnlineResults.count()-1
        output += chr(10)
        prefix = "   "
        if i + 3 = m.subtitleTrackIndex then prefix = "▶  "
        output += prefix + m.subtitleOnlineResults[i].label + "  (ES · en línea)"
    end for
    nativeOffset = 3 + m.subtitleOnlineResults.count()
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
    count = 3 + m.subtitleOnlineResults.count() + m.subtitleTracks.count()
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
        m.subtitleOnlineBusy = true
        m.subtitleOnlineOperation = "search"
        drawSubtitleMenu()
        startSubtitleSearchTask("search","")
        return
    else if m.subtitleTrackIndex < 3 + m.subtitleOnlineResults.count()
        onlineIndex = m.subtitleTrackIndex - 3
        if onlineIndex < 0 or onlineIndex >= m.subtitleOnlineResults.count() then return
        m.subtitleOnlinePendingLabel = m.subtitleOnlineResults[onlineIndex].label
        m.subtitleOnlineBusy = true
        m.subtitleOnlineOperation = "download"
        drawSubtitleMenu()
        startSubtitleSearchTask("download",m.subtitleOnlineResults[onlineIndex].id)
        return
    else
        nativeIndex = m.subtitleTrackIndex - 3 - m.subtitleOnlineResults.count()
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
            m.subtitleTrackIndex = 2
            m.notice = "Subtítulos encontrados: " + m.subtitleOnlineResults.count().toStr()
        else
            m.subtitleTrackIndex = 1
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
    position = plusClockValue(m.decoder.position)
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
    nativePosition = plusClockValue(m.decoder.position)
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
    clock = plusClockText(m.decoder.position)
    d = playerDuration()
    p = plusClockValue(m.decoder.position)
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
    m.keyText.text = "Atrás · Volver al título"
    if m.live then m.keyText.text = "Atrás · Volver a los canales"
    if not m.live and m.current <> invalid and m.current.doesExist("introStart") and m.current.doesExist("introEnd")
        introStart = plusClockValue(m.current.introStart)
        introEnd = plusClockValue(m.current.introEnd)
        currentPosition = plusClockValue(m.decoder.position)
        if introStart <> invalid and introEnd <> invalid and currentPosition <> invalid
            if currentPosition >= introStart and currentPosition < introEnd then m.keyText.text = "OPTIONS · Saltar introducción"
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

sub startStartupTitleAnimation()
    if isPreviewPresentation() or m.startupTimer = invalid or m.startupTitle = invalid then return
    if m.startupOverlay = invalid or not m.startupOverlay.visible then return
    m.startupCharIndex = 0
    m.startupTitle.text = ""
    m.startupTimer.control = "start"
end sub

sub onStartupTypePulse()
    if not m.mediaOpen or m.failed or m.phase = "playing" or m.startupOverlay = invalid or not m.startupOverlay.visible
        if m.startupTimer <> invalid then m.startupTimer.control = "stop"
        return
    end if
    fullTitle = m.titleText.text
    if m.startupCharIndex < len(fullTitle)
        m.startupCharIndex++
        m.startupTitle.text = left(fullTitle,m.startupCharIndex)
    else
        m.startupTimer.control = "stop"
    end if
end sub

sub onPulse()
    if not m.mediaOpen then return
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
        m.resumeFailedPosition = plusClockValue(m.decoder.position)
        m.resumeFailedAt = now
        emitDiagnostic("resume_metadata_timeout")
    end if
    if m.ticket <> invalid
        timeoutAt = m.ticket.issuedAt + 12000
        if m.ticket.doesExist("deadlineAt") then timeoutAt = m.ticket.deadlineAt
        if now >= timeoutAt
            isResumeSeek = false
            resumeTarget = m.ticket.target
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
    currentAt = plusClockValue(m.decoder.position)
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
    origin = plusClockValue(m.decoder.position)
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
    m.tsRelayRestartSegment = segmentIndex
    m.tsRelayRestartStage = 1
    m.tsRelayRestartAt = m.monotonic.totalMilliseconds() + 450
    m.tsStreamServer.nextSegmentIndex = segmentIndex
    print "[RokuPlus ts-relay] seek_restart_requested target="; target; " segment="; segmentIndex
    emitDiagnostic("ts_relay_seek_restart_requested")
    ' Stop the old HTTP response first. The relay task accepts the replacement
    ' connection after Roku closes the previous socket.
    m.decoder.control = "stop"
end sub

sub advanceTsRelayRestart(now as integer)
    if m.tsRelayRestartStage <> 1 or now < m.tsRelayRestartAt then return
    if not m.mediaOpen or not m.tsRelayMode or m.tsRelayRestartSegment < 0 then
        m.tsRelayRestartStage = 0
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
    print "[RokuPlus ts-relay] seek_restart segment="; m.tsRelayRestartSegment
    emitDiagnostic("ts_relay_seek_restart")
    m.tsRelayRestartStage = 0
    m.tsRelayRestartAt = 0
    m.tsRelayRestartSegment = -1
end sub

sub dispatchPendingSeek()
    if m.pendingSeek = invalid or m.ticket <> invalid or m.failed or not m.mediaOpen then return
    if m.monotonic.totalMilliseconds() < m.pendingSeek.dueAt then return
    state = m.decoder.state
    if state <> "playing" and state <> "paused" then return
    origin = plusClockValue(m.decoder.position)
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
    verifyRendered = false
    if v <> invalid then verifyRendered = abs(v-origin) <= 2
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
    m.ticket = {id:m.sequence,origin:origin,target:target,paused:m.wantPaused,issuedPaused:state="paused",issuedAt:seekIssuedAt,deadlineAt:seekIssuedAt+12000,bufferingTimeoutExtended:false,sawBuffering:false,logs:0,verifyRendered:verifyRendered,landingAt:invalid,landingPosition:invalid,sawClockJump:false,isResume:isResumeSeek}
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
    p = plusClockValue(m.decoder.position)
    if p = invalid then return
    sample = renderedFields()
    candidate = plusSeekLanding(m.ticket,p,sample.video,now,state)
    if not candidate.ready then return
    result = {id: m.ticket.id, requested: m.ticket.target, observed: p, difference: p - m.ticket.target, pauseRequested: m.ticket.paused, state: state}
    result.withinOneSecond = abs(result.difference) <= 1
    m.ticket.result = result
    isResumeSeek = false
    resumeTarget = m.ticket.target
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
        m.resumeFailedPosition = plusClockValue(m.decoder.position)
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
function plusSeekLanding(ticket as object, position as dynamic, video as dynamic, now as integer, state = "" as string) as object
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
        if abs(v-p) > 2 then return answer
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
            nativeAck = abs(actualStart-ticket.origin) >= movementEpsilon and abs(actualStart-p) <= 1.25
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
    else if key = "options"
        skipIntro()
    else if key = "up"
        openAudioMenu()
    else if key = "down"
        openSubtitleMenu()
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
