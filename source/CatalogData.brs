' Roku Plus personal library. Original adapters for public service responses.
' No account credentials, provider headers or resolved CDN links are stored here.

function orbitText(value as dynamic, limit = 2400 as integer) as string
    if GetInterface(value, "ifString") = invalid then return ""
    return left(value, limit)
end function

function orbitInteger(value as dynamic, maximum as integer, fallback = 0 as integer) as integer
    if GetInterface(value, "ifString") <> invalid
        if not CreateObject("roRegex", "^[0-9]{1,9}$", "").isMatch(value) then return fallback
        value = value.toInt()
    end if
    isNumber = GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifFloat") <> invalid or GetInterface(value, "ifDouble") <> invalid
    if not isNumber then return fallback
    if value < 0 or value > maximum then return fallback
    return int(value)
end function

function orbitImdb(value as dynamic) as string
    text = orbitText(value, 20)
    if not CreateObject("roRegex", "^tt[0-9]{5,12}$", "").isMatch(text) then return ""
    return text
end function

' Only public DNS names over HTTPS. IP literals and credentials are unnecessary
' for these catalogs and deliberately excluded, including alternate IP syntax.
function orbitHttpsUrl(value as dynamic) as string
    url = orbitText(value, 4097)
    if url = "" or len(url) > 4096 then return ""
    if not CreateObject("roRegex", "^https://[^/?#]+([/?#].*)?$", "i").isMatch(url) then return ""
    if CreateObject("roRegex", "[\x00-\x20\x7F\\|]", "").isMatch(url) then return ""
    match = CreateObject("roRegex", "^https://([^/?#]+)", "i").match(url)
    if match.count() < 2 then return ""
    authority = lcase(match[1])
    if instr(1, authority, "@") > 0 then return ""
    parts = authority.split(":")
    if parts.count() > 2 then return ""
    host = parts[0]
    if parts.count() = 2
        port = orbitInteger(parts[1], 65535)
        if port = 0 then return ""
    end if
    if not CreateObject("roRegex", "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,63}$", "").isMatch(host) then return ""
    for each ending in [".local", ".localhost", ".lan", ".internal", ".home", ".test", ".invalid"]
        if right(host, len(ending)) = ending then return ""
    end for
    if host = "localhost" then return ""
    return url
end function

function orbitRuntime(value as dynamic) as integer
    text = lcase(orbitText(value, 32)).trim()
    match = CreateObject("roRegex", "^([0-9]{1,4})[ ]*(min|minutes|minute)$", "").match(text)
    if match.count() < 2 then return 0
    minutes = orbitInteger(match[1], 1440)
    return minutes * 60
end function

' Public live media may be HTTP. Reuse the same authority/path validation,
' keeping catalog artwork and provider API/resolver URLs HTTPS-only.
function orbitPublicMediaUrl(value as dynamic) as string
    url = orbitText(value, 4097)
    checked = ""
    if lcase(left(url, 7)) = "http://"
        checked = orbitHttpsUrl("https://" + mid(url, 8))
    else
        checked = orbitHttpsUrl(url)
    end if
    if checked <> "" then return url
    if len(url) > 4096 or CreateObject("roRegex", "[\x00-\x20\x7F\\|]", "").isMatch(url) then return ""
    numeric = CreateObject("roRegex", "^https?://([0-9.]+)(:([0-9]{1,5}))?([/?#].*)?$", "i").match(url)
    if numeric.count() < 2 then return ""
    if not orbitPublicIpv4(numeric[1]) then return ""
    if numeric.count() > 3
        if numeric[3] <> "" and orbitInteger(numeric[3], 65535) = 0 then return ""
    end if
    return url
end function

function orbitPublicIpv4(host as string) as boolean
    pieces = host.split(".")
    if pieces.count() <> 4 then return false
    numbers = []
    for each piece in pieces
        value = orbitInteger(piece, 255, -1)
        if value < 0 then return false
        if value.toStr() <> piece then return false
        numbers.push(value)
    end for
    a = numbers[0]
    b = numbers[1]
    c = numbers[2]
    if a = 0 or a = 10 or a = 127 or a >= 224 then return false
    if a = 100 and b >= 64 and b <= 127 then return false
    if a = 169 and b = 254 then return false
    if a = 172 and b >= 16 and b <= 31 then return false
    if a = 192 and b = 168 then return false
    if a = 192 and b = 0 and (c = 0 or c = 2) then return false
    if a = 192 and b = 88 and c = 99 then return false
    if a = 198 and (b = 18 or b = 19) then return false
    if a = 198 and b = 51 and c = 100 then return false
    if a = 203 and b = 0 and c = 113 then return false
    return true
end function

function orbitTitle(raw as dynamic, kind as string) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    if kind <> "movie" and kind <> "series" then return invalid
    id = orbitImdb(raw.id)
    if id = "" then id = orbitImdb(raw.imdb_id)
    title = orbitText(raw.name, 200).trim()
    if id = "" or title = "" then return invalid
    year = orbitText(raw.releaseInfo, 32)
    if year = "" then year = orbitText(raw.year, 32)
    description = orbitText(raw.description)
    return {
        id: id, imdbId: id, title: title, kind: kind
        poster: orbitHttpsUrl(raw.poster), background: orbitHttpsUrl(raw.background)
        description: description, year: year, runtime: orbitRuntime(raw.runtime)
        language: "", seasons: []
    }
end function

function orbitCatalog(raw as dynamic, kind as string, skip as integer) as object
    answer = {items: [], hasMore: false, nextSkip: skip}
    if type(raw) <> "roAssociativeArray" then return answer
    if type(raw.metas) <> "roArray" then return answer
    seen = {}
    take = raw.metas.count()
    if take > 20 then take = 20
    for offset = 0 to take - 1
        item = orbitTitle(raw.metas[offset], kind)
        if item <> invalid
            if not seen.doesExist(item.id)
                seen[item.id] = true
                answer.items.push(item)
            end if
        end if
    end for
    ' The service accepts raw offsets. Advance by source rows, not filtered rows.
    answer.nextSkip = skip + take
    answer.hasMore = raw.metas.count() >= 20 and take > 0
    return answer
end function

function orbitMetadata(raw as dynamic, kind as string, expectedId as string) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    item = orbitTitle(raw.meta, kind)
    if item = invalid then return invalid
    if item.id <> expectedId then return invalid
    if kind <> "series" then return item
    if type(raw.meta.videos) <> "roArray" then return item
    seasonMap = {}
    seen = {}
    inspected = 0
    for each video in raw.meta.videos
        inspected++
        if inspected > 5000 then exit for
        if type(video) = "roAssociativeArray"
            seasonNumber = orbitInteger(video.season, 999, -1)
            episodeNumber = orbitInteger(video.episode, 9999, -1)
            if episodeNumber < 1 then episodeNumber = orbitInteger(video.number, 9999, -1)
            if seasonNumber >= 0 and episodeNumber > 0
                episodeId = item.id + ":" + seasonNumber.toStr() + ":" + episodeNumber.toStr()
                if not seen.doesExist(episodeId)
                    title = orbitText(video.name, 200).trim()
                    if title = "" then title = "Episodio " + episodeNumber.toStr()
                    description = orbitText(video.description)
                    if description = "" then description = orbitText(video.overview)
                    poster = orbitHttpsUrl(video.thumbnail)
                    if poster = "" then poster = item.poster
                    episode = {
                        id: episodeId, imdbId: item.id, title: title, kind: "episode"
                        seriesTitle: item.title, season: seasonNumber, episode: episodeNumber
                        poster: poster, background: item.background, description: description
                        year: item.year, runtime: orbitRuntime(video.runtime), language: "", seasons: []
                    }
                    key = seasonNumber.toStr()
                    if not seasonMap.doesExist(key) then seasonMap[key] = {number: seasonNumber, episodes: []}
                    season = seasonMap[key]
                    if season.episodes.count() < 100
                        season.episodes.push(episode)
                        seen[episodeId] = true
                    end if
                end if
            end if
        end if
    end for
    ' Numeric insertion order avoids lexicographic season 1,10,2 ordering.
    for each key in seasonMap
        season = seasonMap[key]
        sortedEpisodes = season.episodes
        for i = 1 to sortedEpisodes.count() - 1
            position = i
            while position > 0
                if sortedEpisodes[position - 1].episode <= sortedEpisodes[position].episode then exit while
                swap = sortedEpisodes[position - 1]
                sortedEpisodes[position - 1] = sortedEpisodes[position]
                sortedEpisodes[position] = swap
                position--
            end while
        end for
        season.episodes = sortedEpisodes
        item.seasons.push(season)
        position = item.seasons.count() - 1
        while position > 0
            if item.seasons[position - 1].number <= item.seasons[position].number then exit while
            swap = item.seasons[position - 1]
            item.seasons[position - 1] = item.seasons[position]
            item.seasons[position] = swap
            position--
        end while
        if item.seasons.count() > 50 then item.seasons.pop()
    end for
    return item
end function

function orbitResolvedStream(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    if type(raw.streams) <> "roArray" then return invalid
    for each stream in raw.streams
        if type(stream) = "roAssociativeArray"
            url = orbitHttpsUrl(stream.url)
            prefix = "https://mg.homelabx.qzz.io/resolve/"
            allowed = left(url, len(prefix)) = prefix and len(url) > len(prefix)
            headersRequired = false
            if stream.headers <> invalid then headersRequired = true
            if type(stream.behaviorHints) = "roAssociativeArray"
                if stream.behaviorHints.proxyHeaders <> invalid then headersRequired = true
            end if
            if allowed and not headersRequired
                return {url: url, streamFormat: "ts", description: orbitText(stream.description, 500), seekSupport: "unknown", userAgent: "", headers: {}}
            end if
        end if
    end for
    return invalid
end function

function orbitM3uAttribute(line as string, key as string) as string
    quote = chr(34)
    capture = CreateObject("roRegex", key + "=" + quote + "([^" + quote + "]*)" + quote, "i").match(line)
    if capture.count() < 2 then return ""
    return left(capture[1], 400)
end function

function orbitM3uName(line as string) as string
    quoted = false
    for position = 1 to len(line)
        letter = mid(line, position, 1)
        if letter = chr(34) then quoted = not quoted
        if letter = "," and not quoted then return left(mid(line, position + 1).trim(), 200)
    end for
    return ""
end function

function orbitLiveFormat(url as string) as string
    if CreateObject("roRegex", "\.m3u8([?#]|$)", "i").isMatch(url) then return "hls"
    if CreateObject("roRegex", "\.ts([?#]|$)", "i").isMatch(url) then return "ts"
    if CreateObject("roRegex", "\.mp4([?#]|$)", "i").isMatch(url) then return "mp4"
    if CreateObject("roRegex", "\.mpd([?#]|$)", "i").isMatch(url) then return ""
    ' A live M3U can point at a PHP/extensionless manifest. Let the native
    ' player inspect it as HLS instead of hiding it based on the path alone.
    return "hls"
end function

sub orbitLiveOption(item as object, option as string, value as string)
    option = lcase(option.trim())
    if option = "http-referrer" or option = "http-referer"
        referer = orbitPublicMediaUrl(value.trim())
        if referer = "" then item.blocked = true else item.mediaHeaders["Referer"] = referer
    else if option = "http-user-agent"
        value = left(value.trim(), 400)
        if value = "" or CreateObject("roRegex", "[\x00-\x1F\x7F]", "").isMatch(value)
            item.blocked = true
        else
            item.mediaHeaders["User-Agent"] = value
        end if
    else
        ' Cookies, auth, DRM and arbitrary provider options are not forwarded.
        item.blocked = true
    end if
end sub

function orbitMexicoPlaylist(body as string) as object
    ' Legacy name stays available for existing settings and model consumers.
    return orbitCountryChannels(body, "mx")
end function

function orbitCountryChannels(body as string, countryCode as string) as object
    ' The Task authorizes country codes before downloading. Parsing itself
    ' never constructs a network destination and retains all media options.
    channels = []
    channelLimit = 600
    if countryCode = "latam" then channelLimit = 3200
    if len(body) > 2097152 then return channels
    pending = invalid
    seen = {}
    lines = body.replace(chr(13), "").split(chr(10))
    for each rawLine in lines
        line = rawLine.trim()
        if left(line, 8) = "#EXTINF:"
            pending = {
                id: orbitM3uAttribute(line, "tvg-id"), title: orbitM3uName(line)
                poster: orbitHttpsUrl(orbitM3uAttribute(line, "tvg-logo"))
                group: orbitM3uAttribute(line, "group-title"), requiresHeaders: false
                mediaHeaders: {}, blocked: false
            }
            referer = orbitM3uAttribute(line, "http-referrer")
            if referer <> "" then orbitLiveOption(pending, "http-referrer", referer)
            userAgent = orbitM3uAttribute(line, "http-user-agent")
            if userAgent <> "" then orbitLiveOption(pending, "http-user-agent", userAgent)
        else if pending <> invalid and left(line, 1) = "#"
            if left(lcase(line), 11) = "#extvlcopt:"
                optionLine = mid(line, 12)
                equal = instr(1, optionLine, "=")
                if equal > 0 then orbitLiveOption(pending, left(optionLine, equal - 1), mid(optionLine, equal + 1))
            else if left(lcase(line), 9) = "#kodiprop"
                pending.blocked = true
            end if
        else if pending <> invalid and line <> ""
            url = orbitPublicMediaUrl(line)
            format = orbitLiveFormat(url)
            if url <> "" and format <> "" and not pending.blocked
                if pending.title <> "" and not seen.doesExist(url)
                    pending.favoriteIdStable = true
                    if pending.id = ""
                        pending.id = countryCode + "-" + channels.count().toStr()
                        pending.favoriteIdStable = false
                    end if
                    pending.id = "live:" + pending.id
                    pending.kind = "live"
                    pending.countryCode = countryCode
                    if countryCode = "latam"
                        origin = CreateObject("roRegex", "\.([a-z]{2})(@|$)", "i").match(pending.id)
                        pending.countryCode = "xx"
                        if origin.count() > 1 then pending.countryCode = lcase(origin[1])
                    end if
                    pending.url = url
                    pending.streamFormat = format
                    pending.formatInferred = not CreateObject("roRegex", "\.(m3u8|ts|mp4)([?#]|$)", "i").isMatch(url)
                    pending.background = ""
                    pending.description = "Canal en vivo"
                    pending.year = ""
                    pending.runtime = 0
                    pending.language = ""
                    pending.seasons = []
                    pending.live = true
                    pending.seekSupport = "unknown"
                    pending.userAgent = ""
                    pending.headers = {}
                    pending.requiresHeaders = pending.mediaHeaders.count() > 0
                    pending.delete("blocked")
                    channels.push(pending)
                    seen[url] = true
                    if channels.count() >= channelLimit then exit for
                end if
            end if
            pending = invalid
        end if
    end for
    return channels
end function

' Remove duplicate movie/series cards even when providers assign different IDs.
' Episode identities are left untouched because season/episode are meaningful.
function orbitUniqueCatalogItems(items as dynamic) as object
    result = []
    seen = {}
    if type(items) <> "roArray" then return result
    for each item in items
        if type(item) = "roAssociativeArray"
            id = orbitText(item.id,180)
            kind = orbitText(item.kind,20)
            title = orbitText(item.title,200).trim()
            year = orbitText(item.year,12).trim()
            key = id
            if kind = "series" and title <> ""
                ' Providers inconsistently include the release year in the title.
                ' Normalize "Example (2020)" and "Example" to one series identity.
                yearMatch = CreateObject("roRegex","\\s*\\(((19|20)[0-9]{2})\\)\\s*$","").match(title)
                if yearMatch.count() > 2
                    if year = "" then year = yearMatch[1]
                    title = CreateObject("roRegex","\\s*\\(((19|20)[0-9]{2})\\)\\s*$","").replace(title,"").trim()
                end if
                item.title = title
                if orbitText(item.year,12).trim() = "" and year <> "" then item.year = year
                key = "series|"+lcase(title)
            else if kind = "movie" and title <> ""
                ' Movie providers also disagree about whether the year is part of
                ' the title. Normalize "Example (2020)" before comparing cards.
                yearMatch = CreateObject("roRegex","\\s*\\(((19|20)[0-9]{2})\\)\\s*$","").match(title)
                if yearMatch.count() > 2
                    if year = "" then year = yearMatch[1]
                    title = CreateObject("roRegex","\\s*\\(((19|20)[0-9]{2})\\)\\s*$","").replace(title,"").trim()
                end if
                item.title = title
                if orbitText(item.year,12).trim() = "" and year <> "" then item.year = year
                key = "movie|"+lcase(title)+"|"+year
            end if
            duplicateIndex = -1
            if kind = "movie" and title <> ""
                ' Merge same-title movie records when years match or one source
                ' omits the year. Keep genuine remakes with different years.
                for existingIndex = 0 to result.count()-1
                    existing = result[existingIndex]
                    if orbitText(existing.kind,20) = "movie"
                        existingTitle = orbitText(existing.title,200).trim()
                        if lcase(existingTitle) = lcase(title)
                            existingYear = orbitText(existing.year,12).trim()
                            if existingYear = "" or year = "" or existingYear = year
                                duplicateIndex = existingIndex
                                exit for
                            end if
                        end if
                    end if
                end for
            end if
            if duplicateIndex >= 0
                existing = result[duplicateIndex]
                if orbitText(existing.year,12).trim() = "" and year <> "" then existing.year = year
                if orbitText(existing.poster,2048) = "" and orbitText(item.poster,2048) <> "" then existing.poster = item.poster
                if orbitText(existing.background,2048) = "" and orbitText(item.background,2048) <> "" then existing.background = item.background
                if orbitText(existing.description,2400) = "" and orbitText(item.description,2400) <> "" then existing.description = item.description
            else if key <> "" and not seen.doesExist(key)
                seen[key] = result.count()
                result.push(item)
            else if key <> "" and seen.doesExist(key) and kind = "series"
                ' Keep useful metadata from whichever provider supplied it.
                existingIndex = seen[key]
                existing = result[existingIndex]
                if orbitText(existing.year,12).trim() = "" and year <> "" then existing.year = year
                if orbitText(existing.poster,2048) = "" and orbitText(item.poster,2048) <> "" then existing.poster = item.poster
                if orbitText(existing.background,2048) = "" and orbitText(item.background,2048) <> "" then existing.background = item.background
                if orbitText(existing.description,2400) = "" and orbitText(item.description,2400) <> "" then existing.description = item.description
            end if
        end if
    end for
    return result
end function
