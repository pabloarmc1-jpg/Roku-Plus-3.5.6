' Pure playback liveness checks. No network or media URLs are retained here.
function plusWatchdogCreate(now as integer) as object
    return {waitSince:now,lastMotionAt:now,lastPosition:invalid,lastVideo:invalid,phase:"",havePlayed:false,clockSeen:false,failed:false}
end function

' A rendered-video clock takes precedence over the native position when present.
' Pause and an outstanding seek suspend the clock; changing loading states does
' not restart the loading deadline, so none/buffering/stopped cannot loop forever.
function plusWatchdogObserve(watch as object, state as string, position as dynamic, video as dynamic, paused as boolean, seeking as boolean, now as integer) as string
    if watch.failed then return ""
    p = plusWatchdogPosition(position)
    v = plusWatchdogPosition(video)
    if state = "paused" or (paused and state = "playing") or seeking
        watch.waitSince = now
        watch.lastMotionAt = now
        watch.lastPosition = p
        watch.lastVideo = v
        watch.phase = state
        return ""
    end if
    if state = "playing"
        watch.waitSince = invalid
        moved = false
        if not watch.havePlayed then moved = true
        watch.havePlayed = true
        if v <> invalid
            if watch.lastVideo = invalid
                moved = true
            else if plusWatchdogMoved(v,watch.lastVideo)
                moved = true
            end if
        else if p <> invalid
            if watch.lastPosition = invalid
                moved = true
            else if plusWatchdogMoved(p,watch.lastPosition)
                moved = true
            end if
        end if
        if moved then watch.lastMotionAt = now
        if v <> invalid or p <> invalid then watch.clockSeen = true
        watch.lastPosition = p
        if v <> invalid then watch.lastVideo = v
        watch.phase = state
        if watch.clockSeen and now-watch.lastMotionAt >= 60000
            watch.failed = true
            return "progress_timeout"
        end if
    else if state = "none" or state = "stopped" or state = "stopping" or state = "buffering" or state = "opening"
        if watch.waitSince = invalid then watch.waitSince = now
        watch.phase = state
        if now-watch.waitSince >= 60000
            watch.failed = true
            return "loading_timeout"
        end if
    else
        ' Native error and finished are handled by the normal state callback.
        watch.phase = state
    end if
    return ""
end function

function plusWatchdogMoved(current as dynamic, previous as dynamic) as boolean
    delta = current-previous
    return delta >= 0.05 or delta <= -0.05
end function

' Live streams may use Unix timestamps; transport display's VOD clock cap does
' not apply to liveness comparisons. Reject malformed/nonfinite numeric values.
function plusWatchdogPosition(value as dynamic) as dynamic
    if not plusNativeNumeric(value) then return invalid
    if value <> value then return invalid
    if value < 0 or value > 9000000000000.0 then return invalid
    return value
end function

function plusNativeNumeric(value as dynamic) as boolean
    return GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifLongInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid
end function

' Explicit numeric allowlist: native debug strings can contain signed URLs.
function plusSafeNativeError(code as dynamic, info as dynamic) as object
    answer = {}
    if plusNativeNumeric(code) then answer.errorCode = code
    if type(info) = "roAssociativeArray"
        detail = {}
        for each key in ["clipId","ignored","errcode","drmerrcode"]
            if plusNativeNumeric(info[key]) then detail[key] = info[key]
        end for
        if detail.count() > 0 then answer.errorInfo = detail
        safeMessage = plusSafeNativeText(info.errorMsg)
        safeString = plusSafeNativeText(info.errorStr)
        if safeMessage <> "" then answer.errorMessage = safeMessage
        if safeString <> "" then answer.errorDescription = safeString
    end if
    return answer
end function

function plusSafePlaybackIdentity(value as dynamic, provider = false as boolean) as string
    if GetInterface(value,"ifString") = invalid then return ""
    pattern = "^[a-zA-Z0-9:_-]{1,160}$"
    if provider then pattern = "^[a-z][a-z0-9-]{0,31}$"
    if not CreateObject("roRegex",pattern,"").isMatch(value) then return ""
    return value
end function


function plusSafeNativeText(value as dynamic) as string
    if GetInterface(value,"ifString") = invalid then return ""
    clean = left(value,180)
    clean = CreateObject("roRegex", "https?://[^\s]+", "i").replaceAll(clean, "[url] ")
    clean = CreateObject("roRegex", "[?&][A-Za-z0-9_.-]*(token|key|auth|sig)[A-Za-z0-9_.-]*=[^& ]*", "i").replaceAll(clean, "[redacted]")
    return clean
end function
