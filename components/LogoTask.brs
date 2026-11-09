' Resolve transparent title logos through the public Wikimedia Commons API.
' A logo is optional: the player keeps its text title when no trustworthy logo is found.
sub init()
    m.top.functionName = "runLogoLookup"
end sub

sub runLogoLookup()
    answer = {ok:false, requestId:m.top.requestId, title:m.top.title, url:""}
    title = left(m.top.title,180).trim()
    if title = "" or m.top.cancelRequested then return
    print "[RokuPlus logo] search_start title="; title
    encoder = CreateObject("roUrlTransfer")
    search = chr(34) + title + chr(34) + " logo"
    endpoint = "https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=" + encoder.escape(search) + "&gsrnamespace=6&gsrlimit=12&prop=imageinfo&iiprop=url%7Cmime&iiurlwidth=1400&format=json"
    transfer = CreateObject("roUrlTransfer")
    messages = CreateObject("roMessagePort")
    transfer.setMessagePort(messages)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.addHeader("User-Agent", "RokuPlus/1.0 (Wikimedia Commons logo lookup)")
    transfer.setUrl(endpoint)
    files = CreateObject("roFileSystem")
    filename = "tmp:/rokuplus-logo-" + CreateObject("roDeviceInfo").getRandomUUID() + ".json"
    if not transfer.asyncGetToFile(filename)
        print "[RokuPlus logo] request_start_failed"
        if not m.top.cancelRequested then m.top.result = answer
        return
    end if
    elapsed = CreateObject("roTimespan")
    elapsed.mark()
    finished = false
    code = 0
    while not finished
        if m.top.cancelRequested then exit while
        if elapsed.totalMilliseconds() >= 9000 then exit while
        event = wait(50,messages)
        if type(event) = "roUrlEvent"
            if event.getSourceIdentity() = transfer.getIdentity() and event.getInt() = 1
                code = event.getResponseCode()
                finished = true
            end if
        end if
    end while
    if not finished then transfer.asyncCancel()
    print "[RokuPlus logo] http finished="; finished; " status="; code; " ms="; elapsed.totalMilliseconds()
    if finished and code = 200 and not m.top.cancelRequested
        ' ReadAsciiFile returns the JSON text directly. roFileSystem.stat returns
        ' an roFileInfo object, not an associative array with a size field.
        body = ReadAsciiFile(filename)
        if GetInterface(body, "ifString") <> invalid and len(body) > 0 and len(body) <= 1048576
            data = ParseJson(body)
            if type(data) = "roAssociativeArray" and type(data.query) = "roAssociativeArray" and type(data.query.pages) = "roAssociativeArray"
                pages = data.query.pages
                for each pageId in pages
                    page = pages[pageId]
                    if type(page) <> "roAssociativeArray" then continue for
                    fileTitle = lcase(orbitLogoText(page.title,240))
                    if instr(1,fileTitle,"logo") = 0 and instr(1,fileTitle,"wordmark") = 0 then continue for
                    if type(page.imageinfo) <> "roArray" or page.imageinfo.count() = 0 then continue for
                    imageInfo = page.imageinfo[0]
                    if type(imageInfo) <> "roAssociativeArray" then continue for
                    mime = lcase(orbitLogoText(imageInfo.mime,80))
                    if mime <> "image/png" and mime <> "image/svg+xml" then continue for
                    thumb = orbitLogoText(imageInfo.thumburl,2048)
                    if left(thumb,29) <> "https://upload.wikimedia.org/" then continue for
                    answer.ok = true
                    answer.url = thumb
                    answer.title = orbitLogoText(page.title,240)
                    print "[RokuPlus logo] candidate="; answer.title; " mime="; mime
                    exit for
                end for
            end if
        end if
    end if
    files.delete(filename)
    if not answer.ok then print "[RokuPlus logo] not_found title="; title
    if not m.top.cancelRequested then m.top.result = answer
end sub

function orbitLogoText(value as dynamic, limit as integer) as string
    if GetInterface(value,"ifString") = invalid then return ""
    return left(value,limit)
end function
