' Anonymous StreamX metadata lookup. Playback never waits for this request.
sub init()
    m.top.functionName = "runStreamXImageLookup"
end sub

sub runStreamXImageLookup()
    answer = {ok:false,requestId:m.top.requestId,logo:"",background:""}
    imdbId = m.top.imdbId.trim()
    mediaType = LCase(m.top.mediaType)
    if mediaType <> "series" then mediaType = "movie"
    if not CreateObject("roRegex","^tt[0-9]{7,8}$","").isMatch(imdbId)
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if

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