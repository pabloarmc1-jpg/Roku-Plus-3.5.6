' Original Roku Plus task: fetch only fixed, public catalog API endpoints.
sub init()
    m.top.functionName = "runCatalogRequest"
end sub

sub runCatalogRequest()
    operation = m.top.operation
    kind = m.top.kind
    answer = {ok: false, requestId: m.top.requestId, operation: operation, kind: kind, message: "No se pudo completar la consulta."}
    endpoint = ""
    skip = orbitInteger(m.top.skip, 100000)
    id = orbitImdb(m.top.imdbId)
    if operation = "mexico" or operation = "country" or operation = "latam"
        endpoint = orbitCountryEndpoint(operation, m.top.countryCode)
        if operation = "latam" then endpoint = "https://iptv-org.github.io/iptv/regions/latam.m3u"
        selectedCode = "mx"
        if operation = "country" then selectedCode = orbitCountryCode(m.top.countryCode)
        if operation = "latam" then selectedCode = "latam"
        selectedCountry = orbitCountryLookup(selectedCode)
        answer.kind = "live"
        answer.countryCode = selectedCode
        if selectedCountry <> invalid then answer.countryName = selectedCountry.name
        if endpoint = "" then answer.message = "Elige un país o región válido para ver sus canales."
    else if kind <> "movie" and kind <> "series"
        answer.message = "El tipo de catálogo no es válido."
    else if operation = "catalog"
        endpoint = "https://v3-cinemeta.strem.io/catalog/" + kind + "/top"
        extras = ""
        query = left(m.top.query.trim(), 120)
        encoder = CreateObject("roUrlTransfer")
        if query <> "" then extras = "search=" + encoder.escape(query)
        if skip > 0
            if extras <> "" then extras += "&"
            extras += "skip=" + skip.toStr()
        end if
        if extras <> "" then endpoint += "/" + extras
        endpoint += ".json"
    else if operation = "meta" and id <> ""
        endpoint = "https://v3-cinemeta.strem.io/meta/" + kind + "/" + id + ".json"
    else if operation = "resolve" and id <> ""
        resourceId = id
        if kind = "series"
            season = orbitInteger(m.top.season, 999, -1)
            episode = orbitInteger(m.top.episode, 9999, -1)
            if season >= 0 and episode > 0 then resourceId += ":" + season.toStr() + ":" + episode.toStr() else resourceId = ""
        end if
        if resourceId <> "" then endpoint = "https://mg.homelabx.qzz.io/stream/" + kind + "/" + resourceId + ".json"
    else
        answer.message = "La consulta no tiene un identificador válido."
    end if
    if endpoint = ""
        m.top.result = answer
        return
    end if
    response = orbitDownloadText(endpoint)
    if not response.ok
        answer.message = response.message
        answer.cancelled = response.cancelled
        m.top.result = answer
        return
    end if
    if m.top.cancelRequested then return
    if operation = "mexico" or operation = "country" or operation = "latam"
        answer.items = orbitCountryChannels(response.body, selectedCode)
        answer.items = rpLiveApplyArtwork(answer.items,ParseJson(ReadAsciiFile("pkg:/data/channel-logos.json")))
        answer.ok = answer.items.count() > 0
        answer.message = ""
        if not answer.ok then answer.message = "No se encontraron canales compatibles para este país o región."
    else
        data = ParseJson(response.body)
        if type(data) <> "roAssociativeArray"
            answer.message = "La fuente devolvió datos que no se pueden leer."
        else if operation = "catalog"
            page = orbitCatalog(data, kind, skip)
            answer.items = page.items
            answer.hasMore = page.hasMore
            answer.nextSkip = page.nextSkip
            answer.ok = true
            answer.message = ""
        else if operation = "meta"
            answer.item = orbitMetadata(data, kind, id)
            answer.ok = answer.item <> invalid
            answer.message = ""
            if not answer.ok then answer.message = "No se encontraron detalles para este título."
        else if operation = "resolve"
            stream = orbitResolvedStream(data)
            if stream <> invalid
                answer.url = stream.url
                answer.streamFormat = stream.streamFormat
                answer.description = stream.description
                answer.seekSupport = "unknown"
                answer.ok = true
                answer.message = ""
            else
                answer.message = "No hay una fuente compatible disponible para este título."
            end if
        end if
    end if
    if not m.top.cancelRequested then m.top.result = answer
end sub

function orbitDownloadText(endpoint as string) as object
    reply = {ok: false, body: "", message: "No se pudo conectar con la fuente.", cancelled: false}
    if m.top.cancelRequested
        reply.cancelled = true
        reply.message = "Consulta cancelada."
        return reply
    end if
    transfer = CreateObject("roUrlTransfer")
    messages = CreateObject("roMessagePort")
    transfer.setMessagePort(messages)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.addHeader("User-Agent", "RokuPlusPersonal/1.0")
    transfer.enableEncodings(true)
    transfer.setUrl(endpoint)
    files = CreateObject("roFileSystem")
    filename = "tmp:/rokuplus-catalog-" + CreateObject("roDeviceInfo").getRandomUUID() + ".txt"
    if not transfer.asyncGetToFile(filename) then return reply
    elapsed = CreateObject("roTimespan")
    elapsed.mark()
    finished = false
    code = 0
    while not finished
        if m.top.cancelRequested
            reply.cancelled = true
            reply.message = "Consulta cancelada."
            exit while
        end if
        if elapsed.totalMilliseconds() >= 20000
            reply.message = "La fuente tardó demasiado. Vuelve a intentar."
            exit while
        end if
        info = files.stat(filename)
        bytes = orbitTaskFileSize(info)
        if bytes > 2097152
            reply.message = "La respuesta de la fuente supera el límite permitido."
            exit while
        end if
        event = wait(50, messages)
        if type(event) = "roUrlEvent"
            if event.getSourceIdentity() = transfer.getIdentity() and event.getInt() = 1
                code = event.getResponseCode()
                finished = true
            end if
        end if
    end while
    if not finished then transfer.asyncCancel()
    if finished and code = 200 and not m.top.cancelRequested
        info = files.stat(filename)
        bytes = orbitTaskFileSize(info)
        if bytes > 0 and bytes <= 2097152
            reply.body = ReadAsciiFile(filename)
            if len(reply.body) > 0 and len(reply.body) <= 2097152 then reply.ok = true
        else
            reply.message = "La respuesta de la fuente está vacía o es demasiado grande."
        end if
    end if
    files.delete(filename)
    return reply
end function

' Stat() may return an empty associative array while the download has not yet
' created its file. Never compare a missing/non-numeric size with an integer.
function orbitTaskFileSize(info as dynamic) as integer
    if type(info) <> "roAssociativeArray" then return -1
    if not info.doesExist("size") then return -1
    value = info.size
    numeric = GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifLongInt") <> invalid or GetInterface(value, "ifFloat") <> invalid or GetInterface(value, "ifDouble") <> invalid
    if not numeric then return -1
    if value < 0 then return -1
    if value > 2097152 then return 2097153
    return int(value)
end function
