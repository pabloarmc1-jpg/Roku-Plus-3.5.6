' Original Roku Plus adapter for the owner's fixed LAN compatibility helper.
' The helper receives public title identifiers only, never account credentials.
sub init()
    m.top.functionName = "runCompatibilityRequest"
end sub

sub runCompatibilityRequest()
    if m.top.operation = "touch"
        runCompatibilityTouch()
        return
    end if
    result = {ok: false, requestId: m.top.requestId, operation: "prepare", helper: false, fallback: true, errorcode: "pc_unavailable", message: "La computadora no está disponible. Se usará la fuente directa."}
    if m.top.operation <> "prepare"
        result.errorcode = "invalid_operation"
        result.message = "La operación de reproducción no es válida."
        if not m.top.cancelRequested then m.top.result = result
        return
    end if
    base = rpCompatBase(m.top.helperBase)
    if base = ""
        result.errorcode = "pc_not_configured"
        result.message = "Configura la dirección de tu computadora en Configuración."
        if not m.top.cancelRequested then m.top.result = result
        return
    end if
    route = rpCompatPrepareRoute(m.top.itemId, m.top.kind, m.top.season, m.top.episode)
    if route = ""
        result.errorcode = "invalid_item"
        result.message = "El título no tiene un identificador válido para esta reproducción."
        if not m.top.cancelRequested then m.top.result = result
        return
    end if
    clock = CreateObject("roTimespan")
    clock.mark()
    pollPort = CreateObject("roMessagePort")
    nextUrl = base + route
    jobId = ""
    while clock.totalMilliseconds() < 30000
        if m.top.cancelRequested then return
        remaining = 30000 - clock.totalMilliseconds()
        requestLimit = 3000
        if remaining < requestLimit then requestLimit = remaining
        response = rpCompatFetch(nextUrl, requestLimit, base)
        if m.top.cancelRequested then return
        if not response.ok
            if clock.totalMilliseconds() >= 30000 and jobId <> ""
                result.errorcode = "prepare_timeout"
                result.message = "La preparación tardó demasiado. Se usará la fuente directa."
            end if
            m.top.result = result
            return
        end if
        job = rpCompatResponse(response.data, jobId, base)
        if job.status = "invalid"
            result.errorcode = "helper_protocol"
            result.message = "La computadora devolvió una respuesta incompatible. Se usará la fuente directa."
            m.top.result = result
            return
        end if
        jobId = job.jobid
        if job.status = "ready"
            result.ok = true
            result.helper = true
            result.fallback = false
            result.errorcode = ""
            result.message = ""
            result.url = job.playlist
            result.streamFormat = "hls"
            result.jobid = jobId
            m.top.result = result
            return
        end if
        if job.status = "error"
            result.errorcode = "helper_error"
            result.message = "No se pudo preparar este título en la computadora. Se usará la fuente directa."
            m.top.result = result
            return
        end if
        ' A small cooperative pause leaves cancellation responsive while the
        ' helper downloads and remuxes the first closed HLS segments.
        pauseStart = clock.totalMilliseconds()
        while clock.totalMilliseconds() - pauseStart < 500 and clock.totalMilliseconds() < 30000
            if m.top.cancelRequested then return
            wait(50, pollPort)
        end while
        nextUrl = base + "/status/" + jobId
    end while
    result.errorcode = "prepare_timeout"
    result.message = "La preparación tardó demasiado. Se usará la fuente directa."
    if not m.top.cancelRequested then m.top.result = result
end sub

' One status GET refreshes the helper's lease without preparing another job or
' changing playback. Failure is informational; callers keep the current player.
sub runCompatibilityTouch()
    result = {ok: false, requestId: m.top.requestId, operation: "touch", helper: true, fallback: false, errorcode: "pc_unavailable", message: "No se pudo actualizar la conexión con la computadora."}
    base = rpCompatBase(m.top.helperBase)
    if base = ""
        result.errorcode = "pc_not_configured"
        if not m.top.cancelRequested then m.top.result = result
        return
    end if
    route = rpCompatTouchRoute(m.top.jobid)
    if route = ""
        result.errorcode = "invalid_job"
        result.message = "El trabajo de reproducción no es válido."
        if not m.top.cancelRequested then m.top.result = result
        return
    end if
    result.jobid = lcase(m.top.jobid)
    response = rpCompatFetch(base + route, 3000, base)
    if m.top.cancelRequested then return
    if response.ok
        job = rpCompatResponse(response.data, result.jobid, base)
        result.status = job.status
        if job.status = "ready" or job.status = "preparing"
            result.ok = true
            result.errorcode = ""
            result.message = ""
        else
            result.errorcode = "helper_protocol"
            if job.status = "error" then result.errorcode = "helper_error"
        end if
    end if
    m.top.result = result
end sub

function rpCompatTouchRoute(value as dynamic) as string
    if GetInterface(value, "ifString") = invalid then return ""
    if not CreateObject("roRegex", "^[A-Fa-f0-9]{32}$", "").isMatch(value) then return ""
    return "/status/" + lcase(value)
end function

function rpCompatPrepareRoute(itemId as dynamic, kind as dynamic, season as dynamic, episode as dynamic) as string
    if GetInterface(itemId, "ifString") = invalid then return ""
    if GetInterface(kind, "ifString") = invalid then return ""
    if not CreateObject("roRegex", "^tt[0-9]{5,12}$", "").isMatch(itemId) then return ""
    if kind = "movie" then return "/prepare/movie/" + itemId
    if kind <> "episode" then return ""
    if GetInterface(season, "ifInt") = invalid or GetInterface(episode, "ifInt") = invalid then return ""
    if season < 0 or season > 999 or episode < 1 or episode > 9999 then return ""
    return "/prepare/series/" + itemId + "/" + season.toStr() + "/" + episode.toStr()
end function

function rpCompatJobId(value as dynamic) as string
    if GetInterface(value, "ifString") = invalid then return ""
    if not CreateObject("roRegex", "^[A-Za-z0-9_-]{1,80}$", "").isMatch(value) then return ""
    return value
end function

function rpCompatResponse(data as dynamic, expectedJob as string, base as string) as object
    result = {status: "invalid", jobid: "", playlist: ""}
    if type(data) <> "roAssociativeArray" then return result
    if GetInterface(data.status, "ifString") = invalid then return result
    job = rpCompatJobId(data.jobid)
    if job = "" then return result
    if expectedJob <> "" and job <> expectedJob then return result
    if data.status <> "preparing" and data.status <> "ready" and data.status <> "error" then return result
    result.jobid = job
    if data.status = "ready"
        expectedUrl = base + "/stream/" + job + "/index.m3u8"
        if GetInterface(data.playlist, "ifString") = invalid then return result
        if data.playlist <> expectedUrl then return result
        result.playlist = expectedUrl
    end if
    result.status = data.status
    return result
end function

function rpCompatFileSize(stat as dynamic) as integer
    if type(stat) <> "roAssociativeArray" then return -1
    if not stat.doesExist("size") then return -1
    size = stat.size
    numeric = GetInterface(size, "ifInt") <> invalid or GetInterface(size, "ifLongInt") <> invalid or GetInterface(size, "ifFloat") <> invalid or GetInterface(size, "ifDouble") <> invalid
    if not numeric then return -1
    if size < 0 then return -1
    if size > 65536 then return 65537
    return int(size)
end function

function rpCompatFetch(url as string, deadline as integer, base as string) as object
    response = {ok: false, data: invalid}
    if m.top.cancelRequested or deadline <= 0 then return response
    ' url is built solely from validated IDs plus one of the two literal paths.
    prefix = base + "/"
    if left(url, len(prefix)) <> prefix then return response
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setUrl(url)
    transfer.addHeader("User-Agent", "RokuPlusPersonal/1.0")
    files = CreateObject("roFileSystem")
    filename = "tmp:/rokuplus-compat-" + CreateObject("roDeviceInfo").getRandomUUID() + ".json"
    if not transfer.asyncGetToFile(filename)
        files.delete(filename)
        return response
    end if
    clock = CreateObject("roTimespan")
    clock.mark()
    done = false
    status = 0
    while clock.totalMilliseconds() < deadline
        if m.top.cancelRequested then exit while
        size = rpCompatFileSize(files.stat(filename))
        if size > 65536 then exit while
        waitMs = deadline - clock.totalMilliseconds()
        if waitMs <= 0 then exit while
        if waitMs > 50 then waitMs = 50
        event = wait(waitMs, port)
        if type(event) = "roUrlEvent"
            if event.getSourceIdentity() = transfer.getIdentity() and event.getInt() = 1
                status = event.getResponseCode()
                done = true
                exit while
            end if
        end if
    end while
    if not done then transfer.asyncCancel()
    size = rpCompatFileSize(files.stat(filename))
    if done and status >= 200 and status < 300 and size > 0 and size <= 65536 and not m.top.cancelRequested
        body = ReadAsciiFile(filename)
        if len(body) > 0 and len(body) <= 65536
            parsed = ParseJson(body)
            if type(parsed) = "roAssociativeArray"
                response.data = parsed
                response.ok = true
            end if
        end if
    end if
    files.delete(filename)
    return response
end function


function rpCompatBase(value as dynamic) as string
    if GetInterface(value,"ifString") = invalid then return ""
    candidate = value.trim()
    if len(candidate) = 0 or len(candidate) > 120 then return ""
    if not CreateObject("roRegex", "^http://[A-Za-z0-9.-]+:[0-9]{1,5}$", "").isMatch(candidate) then return ""
    colon = instr(8, candidate, ":")
    if colon < 0 then return ""
    port = val(mid(candidate, colon + 1))
    if port < 1 or port > 65535 then return ""
    return candidate
end function
