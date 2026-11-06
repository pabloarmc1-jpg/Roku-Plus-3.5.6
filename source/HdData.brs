' Static HD catalog only. Import CatalogData.brs in the same component/scope:
' orbitText, orbitInteger and orbitHttpsUrl provide shared primitive validation.
' No network, provider resolution, registry, player or SceneGraph operations.

function rpHdLibrary() as object
    return rpHdLibraryFromText(ReadAsciiFile("pkg:/data/hd-library.json"))
end function

function rpHdLibraryFromText(body as dynamic) as object
    empty = {movies: [], series: []}
    if GetInterface(body, "ifString") = invalid then return empty
    if len(body) = 0 or len(body) > 262144 then return empty
    body = body.trim()
    if left(body, 1) <> "{" or right(body, 1) <> "}" then return empty
    return rpHdNormalize(ParseJson(body))
end function

function rpHdId(value as dynamic) as string
    id = orbitText(value, 97)
    if len(id) > 96 then return ""
    if not CreateObject("roRegex", "^hd-[a-z0-9][a-z0-9-]*$", "").isMatch(id) then return ""
    return id
end function

' Exact authorities and fixed public path families, no ports, query, fragment,
' percent escapes, credentials or alternate hosts. Artwork cannot be a stream.
function rpHdUrl(value as dynamic, role = "media" as string) as string
    url = orbitHttpsUrl(value)
    if url = "" then return ""
    pattern = ""
    if role = "media"
        pattern = "^https://(studio\.blender\.org/download-source/files/[a-z0-9/_-]+\.mp4|images-assets\.nasa\.gov/video/[a-z0-9_-]+/[a-z0-9_~-]+\.mp4)$"
    else if role = "art"
        pattern = "^https://(studio\.blender\.org/files/public/thumbnail/[a-z0-9/_-]+\.(webp|png|jpg|jpeg)|images-assets\.nasa\.gov/video/[a-z0-9_-]+/[a-z0-9_~-]+\.(jpg|jpeg|png))$"
    else if role = "reference"
        pattern = "^https://(studio\.blender\.org/projects/[a-z0-9-]+/|images\.nasa\.gov/details/[a-z0-9_-]+)$"
    else
        return ""
    end if
    if not CreateObject("roRegex", pattern, "i").isMatch(url) then return ""
    return url
end function

function rpHdNumber(value as dynamic, maximum as integer, fallback = -1 as integer) as integer
    ' Shared integer helper handles type/range checks; guard nonfinite numbers
    ' first because static parser fixtures may be supplied directly by tests.
    numeric = GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifFloat") <> invalid or GetInterface(value, "ifDouble") <> invalid
    if numeric
        if value <> value then return fallback
    end if
    return orbitInteger(value, maximum, fallback)
end function

function rpHdMedia(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    if orbitText(raw.container, 8) <> "mp4" then return invalid
    if orbitText(raw.videoCodec, 8) <> "h264" then return invalid
    if orbitText(raw.videoSampleEntry, 8) <> "avc1" then return invalid
    if orbitText(raw.audioCodec, 8) <> "aac" then return invalid
    if orbitText(raw.audioProfile, 8) <> "LC" then return invalid
    if rpHdNumber(raw.audioObjectType, 63) <> 2 then return invalid
    width = rpHdNumber(raw.width, 1920)
    height = rpHdNumber(raw.height, 1080)
    channels = rpHdNumber(raw.audioChannels, 2)
    rate = rpHdNumber(raw.audioSampleRate, 96000)
    profileId = rpHdNumber(raw.profileIdc, 100)
    levelId = rpHdNumber(raw.levelIdc, 42)
    if width < 16 or height < 16 or channels < 1 or rate < 8000 then return invalid
    profile = orbitText(raw.profile, 16)
    validProfile = (profile = "Baseline" and profileId = 66) or (profile = "Main" and profileId = 77) or (profile = "High" and profileId = 100)
    if not validProfile then return invalid
    if levelId < 10 then return invalid
    level = (levelId \ 10).toStr() + "." + (levelId mod 10).toStr()
    if orbitText(raw.level, 8) <> level then return invalid
    if GetInterface(raw.verifiedFromHeader, "ifBoolean") = invalid then return invalid
    if raw.verifiedFromHeader <> true then return invalid
    tested = false
    if GetInterface(raw.playbackTested, "ifBoolean") <> invalid then tested = raw.playbackTested
    result = {
        container: "mp4", videoCodec: "h264", videoSampleEntry: "avc1"
        profile: profile, profileIdc: profileId, level: level, levelIdc: levelId
        width: width, height: height, audioCodec: "aac", audioProfile: "LC"
        audioObjectType: 2, audioChannels: channels, audioSampleRate: rate
        verifiedFromHeader: true, playbackTested: tested
    }
    if GetInterface(raw.ffmpegFirstFrameDecoded, "ifBoolean") <> invalid then result.ffmpegFirstFrameDecoded = raw.ffmpegFirstFrameDecoded
    return result
end function

function rpHdEntry(raw as dynamic, expectedKind as string) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    if orbitText(raw.kind, 12) <> expectedKind then return invalid
    id = rpHdId(raw.id)
    title = orbitText(raw.title, 200).trim()
    source = orbitText(raw.source, 240).trim()
    license = orbitText(raw.license, 1200).trim()
    if id = "" or title = "" or source = "" or license = "" then return invalid
    result = {
        id: id, imdbId: "", title: title, kind: expectedKind
        poster: rpHdUrl(raw.poster, "art"), background: rpHdUrl(raw.background, "art")
        description: orbitText(raw.description, 2400), year: orbitText(raw.year, 32)
        runtime: 0, language: orbitText(raw.language, 40), source: source, license: license
        sourcePage: rpHdUrl(raw.sourcePage, "reference"), seasons: []
    }
    if result.background = "" then result.background = result.poster
    if expectedKind <> "series"
        result.directUrl = rpHdUrl(raw.directUrl)
        result.streamFormat = "mp4"
        result.runtime = rpHdNumber(raw.runtime, 86400)
        result.media = rpHdMedia(raw.media)
        if result.directUrl = "" or result.runtime < 1 or result.media = invalid then return invalid
        if orbitText(raw.streamFormat, 8) <> "mp4" then return invalid
    end if
    return result
end function

function rpHdNormalize(raw as dynamic) as object
    result = {movies: [], series: []}
    if type(raw) <> "roAssociativeArray" then return result
    if GetInterface(raw.version, "ifInt") = invalid then return result
    if raw.version <> 1 then return result
    if type(raw.movies) <> "roArray" or type(raw.series) <> "roArray" then return result
    seen = {}
    take = raw.movies.count()
    if take > 64 then take = 64
    for i = 0 to take - 1
        movie = rpHdEntry(raw.movies[i], "movie")
        if movie <> invalid
            if not seen.doesExist(movie.id)
                result.movies.push(movie)
                seen[movie.id] = true
            end if
        end if
    end for
    take = raw.series.count()
    if take > 16 then take = 16
    for i = 0 to take - 1
        series = rpHdEntry(raw.series[i], "series")
        sourceSeries = raw.series[i]
        if series <> invalid
            if not seen.doesExist(series.id) and type(sourceSeries.seasons) = "roArray"
                seen[series.id] = true
                seasonSeen = {}
                seasonTake = sourceSeries.seasons.count()
                if seasonTake > 12 then seasonTake = 12
                for s = 0 to seasonTake - 1
                    sourceSeason = sourceSeries.seasons[s]
                    if type(sourceSeason) = "roAssociativeArray"
                        number = rpHdNumber(sourceSeason.number, 999)
                        key = number.toStr()
                        if number >= 0 and not seasonSeen.doesExist(key) and type(sourceSeason.episodes) = "roArray"
                            season = {number: number, episodes: []}
                            episodeSeen = {}
                            episodeTake = sourceSeason.episodes.count()
                            if episodeTake > 100 then episodeTake = 100
                            for e = 0 to episodeTake - 1
                                sourceEpisode = sourceSeason.episodes[e]
                                episode = rpHdEntry(sourceEpisode, "episode")
                                if episode <> invalid
                                    episodeNumber = rpHdNumber(sourceEpisode.episode, 9999)
                                    episodeSeason = rpHdNumber(sourceEpisode.season, 999)
                                    episodeKey = episodeNumber.toStr()
                                    if episodeSeason = number and episodeNumber > 0 and not seen.doesExist(episode.id) and not episodeSeen.doesExist(episodeKey)
                                        episode.seriesTitle = series.title
                                        episode.season = number
                                        episode.episode = episodeNumber
                                        season.episodes.push(episode)
                                        seen[episode.id] = true
                                        episodeSeen[episodeKey] = true
                                    end if
                                end if
                            end for
                            if season.episodes.count() > 0 then series.seasons.push(season)
                            seasonSeen[key] = true
                        end if
                    end if
                end for
                if series.seasons.count() > 0 then result.series.push(series)
            end if
        end if
    end for
    return result
end function

function rpHdCatalog(kind as dynamic, query = "" as dynamic) as object
    return rpHdCatalogItems(rpHdLibrary(), kind, query)
end function

function rpHdCatalogItems(library as object, kind as dynamic, query = "" as dynamic) as object
    ' Pure variant: library is the result of rpHdLibrary/rpHdNormalize.
    items = []
    if GetInterface(kind, "ifString") = invalid then return items
    if kind = "movie"
        items = library.movies
    else if kind = "series"
        items = library.series
    else
        return items
    end if
    query = lcase(orbitText(query, 120).trim())
    result = []
    for each item in items
        haystack = lcase(item.title + " " + item.description)
        if query = "" or instr(1, haystack, query) > 0 then result.push(item)
    end for
    return result
end function

function rpHdItem(id as dynamic) as dynamic
    return rpHdFindItem(rpHdLibrary(), id)
end function

function rpHdFindItem(library as object, value as dynamic) as dynamic
    ' Pure variant: library is the result of rpHdLibrary/rpHdNormalize.
    id = rpHdId(value)
    if id = "" then return invalid
    for each item in library.movies
        if item.id = id then return item
    end for
    for each series in library.series
        if series.id = id then return series
        for each season in series.seasons
            for each episode in season.episodes
                if episode.id = id then return episode
            end for
        end for
    end for
    return invalid
end function
