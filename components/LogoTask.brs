' Resolve title logos through Wikimedia Commons, preferring vector artwork.
' SVG thumbnails are rendered by Commons as PNG and normally preserve transparency.
' The player keeps its text title when no suitable logo is found.
sub init()
    m.top.functionName = "runLogoLookup"
end sub

sub runLogoLookup()
    answer = {ok:false, requestId:m.top.requestId, title:m.top.title, url:""}
    title = left(m.top.title,180).trim()
    if title = "" or m.top.cancelRequested then return
    print "[RokuPlus logo] search_start title="; title

    queries = []
    fullQuery = orbitLogoSearchBase(title)
    if fullQuery <> "" then queries.push(fullQuery + " logo")
    mainQuery = orbitLogoMainTitle(title)
    if mainQuery <> "" and mainQuery <> fullQuery then queries.push(mainQuery + " logo")
    if mainQuery <> "" then queries.push(mainQuery + " wordmark")
    if queries.count() = 0 then queries.push(title + " logo")

    encoder = CreateObject("roUrlTransfer")
    files = CreateObject("roFileSystem")
    for each search in queries
        if m.top.cancelRequested then exit for
        endpoint = "https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=" + encoder.escape(search) + "&gsrnamespace=6&gsrlimit=30&prop=imageinfo&iiprop=url%7Cmime%7Csize&iiurlwidth=1200&format=json"
        transfer = CreateObject("roUrlTransfer")
        messages = CreateObject("roMessagePort")
        transfer.setMessagePort(messages)
        transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
        transfer.addHeader("User-Agent", "RokuPlus/1.0 (Wikimedia Commons logo lookup)")
        transfer.setUrl(endpoint)
        filename = "tmp:/rokuplus-logo-" + CreateObject("roDeviceInfo").getRandomUUID() + ".json"
        if not transfer.asyncGetToFile(filename)
            print "[RokuPlus logo] request_start_failed query="; search
            continue for
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
        print "[RokuPlus logo] http query="; search; " finished="; finished; " status="; code; " ms="; elapsed.totalMilliseconds()

        if finished and code = 200 and not m.top.cancelRequested
            body = ReadAsciiFile(filename)
            if GetInterface(body, "ifString") <> invalid and len(body) > 0 and len(body) <= 1048576
                data = ParseJson(body)
                if type(data) = "roAssociativeArray" and type(data.query) = "roAssociativeArray" and type(data.query.pages) = "roAssociativeArray"
                    pages = data.query.pages
                    bestScore = -1
                    bestUrl = ""
                    bestTitle = ""
                    bestMime = ""
                    bestWidth = 0
                    bestHeight = 0
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

                        width = 0
                        height = 0
                        if GetInterface(imageInfo.width,"ifInt") <> invalid then width = imageInfo.width
                        if GetInterface(imageInfo.height,"ifInt") <> invalid then height = imageInfo.height
                        if width <= 0 or height <= 0 then continue for
                        ratio = width / height
                        ' Avoid square icons and portrait artwork: this overlay needs a wordmark.
                        if ratio < 1.15 then continue for
                        if width < 180 then continue for

                        score = 100
                        if mime = "image/svg+xml" then score = score + 1000
                        if ratio >= 1.5 then score = score + 100
                        if ratio >= 2.0 then score = score + 50
                        if width >= 500 then score = score + 20
                        if instr(1,fileTitle,"logo") > 0 then score = score + 10

                        if score > bestScore
                            bestScore = score
                            bestUrl = thumb
                            bestTitle = orbitLogoText(page.title,240)
                            bestMime = mime
                            bestWidth = width
                            bestHeight = height
                        end if
                    end for

                    if bestScore >= 0
                        answer.ok = true
                        answer.url = bestUrl
                        answer.title = bestTitle
                        print "[RokuPlus logo] candidate="; answer.title; " mime="; bestMime; " dimensions="; bestWidth; "x"; bestHeight; " score="; bestScore
                    end if
                end if
            end if
        end if
        files.delete(filename)
        if answer.ok then exit for
    end for

    if not answer.ok then print "[RokuPlus logo] not_found title="; title
    if not m.top.cancelRequested then m.top.result = answer
end sub

function orbitLogoSearchBase(value as string) as string
    result = value.trim()
    yearAt = instr(1,result," (")
    if yearAt > 0 then result = left(result,yearAt-1).trim()
    return result
end function

function orbitLogoMainTitle(value as string) as string
    result = orbitLogoSearchBase(value)
    colonAt = instr(1,result,":")
    if colonAt > 1 then result = left(result,colonAt-1).trim()
    dashAt = instr(1,result," - ")
    if dashAt > 1 then result = left(result,dashAt-1).trim()
    return result
end function

function orbitLogoText(value as dynamic, limit as integer) as string
    if GetInterface(value,"ifString") = invalid then return ""
    return left(value,limit)
end function
