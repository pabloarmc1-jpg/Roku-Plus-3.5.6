' Original RokuPlus player. The source URL is never included in diagnostics.
sub init()
    m.top.focusable = true
    m.top.visible = false
    m.decoder = m.top.findNode("decoder")
    m.previewMask = m.top.findNode("previewMask")
    m.backdrop = m.top.findNode("backdrop")
    m.panel = m.top.findNode("transport")
    m.capsule = m.top.findNode("capsule")
    m.titleShade = m.top.findNode("titleShade")
    m.centerSurface = m.top.findNode("centerSurface")
    m.titleText = m.top.findNode("titleText")
    m.metaText = m.top.findNode("metaText")
    m.clockText = m.top.findNode("clockText")
    m.modeText = m.top.findNode("modeText")
    m.durationText = m.top.findNode("durationText")
    m.pauseText = m.top.findNode("pauseText")
    m.keyText = m.top.findNode("keyText")
    m.noticeText = m.top.findNode("noticeText")
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
            revealTransport()
            m.top.setFocus(true)
        end if
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
    m.decoder.visible = false
    m.decoder.control = "stop"
    m.decoder.content = invalid
    m.generation++
    m.monotonic.mark()
    m.current = supplied
    m.ticket = invalid
    m.pendingSeek = invalid
    m.actionUntil = 0
    m.actionDirection = ""
    m.lastBuffer = invalid
    m.firstNative = invalid
    m.firstRendered = invalid
    m.failed = false
    m.closing = false
    m.alreadyClosed = false
    m.live = supplied.kind = "live"
    m.wantPaused = supplied.startPaused = true
    m.panelUntil = 6000
    m.noticeUntil = 0
    m.notice = ""
    m.bufferSince = 0
    m.watch = plusWatchdogCreate(0)
    m.lastProgressAt = -1000
    m.phase = "opening"
    m.resumePending = invalid
    m.resumeAttempts = 0
    m.resumeFailed = false
    resumeValue = plusClockValue(supplied.resumePosition)
    if not m.live and resumeValue <> invalid and resumeValue > 15 and resumeValue < 172800 then m.resumePending = resumeValue
    m.titleText.text = "Reproducción"
    if GetInterface(supplied.title, "ifString") <> invalid then m.titleText.text = left(supplied.title, 130)
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
    media = CreateObject("roSGNode", "ContentNode")
    media.url = supplied.url
    media.title = m.titleText.text
    media.streamFormat = format
    media.live = m.live
    media.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    ' Build headers in a local resizable array. SceneGraph node fields may
    ' expose a fixed-size copy after assignment, so do not mutate the field.
    requestHeaders = CreateObject("roArray", 2, true)
    requestHeaders.push("User-Agent: RokuPlus/1.0")
    if type(supplied.mediaHeaders) = "roAssociativeArray"
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
    m.decoder.enableUI = false
    m.decoder.enableTrickPlay = false
    m.decoder.notificationInterval = 0.1
    m.decoder.autoplayAfterSeek = true
    m.accuracyMode = "unavailable"
    if m.decoder.hasField("seekMode")
        m.decoder.seekMode = "accurate"
        m.accuracyMode = m.decoder.seekMode
    end if
    m.decoder.content = media
    m.mediaOpen = true
    m.top.visible = true
    m.top.active = true
    applyPresentation()
    m.decoder.control = "play"
    m.pulse.control = "start"
    emitDiagnostic("open")
    drawTransport()
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
    m.current = invalid
    m.top.request = invalid
    m.top.active = false
    m.alreadyClosed = true
    m.closing = false
    m.top.closedRequest = closedRequest
    m.top.closed = true
end sub

sub onDecoderState()
    if not m.mediaOpen or m.closing then return
    m.phase = m.decoder.state
    if m.phase = "buffering"
        m.bufferSince = m.monotonic.totalMilliseconds()
        if m.ticket <> invalid then m.ticket.sawBuffering = true
        revealTransport()
    end if
    emitDiagnostic("state")
    if m.phase = "playing"
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
        m.bufferSince = invalid
        if not m.wantPaused
            m.decoder.control = "resume"
            return
        end if
        revealTransport()
    else if m.phase = "error"
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
    duration = plusClockValue(m.decoder.duration)
    if duration = invalid or duration <= 0 then return
    resumeAt = m.resumePending
    if duration <= resumeAt + 20 then return
    currentPosition = plusClockValue(m.decoder.position)
    ' If playback has already advanced, do not seek late to an old bookmark.
    if currentPosition <> invalid and currentPosition > 15
        m.resumePending = invalid
        emitDiagnostic("resume_skipped_playing")
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
        if m.ticket <> invalid
            actualStart = plusClockValue(info.actualStart)
            if actualStart <> invalid
                m.ticket.actualStart = actualStart
                m.ticket.actualStartAt = sample.observedAtMs
            end if
        end if
    end if
    emitDiagnostic("buffering_status")
end sub

sub publishProgress(force = false as boolean)
    now = m.monotonic.totalMilliseconds()
    if not force and now - m.lastProgressAt < 500 then return
    m.lastProgressAt = now
    state = m.decoder.state
    if m.phase = "opening" then state = "opening"
    presentation = "fullscreen"
    if isPreviewPresentation() then presentation = "preview"
    nativePosition = plusClockValue(m.decoder.position)
    nativeDuration = plusClockValue(m.decoder.duration)
    resumeInFlight = m.resumePending <> invalid
    if m.pendingSeek <> invalid and m.pendingSeek.doesExist("isResume") then resumeInFlight = resumeInFlight or m.pendingSeek.isResume = true
    if m.ticket <> invalid and m.ticket.doesExist("isResume") then resumeInFlight = resumeInFlight or m.ticket.isResume = true
    ' Do not let startup zeroes or stale positionInfo overwrite the saved bookmark.
    if resumeInFlight then return
    if m.resumeFailed
        if nativePosition = invalid or nativePosition <= 15 then return
        m.resumeFailed = false
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
    state = m.decoder.state
    mode = "Reproduciendo"
    if state = "paused" then mode = "En pausa"
    if state = "buffering" or state = "none" or state = "stopped" then mode = "Cargando"
    if m.ticket <> invalid or m.pendingSeek <> invalid then mode = "Buscando posición"
    if m.failed then mode = "No se pudo reproducir"
    clock = plusClockText(m.decoder.position)
    d = plusClockValue(m.decoder.duration)
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
    m.noticeText.text = ""
    if m.monotonic.totalMilliseconds() < m.noticeUntil then m.noticeText.text = m.notice
end sub

sub onPulse()
    if not m.mediaOpen then return
    verifySeekResult()
    now = m.monotonic.totalMilliseconds()
    if m.ticket <> invalid
        if now - m.ticket.issuedAt >= 12000
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
                m.pendingSeek = invalid
            end if
        end if
    end if
    dispatchPendingSeek()
    if not m.failed and m.watch <> invalid
        sample = renderedFields()
        reason = plusWatchdogObserve(m.watch,m.decoder.state,m.decoder.position,sample.video,m.wantPaused,m.ticket <> invalid,now)
        if reason <> ""
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
    if not m.failed and m.ticket = invalid and m.pendingSeek = invalid and m.decoder.state = "playing" and now >= m.panelUntil then m.panel.visible = false
    drawTransport()
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
    target = plusShiftDestination(base, m.decoder.duration, backwards)
    if target = invalid then return
    if abs(target - base) < 0.05 then return
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
    m.ticket = {id:m.sequence,origin:origin,target:target,paused:m.wantPaused,issuedPaused:state="paused",issuedAt:m.monotonic.totalMilliseconds(),sawBuffering:false,logs:0,verifyRendered:verifyRendered,landingAt:invalid,landingPosition:invalid,sawClockJump:false,isResume:isResumeSeek}
    m.decoder.autoplayAfterSeek = not m.wantPaused
    emitDiagnostic("seek_request")
    m.decoder.seek = target
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
    if m.decoder.state = "error" then entry.nativeError = plusSafeNativeError(m.decoder.errorCode,m.decoder.errorInfo)
    if m.firstNative <> invalid then entry.firstNativePosition = m.firstNative
    if m.firstRendered <> invalid then entry.firstRenderedVideo = m.firstRendered
    if m.lastBuffer <> invalid then entry.buffer = m.lastBuffer
    if m.ticket <> invalid
        entry.seek = {id: m.ticket.id, origin: m.ticket.origin, target: m.ticket.target, issuedAt: m.ticket.issuedAt, paused: m.ticket.paused, sawBuffering: m.ticket.sawBuffering}
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
    else if key = "OK"
        if m.panel.visible
            revealTransport()
            togglePause()
        else
            revealTransport()
        end if
    else if key = "left" or key = "rewind" or key = "replay"
        shiftTen(true)
    else if key = "right" or key = "fastforward"
        shiftTen(false)
    else
        revealTransport()
    end if
    return true
end function
