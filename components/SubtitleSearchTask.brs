' Subtitle Search Engine adapter with optional local API-key authentication.
' Provider documentation: https://subtitles.website/docs/
sub init()
    m.top.functionName = "runSubtitleSearch"
end sub

sub runSubtitleSearch()
    answer = {ok:false,operation:m.top.operation,items:[],subtitleText:"",message:"No se pudo consultar el catálogo de subtítulos."}
    operation = m.top.operation
    if operation = "search"
        title = left(m.top.title,160).trim()
        imdb = left(m.top.imdbId,24).trim()
        language = lcase(left(m.top.language,8).trim())
        if language = "" then language = "es"
        if title = "" and imdb = ""
            answer.message = "No hay título ni IMDb para buscar subtítulos."
            m.top.result = answer
            return
        end if
        transfer = subtitleTransfer(m.top.apiKey)
        endpoint = "https://subtitles.website/strapi/api/search/subtitles?"
        if imdb <> ""
            if not CreateObject("roRegex","^tt[0-9]{5,12}$","").isMatch(imdb)
                imdb = ""
            end if
        end if
        if imdb = "" and title = ""
            answer.message = "El identificador IMDb no es válido y falta el título."
            m.top.result = answer
            return
        end if
        if imdb <> ""
            endpoint += "imdb=" + transfer.Escape(imdb)
        else
            endpoint += "title=" + transfer.Escape(title)
        end if
        endpoint += "&language=" + transfer.Escape(language) + "&format=srt"
        body = subtitleGet(transfer,endpoint)
        if GetInterface(body,"ifString") = invalid
            answer.message = "El servicio de subtítulos no respondió."
            if m.subtitleHttpStatus = 429 then answer.message = "Se alcanzó el límite diario de solicitudes de subtítulos."
            if m.subtitleHttpStatus = 401 or m.subtitleHttpStatus = 403 then answer.message = "La API Key fue rechazada. Revisa la clave en el menú de subtítulos."
            m.top.result = answer
            return
        end if
        if len(body) = 0
            answer.message = "El servicio de subtítulos devolvió una respuesta vacía."
            m.top.result = answer
            return
        end if
        parsed = ParseJson(body)
        if type(parsed) <> "roAssociativeArray"
            answer.message = "La respuesta del servicio no tiene un formato válido."
            m.top.result = answer
            return
        end if
        if type(parsed.data) <> "roArray"
            answer.message = "La respuesta del servicio no incluye resultados."
            m.top.result = answer
            return
        end if
        ' IMDb is the most precise key, but subtitle catalogs sometimes index
        ' releases only by title. Retry by title only after a valid empty IMDb
        ' response; do not retry transport/authentication failures.
        if parsed.data.count() = 0 and imdb <> "" and title <> ""
            fallbackEndpoint = "https://subtitles.website/strapi/api/search/subtitles?"
            fallbackEndpoint += "title=" + transfer.Escape(title)
            fallbackEndpoint += "&language=" + transfer.Escape(language) + "&format=srt"
            fallbackBody = subtitleGet(transfer,fallbackEndpoint)
            if GetInterface(fallbackBody,"ifString") <> invalid and fallbackBody <> ""
                fallbackParsed = ParseJson(fallbackBody)
                if type(fallbackParsed) = "roAssociativeArray"
                    if type(fallbackParsed.data) = "roArray"
                        parsed = fallbackParsed
                        print "[RokuPlus subtitles-online] title_fallback results="; parsed.data.count()
                    end if
                end if
            end if
        end if
        for each entry in parsed.data
            if answer.items.count() >= 12 then exit for
            if type(entry) = "roAssociativeArray"
                id = entry.id
                release = entry.release
                if GetInterface(id,"ifString") <> invalid and CreateObject("roRegex","^[a-zA-Z0-9_-]{6,80}$","").isMatch(id)
                    if GetInterface(release,"ifString") <> invalid
                        label = left(release,100)
                        lang = language
                        if type(entry.language) = "roAssociativeArray"
                            if GetInterface(entry.language.code,"ifString") <> invalid then lang = entry.language.code
                        end if
                        answer.items.push({id:id,label:label,language:lang})
                    end if
                end if
            end if
        end for
        ' SubDL is a separate fallback provider. Its key is stored independently
        ' from the Subtitle Search Engine key and is never printed to diagnostics.
        if answer.items.count() = 0
            subdlKey = m.top.subdlApiKey
            if GetInterface(subdlKey,"ifString") <> invalid and subdlKey.trim() <> ""
                subdlItems = subtitleSubDlSearch(title,imdb,language,subdlKey,m.top.kind,m.top.seasonNumber,m.top.episodeNumber)
                for each subdlItem in subdlItems
                    if answer.items.count() >= 12 then exit for
                    answer.items.push(subdlItem)
                end for
                if answer.items.count() > 0 then answer.provider = "subdl"
            end if
        end if
        answer.ok = true
        answer.message = ""
        if answer.items.count() = 0 then answer.message = "No se encontraron subtítulos en español para este título."
        print "[RokuPlus subtitles-online] search results="; answer.items.count()
        m.top.result = answer
        return
    else if operation = "download"
        subtitleId = m.top.subtitleId
        if left(subtitleId,6) = "subdl:"
            subdlPath = mid(subtitleId,7)
            if left(subdlPath,10) <> "/subtitle/" or instr(1,subdlPath,"..") > 0 or instr(1,subdlPath,chr(92)) > 0 or instr(1,subdlPath,chr(10)) > 0
                answer.message = "El enlace de SubDL no es válido."
                m.top.result = answer
                return
            end if
            subdlUrl = "https://dl.subdl.com" + subdlPath
            subdlText = subtitleGet(subtitleTransfer(""),subdlUrl)
            if GetInterface(subdlText,"ifString") = invalid or len(subdlText) = 0 or len(subdlText) > 2097152
                answer.message = "No se pudo descargar el subtítulo desde SubDL."
                m.top.result = answer
                return
            end if
            if instr(1,subdlText,"-->") = 0
                answer.message = "El archivo de SubDL no parece ser un SRT válido."
                m.top.result = answer
                return
            end if
            answer.ok = true
            answer.subtitleText = subdlText
            answer.message = ""
            print "[RokuPlus subtitles-online] provider=subdl download bytes="; len(subdlText)
            m.top.result = answer
            return
        end if
        if GetInterface(subtitleId,"ifString") = invalid or not CreateObject("roRegex","^[a-zA-Z0-9_-]{6,80}$","").isMatch(subtitleId)
            answer.message = "El identificador del subtítulo no es válido."
            m.top.result = answer
            return
        end if
        transfer = subtitleTransfer(m.top.apiKey)
        endpoint = "https://subtitles.website/strapi/api/search/download/" + subtitleId
        body = subtitleGet(transfer,endpoint)
        if GetInterface(body,"ifString") = invalid or len(body) = 0
            answer.message = "No se pudo obtener el enlace del subtítulo."
            if m.subtitleHttpStatus = 429 then answer.message = "Se alcanzó el límite diario de solicitudes de subtítulos."
            if m.subtitleHttpStatus = 401 or m.subtitleHttpStatus = 403 then answer.message = "La API Key fue rechazada. Revisa la clave en el menú de subtítulos."
            m.top.result = answer
            return
        end if
        parsed = ParseJson(body)
        if type(parsed) <> "roAssociativeArray"
            answer.message = "El servicio no entregó un archivo de subtítulos."
            m.top.result = answer
            return
        end if
        if GetInterface(parsed.download_url,"ifString") = invalid
            answer.message = "El servicio no entregó un archivo de subtítulos."
            m.top.result = answer
            return
        end if
        path = parsed.download_url
        if left(path,9) <> "/uploads/" or instr(1,path,"..") > 0 or instr(1,path,chr(92)) > 0
            answer.message = "El enlace de descarga no es válido."
            m.top.result = answer
            return
        end if
        subtitleUrl = "https://subtitles.website/strapi" + path
        transfer = subtitleTransfer(m.top.apiKey)
        subtitleText = subtitleGet(transfer,subtitleUrl)
        if GetInterface(subtitleText,"ifString") = invalid
            answer.message = "No se pudo leer el archivo SRT."
            if m.subtitleHttpStatus = 429 then answer.message = "Se alcanzó el límite diario de solicitudes de subtítulos."
            if m.subtitleHttpStatus = 401 or m.subtitleHttpStatus = 403 then answer.message = "La API Key fue rechazada. Revisa la clave en el menú de subtítulos."
            m.top.result = answer
            return
        end if
        if len(subtitleText) = 0 or len(subtitleText) > 2097152
            answer.message = "El archivo SRT está vacío o supera el tamaño permitido."
            m.top.result = answer
            return
        end if
        if instr(1,subtitleText,"-->") = 0
            answer.message = "El archivo descargado no parece ser un SRT válido."
            m.top.result = answer
            return
        end if
        answer.ok = true
        answer.subtitleText = subtitleText
        answer.message = ""
        print "[RokuPlus subtitles-online] download bytes="; len(subtitleText)
        m.top.result = answer
        return
    else if operation = "source"
        subtitleUrl = m.top.subtitleUrl
        safeUrl = orbitHttpsUrl(subtitleUrl)
        allowed = CreateObject("roRegex","^https://(([a-z0-9-]+\.)?vimeos\.(net|zip)|([a-z0-9-]+\.)?fastream\.to|([a-z0-9-]+\.)?voe-network\.net|([a-z0-9-]+\.)?voe\.sx|([a-z0-9-]+\.)?cloudwindow-route\.com|([a-z0-9-]+\.)?arianathankspecial\.com)/","i").isMatch(safeUrl)
        pathLower = lcase(safeUrl)
        isVtt = instr(1,pathLower,".vtt") > 0
        isSrt = instr(1,pathLower,".srt") > 0
        isPlaylist = instr(1,pathLower,".m3u8") > 0
        if not allowed or (not isVtt and not isSrt and not isPlaylist)
            answer.message = "La dirección de subtítulos de la fuente no es válida."
            m.top.result = answer
            return
        end if
        transfer = subtitleTransfer("")
        transfer.addHeader("Accept","text/vtt,application/x-subrip,application/vnd.apple.mpegurl,text/plain,*/*")
        ' Match the Vimeos player request captured in the HAR.
        if CreateObject("roRegex","^https://([a-z0-9-]+\.)?vimeos\.(net|zip)/","i").isMatch(safeUrl)
            transfer.addHeader("Referer","https://vimeos.net/")
        end if
        subtitleText = subtitleGet(transfer,safeUrl)
        if GetInterface(subtitleText,"ifString") = invalid or len(subtitleText) = 0 or len(subtitleText) > 2097152
            answer.message = "No se pudo descargar la pista de subtítulos de la fuente."
            m.top.result = answer
            return
        end if
        if isSrt and instr(1,subtitleText,"-->") > 0
            subtitleText = subtitleSrtToVtt(subtitleText)
        else if instr(1,subtitleText,"WEBVTT") = 0 and left(subtitleText.trim(),7) = "#EXTM3U"
            subtitleText = subtitleVttPlaylist(subtitleText,safeUrl)
        end if
        if GetInterface(subtitleText,"ifString") = invalid or instr(1,subtitleText,"WEBVTT") = 0
            answer.message = "La fuente no entregó una pista WebVTT válida o compatible."
            m.top.result = answer
            return
        end if
        answer.ok = true
        answer.subtitleText = subtitleText
        answer.message = ""
        m.top.result = answer
        return
    end if
    answer.message = "Operación de subtítulos desconocida."
    m.top.result = answer
end sub

function subtitleSrtToVtt(body as string) as dynamic
    if len(body) = 0 or len(body) > 2097152 then return invalid
    clean = body.replace(chr(13),"")
    if left(clean,3) = chr(239) + chr(187) + chr(191) then clean = mid(clean,4)
    lines = clean.split(chr(10))
    output = "WEBVTT" + chr(10) + chr(10)
    timingRegex = CreateObject("roRegex","^([0-9]{2}:[0-9]{2}:[0-9]{2}),([0-9]{3})[ \t]+-->[ \t]+([0-9]{2}:[0-9]{2}:[0-9]{2}),([0-9]{3})(.*)$","")
    cueCount = 0
    for each line in lines
        timing = timingRegex.match(line)
        if timing.count() >= 6
            output += timing[1] + "." + timing[2] + " --> " + timing[3] + "." + timing[4] + timing[5] + chr(10)
            cueCount++
        else
            output += line + chr(10)
        end if
        if len(output) > 2097152 then return invalid
    end for
    if cueCount = 0 then return invalid
    return output
end function
function subtitleVttPlaylist(body as string, playlistUrl as string) as dynamic
    output = "WEBVTT" + chr(10) + chr(10)
    lines = body.replace(chr(13),"").split(chr(10))
    pendingDuration = 0.0
    elapsed = 0.0
    segmentCount = 0
    for each rawLine in lines
        line = rawLine.trim()
        if left(line,8) = "#EXTINF:"
            durationText = mid(line,9)
            commaAt = instr(1,durationText,",")
            if commaAt > 0 then durationText = left(durationText,commaAt-1)
            pendingDuration = val(durationText)
        else if left(line,11) = "#EXT-X-KEY:"
            attrs = rpHdOnlineAttributes(line)
            if lcase(orbitText(attrs.METHOD,20)) <> "none" then return invalid
        else if line <> "" and left(line,1) <> "#"
            if segmentCount >= 200 then return invalid
            segmentUrl = rpHdOnlineJoin(playlistUrl,line)
            if segmentUrl = "" or instr(1,lcase(segmentUrl),".vtt") = 0 then return invalid
            segment = subtitleGet(subtitleTransfer(""),segmentUrl)
            if GetInterface(segment,"ifString") = invalid or len(segment) = 0 or len(segment) > 262144 or instr(1,segment,"WEBVTT") = 0 then return invalid
            segmentLines = segment.replace(chr(13),"").split(chr(10))
            i = 0
            while i < segmentLines.count()
                cueLine = segmentLines[i].trim()
                if instr(1,cueLine,"-->") > 0
                    timing = CreateObject("roRegex","^((([0-9]{2}:)?[0-9]{2}:[0-9]{2})\.[0-9]{3})[ \t]+-->[ \t]+((([0-9]{2}:)?[0-9]{2}:[0-9]{2})\.[0-9]{3})","").match(cueLine)
                    if timing.count() >= 5
                        cueStart = subtitleVttTime(timing[1]) + elapsed
                        cueEnd = subtitleVttTime(timing[4]) + elapsed
                        if cueStart >= 0 and cueEnd > cueStart
                            output += subtitleVttStamp(cueStart) + " --> " + subtitleVttStamp(cueEnd) + chr(10)
                            i++
                            while i < segmentLines.count() and segmentLines[i].trim() <> ""
                                output += segmentLines[i].trim() + chr(10)
                                i++
                            end while
                            output += chr(10)
                        end if
                    end if
                end if
                i++
            end while
            if pendingDuration > 0 then elapsed += pendingDuration
            pendingDuration = 0.0
            segmentCount++
            if len(output) > 2097152 then return invalid
        end if
    end for
    if segmentCount = 0 then return invalid
    return output
end function

function subtitleVttTime(value as string) as float
    parts = value.split(":")
    if parts.count() = 2 then value = "00:" + value
    parts = value.split(":")
    if parts.count() <> 3 then return -1
    seconds = parts[2].split(".")
    if seconds.count() <> 2 then return -1
    hours = val(parts[0])
    minutes = val(parts[1])
    whole = val(seconds[0])
    millis = val(seconds[1])
    if hours < 0 or minutes < 0 or minutes > 59 or whole < 0 or whole > 59 or millis < 0 or millis > 999 then return -1
    return hours*3600 + minutes*60 + whole + millis/1000.0
end function

function subtitleVttStamp(value as float) as string
    totalMillis = int(value*1000 + 0.5)
    hours = totalMillis \ 3600000
    remainder = totalMillis mod 3600000
    minutes = remainder \ 60000
    remainder = remainder mod 60000
    seconds = remainder \ 1000
    millis = remainder mod 1000
    hourText = hours.toStr()
    minuteText = minutes.toStr()
    secondText = seconds.toStr()
    milliText = millis.toStr()
    if len(hourText) < 2 then hourText = "0" + hourText
    if len(minuteText) < 2 then minuteText = "0" + minuteText
    if len(secondText) < 2 then secondText = "0" + secondText
    if len(milliText) < 3 then milliText = "0" + milliText
    if len(milliText) < 3 then milliText = "0" + milliText
    return hourText + ":" + minuteText + ":" + secondText + "." + milliText
end function

function subtitleSubDlSearch(title as string, imdb as string, language as string, apiKey as string, kind as dynamic, seasonNumber as dynamic, episodeNumber as dynamic) as object
    items = []
    if apiKey = "" or len(apiKey) > 512 then return items
    if instr(1,apiKey,chr(10)) > 0 or instr(1,apiKey,chr(13)) > 0 then return items
    transfer = subtitleTransfer("")
    endpoint = "https://api.subdl.com/api/v1/subtitles?api_key=" + transfer.Escape(apiKey)
    if imdb <> "" and CreateObject("roRegex","^tt[0-9]{5,12}$","").isMatch(imdb)
        endpoint += "&imdb_id=" + transfer.Escape(imdb)
    else if title <> ""
        endpoint += "&film_name=" + transfer.Escape(title)
    else
        return items
    end if
    if kind = "episode"
        endpoint += "&type=tv"
        if GetInterface(seasonNumber,"ifString") <> invalid and seasonNumber <> "" then endpoint += "&season_number=" + transfer.Escape(seasonNumber)
        if GetInterface(episodeNumber,"ifString") <> invalid and episodeNumber <> "" then endpoint += "&episode_number=" + transfer.Escape(episodeNumber)
    else
        endpoint += "&type=movie"
    end if
    endpoint += "&languages=ES&unpack=1&subs_per_page=30&client=other"
    body = subtitleGet(transfer,endpoint)
    if GetInterface(body,"ifString") = invalid or body = "" then return items
    parsed = ParseJson(body)
    if type(parsed) <> "roAssociativeArray" then return items
    if parsed.status <> true then return items
    if type(parsed.subtitles) <> "roArray" then return items
    for each subtitle in parsed.subtitles
        if type(subtitle) = "roAssociativeArray" and type(subtitle.unpack_files) = "roArray"
            for each fileEntry in subtitle.unpack_files
                if items.count() >= 12 then exit for
                if type(fileEntry) = "roAssociativeArray"
                    lang = ""
                    format = ""
                    path = ""
                    label = ""
                    if GetInterface(fileEntry.language,"ifString") <> invalid then lang = ucase(fileEntry.language)
                    if lang = "ES" or lang = "SPA" or lang = "ES-ES" or lang = "ES-MX"
                        if GetInterface(fileEntry.format,"ifString") <> invalid then format = lcase(fileEntry.format)
                        if format = "srt"
                            if GetInterface(fileEntry.url,"ifString") <> invalid then path = fileEntry.url
                            if left(path,10) = "/subtitle/" and instr(1,path,"..") = 0 and instr(1,path,chr(92)) = 0
                                if GetInterface(fileEntry.release_name,"ifString") <> invalid then label = fileEntry.release_name
                                if label = "" and GetInterface(fileEntry.name,"ifString") <> invalid then label = fileEntry.name
                                if label = "" then label = "Subtítulo en español (SubDL)"
                                items.push({id:"subdl:" + path,label:left(label,100),language:"es",provider:"subdl"})
                            end if
                        end if
                    end if
                end if
            end for
        end if
        if items.count() >= 12 then exit for
    end for
    print "[RokuPlus subtitles-online] provider=subdl results="; items.count()
    return items
end function

function subtitleTransfer(apiKey as dynamic) as object
    transfer = CreateObject("roUrlTransfer")
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.enableEncodings(true)
    transfer.addHeader("User-Agent","RokuPlus/1.0")
    transfer.addHeader("Accept","application/json,text/plain,*/*")
    if GetInterface(apiKey,"ifString") <> invalid
        safeKey = apiKey.trim()
        if safeKey <> "" and len(safeKey) <= 512 and instr(1,safeKey,chr(10)) = 0 and instr(1,safeKey,chr(13)) = 0
            transfer.addHeader("Authorization","Bearer " + safeKey)
        end if
    end if
    return transfer
end function

function subtitleUrlAllowed(endpoint as string) as boolean
    safeUrl = orbitHttpsUrl(endpoint)
    if safeUrl = "" then return false
    if left(safeUrl,37) = "https://subtitles.website/strapi/api/" then return true
    if left(safeUrl,41) = "https://subtitles.website/strapi/uploads/" then return true
    if left(safeUrl,29) = "https://api.subdl.com/api/v1/" then return true
    if left(safeUrl,30) = "https://dl.subdl.com/subtitle/" then return true
    sourceHost = CreateObject("roRegex","^https://(([a-z0-9-]+\.)?vimeos\.(net|zip)|([a-z0-9-]+\.)?fastream\.to|([a-z0-9-]+\.)?voe-network\.net|([a-z0-9-]+\.)?voe\.sx|([a-z0-9-]+\.)?cloudwindow-route\.com|([a-z0-9-]+\.)?arianathankspecial\.com)/","i").isMatch(safeUrl)
    if not sourceHost then return false
    lowerUrl = lcase(safeUrl)
    return instr(1,lowerUrl,".vtt") > 0 or instr(1,lowerUrl,".srt") > 0 or instr(1,lowerUrl,".m3u8") > 0
end function

function subtitleGet(transfer as object, endpoint as string) as dynamic
    if not subtitleUrlAllowed(endpoint) then return invalid
    m.subtitleHttpStatus = 0
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setUrl(endpoint)
    if not transfer.asyncGetToString() then return invalid
    event = wait(12000,port)
    if type(event) = "roUrlEvent"
        if event.getSourceIdentity() = transfer.getIdentity() and event.getInt() = 1
            m.subtitleHttpStatus = event.getResponseCode()
            if m.subtitleHttpStatus = 200
                ' Roku follows HTTP redirects internally. Re-check the effective
                ' URL so an allowlisted source cannot redirect to an arbitrary host.
                finalUrl = transfer.getUrl()
                if not subtitleUrlAllowed(finalUrl)
                    print "[RokuPlus subtitles-online] rejected_redirect"
                    return invalid
                end if
                return event.getString()
            end if
        end if
    end if
    transfer.asyncCancel()
    return invalid
end function
