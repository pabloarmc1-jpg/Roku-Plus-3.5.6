sub init()
    m.top.focusable = true
    m.video = m.top.findNode("decoder")
    m.titleNode = m.top.findNode("titleText")
    m.statusNode = m.top.findNode("statusText")
    m.helpNode = m.top.findNode("helpText")
    m.errorNode = m.top.findNode("errorText")
    m.video.observeField("state","videoStateChanged")
    m.video.observeField("errorCode","videoErrorChanged")
    m.video.observeField("position","videoPositionChanged")
    m.video.observeField("duration","videoDurationChanged")
    m.statusNode.text = "Preparando video…"
    m.helpNode.text = "OK: pausar/reanudar    ← / →: retroceder/avanzar 10 s    Atrás: cerrar"
    m.errorNode.text = ""
    m.duration = 0
    m.closing = false
    m.closeTimer = m.top.findNode("closeTimer")
    m.closeTimer.observeField("fire","finishInvidiousClose")
end sub

sub openRequest()
    request = m.top.request
    if type(request) <> "roAssociativeArray" then return
    if not request.doesExist("url") or request.url = "" then return
    m.closeTimer.control = "stop"
    m.closing = false
    m.top.closed = false
    m.duration = 0
    m.errorNode.text = ""
    m.titleNode.text = left(invidiousText(request.title,180),180)
    m.statusNode.text = "Conectando con la fuente de video…"
    media = CreateObject("roSGNode","ContentNode")
    media.url = request.url
    media.title = m.titleNode.text
    media.live = false
    streamFormat = "mp4"
    if request.doesExist("streamFormat") and request.streamFormat <> "" then streamFormat = lcase(request.streamFormat)
    ' Progressive containers and native MPEG-DASH are handled by Roku Video.
    if streamFormat <> "mp4" and streamFormat <> "mkv" and streamFormat <> "webm" and streamFormat <> "dash"
        m.statusNode.text = "Contenedor no compatible. Se permiten MP4, MKV, WebM y DASH."
        return
    end if
    media.streamFormat = streamFormat
    if streamFormat = "dash"
        ' DASH contains separate adaptation sets; do not create a progressive
        ' streams array or try to mux audio/video in BrightScript.
        print "[RokuPlus Invidious playback] transport=DASH mode=native_adaptive"
        m.statusNode.text = "Abriendo manifiesto DASH adaptativo de Invidious…"
    else
        bitrate = 0
        if request.doesExist("bitrate") and request.bitrate <> invalid
            bitrate = val(request.bitrate.toStr())
        end if
        if bitrate <= 0
            m.statusNode.text = "La fuente progresiva no incluye un bitrate válido."
            return
        end if
        quality = false
        if bitrate >= 1500 then quality = true
        media.streams = [{url:request.url,bitrate:int(bitrate),quality:quality,contentid:"invidious-" + invidiousText(request.title,80)}]
    end if
    m.video.control = "stop"
    m.video.content = media
    m.top.active = true
    m.video.control = "play"
    m.top.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return true
    if key = "back"
        closeInvidiousPlayback()
        return true
    else if key = "OK" or key = "play" or key = "playpause" or key = "pause"
        if m.video.state = "playing"
            m.video.control = "pause"
        else if m.video.state = "paused"
            m.video.control = "resume"
        else if m.video.state = "stopped"
            m.video.control = "play"
        end if
        return true
    else if key = "left" or key = "rewind"
        seekBy(-10)
        return true
    else if key = "right" or key = "fastforward"
        seekBy(10)
        return true
    end if
    return true
end function

sub seekBy(delta as integer)
    position = m.video.position
    if position = invalid then position = 0
    target = position + delta
    if target < 0 then target = 0
    if m.duration > 0 and target > m.duration then target = m.duration
    m.video.seek = target
    m.statusNode.text = "Saltando a " + invidiousClock(target)
end sub

sub videoStateChanged(event as object)
    state = event.getData()
    if state = "playing"
        m.statusNode.text = "REPRODUCIENDO  ·  " + invidiousClock(m.video.position) + " / " + invidiousClock(m.duration)
    else if state = "paused"
        m.statusNode.text = "PAUSADO  ·  OK para reanudar"
    else if state = "buffering"
        m.statusNode.text = "CARGANDO VIDEO…"
    else if state = "finished"
        m.statusNode.text = "VIDEO FINALIZADO  ·  Atrás para volver a los resultados"
    else if state = "error"
        m.statusNode.text = "No se pudo reproducir este formato de video."
    else if state = "stopped" and m.closing
        finishInvidiousClose()
    else if state = "stopped" and m.top.active
        m.statusNode.text = "REPRODUCTOR DETENIDO"
    end if
end sub

sub videoErrorChanged(event as object)
    code = event.getData()
    message = m.video.errorMsg
    m.errorNode.text = "Error de reproducción (" + invidiousText(code,24) + "): " + invidiousText(message,180)
    m.statusNode.text = "La fuente no pudo abrirse en el reproductor Roku."
end sub

sub videoPositionChanged(event as object)
    if m.video.state = "playing"
        m.statusNode.text = "REPRODUCIENDO  ·  " + invidiousClock(event.getData()) + " / " + invidiousClock(m.duration)
    end if
end sub

sub videoDurationChanged(event as object)
    value = event.getData()
    if value <> invalid then m.duration = value
end sub

sub closeInvidiousPlayback()
    if not m.top.active or m.closing then return
    ' Do not detach DASH content or redraw the parent scene while Roku's
    ' native adaptive pipeline is tearing down. Stop first and close async.
    m.closing = true
    m.statusNode.text = "Cerrando reproductor…"
    m.closeTimer.duration = 0.6
    m.video.control = "stop"
    m.closeTimer.control = "start"
end sub

sub finishInvidiousClose()
    if not m.closing then return
    m.closeTimer.control = "stop"
    m.closing = false
    m.top.active = false
    ' Keep the last ContentNode attached. Replacing it on the next open avoids
    ' forcing a synchronous DASH detach on the UI thread during BACK.
    m.top.closed = true
end sub

function invidiousClock(value as dynamic) as string
    if value = invalid then return "00:00"
    seconds = int(value)
    if seconds < 0 then seconds = 0
    minutes = seconds \ 60
    remainder = seconds mod 60
    secondText = remainder.toStr()
    if remainder < 10 then secondText = "0" + secondText
    return minutes.toStr() + ":" + secondText
end function

function invidiousText(value as dynamic, limit as integer) as string
    if value = invalid then return ""
    result = ""
    if GetInterface(value,"ifString") <> invalid
        result = value
    else
        result = value.toStr()
    end if
    return left(result,limit)
end function
