' Anonymous StreamX metadata lookup. Playback never waits for this request.
sub init()
    m.top.functionName = "runStreamXImageLookup"
end sub

sub runStreamXImageLookup()
    answer = {ok:false,requestId:m.top.requestId,logo:"",background:"",imdbId:""}
    imdbId = m.top.imdbId.trim()
    mediaType = LCase(m.top.mediaType)
    if mediaType <> "series" then mediaType = "movie"

    ' Some catalogues do not expose IMDb IDs. Resolve only an exact title match,
    ' with the catalogue year used as an additional guard when available.
    if not CreateObject("roRegex","^tt[0-9]{5,12}$","").isMatch(imdbId)
        imdbId = resolveStreamXImdbId(m.top.title,m.top.year,mediaType)
    end if
    if imdbId = ""
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if
    answer.imdbId = imdbId

    endpoint = "https://api.streamx.qzz.io/meta/" + mediaType + "/" + imdbId + "?enrich=0"
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.addHeader("Accept","application/json")
    transfer.setUrl(endpoint)
    if not transfer.asyncGetToString()
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if

    clock = CreateObject("roTimespan")
    clock.mark()
    responseEvent = invalid
    while clock.totalMilliseconds() < 6500
        if m.top.cancelRequested
            transfer.asyncCancel()
            return
        end if
        event = wait(100,port)
        if type(event) = "roUrlEvent" and event.getSourceIdentity() = transfer.getIdentity()
            responseEvent = event
            exit while
        end if
    end while
    if responseEvent = invalid
        transfer.asyncCancel()
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if
    if responseEvent.getResponseCode() <> 200
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if

    parsed = ParseJson(responseEvent.getString())
    if type(parsed) <> "roAssociativeArray"
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if
    metadata = parsed
    if type(parsed.meta) = "roAssociativeArray" then metadata = parsed.meta
    if GetInterface(metadata.logo,"ifString") <> invalid then answer.logo = metadata.logo
    if GetInterface(metadata.background,"ifString") <> invalid then answer.background = metadata.background
    if type(metadata.images) = "roAssociativeArray"
        logoImages = metadata.images.logo
        backgroundImages = metadata.images.background
        if type(logoImages) = "roAssociativeArray"
            if answer.logo = "" and GetInterface(logoImages.large,"ifString") <> invalid then answer.logo = logoImages.large
            if answer.logo = "" and GetInterface(logoImages.original,"ifString") <> invalid then answer.logo = logoImages.original
        end if
        if type(backgroundImages) = "roAssociativeArray"
            if answer.background = "" and GetInterface(backgroundImages.large,"ifString") <> invalid then answer.background = backgroundImages.large
            if answer.background = "" and GetInterface(backgroundImages.original,"ifString") <> invalid then answer.background = backgroundImages.original
        end if
    end if
    answer.ok = answer.logo <> "" or answer.background <> ""
    if not m.top.cancelRequested then m.top.result = answer
end sub

function resolveStreamXImdbId(title as string, yearValue as dynamic, mediaType as string) as string
    cleanTitle = title.trim()
    if cleanTitle = "" or len(cleanTitle) > 160 then return ""
    query = cleanTitle
    targetYear = ""
    if GetInterface(yearValue,"ifString") <> invalid
        yearMatch = CreateObject("roRegex","[0-9]{4}","").match(yearValue)
        if yearMatch.count() > 0 then targetYear = yearMatch[0]
    else if GetInterface(yearValue,"ifInt") <> invalid
        if yearValue >= 1880 and yearValue <= 2199 then targetYear = yearValue.toStr()
    end if
    if targetYear <> "" then query += " " + targetYear

    encoder = CreateObject("roUrlTransfer")
    endpoint = "https://api.streamx.qzz.io/imdb/search?q=" + encoder.escape(query)
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.addHeader("Accept","application/json")
    transfer.setUrl(endpoint)
    if not transfer.asyncGetToString() then return ""

    clock = CreateObject("roTimespan")
    clock.mark()
    responseEvent = invalid
    while clock.totalMilliseconds() < 4500
        if m.top.cancelRequested
            transfer.asyncCancel()
            return ""
        end if
        event = wait(100,port)
        if type(event) = "roUrlEvent" and event.getSourceIdentity() = transfer.getIdentity()
            responseEvent = event
            exit while
        end if
    end while
    if responseEvent = invalid
        transfer.asyncCancel()
        return ""
    end if
    if responseEvent.getResponseCode() <> 200 then return ""
    payload = ParseJson(responseEvent.getString())
    if type(payload) <> "roAssociativeArray" or type(payload.results) <> "roArray" then return ""

    wantedTitle = LCase(cleanTitle)
    for each candidate in payload.results
        if type(candidate) = "roAssociativeArray"
            candidateId = ""
            candidateTitle = ""
            candidateType = ""
            candidateYear = ""
            if GetInterface(candidate.id,"ifString") <> invalid then candidateId = candidate.id
            if GetInterface(candidate.title,"ifString") <> invalid then candidateTitle = candidate.title.trim()
            if GetInterface(candidate.type,"ifString") <> invalid then candidateType = candidate.type
            if GetInterface(candidate.year,"ifInt") <> invalid then candidateYear = candidate.year.toStr()
            if GetInterface(candidate.year,"ifString") <> invalid then candidateYear = candidate.year
            if candidateId <> "" and candidateTitle <> "" and LCase(candidateTitle) = wantedTitle
                if candidateType = mediaType and CreateObject("roRegex","^tt[0-9]{5,12}$","").isMatch(candidateId)
                    if targetYear = "" or candidateYear = targetYear then return candidateId
                end if
            end if
        end if
    end for
    return ""
end function
