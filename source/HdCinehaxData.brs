' CineHax public JSON normalization. No network, browser, script evaluation or URL persistence.

' Treat source identifiers as opaque decimal strings. A Float conversion can
' round the site's newer eight-digit IDs and make distinct catalog cards collide.
function rpHdCinehaxId(value as dynamic) as string
    text = ""
    if GetInterface(value,"ifString") <> invalid
        text = value
    else
        numeric = GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid
        if not numeric then return ""
        if value < 1 or value > 16777215 or value <> int(value) then return ""
        text = FormatJson(value)
    end if
    if not CreateObject("roRegex","^[1-9][0-9]{0,8}$","").isMatch(text) then return ""
    return text
end function

' Quote only integer identifier members before ParseJson. Existing quoted IDs,
' normal numbers and JSON string contents remain unchanged. No script evaluation.
function rpHdCinehaxJsonText(raw as dynamic) as string
    text = orbitText(raw,2097153)
    if len(text) > 2097152 then return ""
    quote = chr(34)
    pattern = "([,{]\s*"+quote+"(?:catalog_item_id|item_id|tmdb_id)"+quote+"\s*:\s*)([1-9][0-9]{0,8})(?=\s*[,}])"
    regex = CreateObject("roRegex",pattern,"")
    result = ""
    start = 1
    for guard = 1 to 6000
        remaining = mid(text,start)
        found = regex.match(remaining)
        if found.count() < 3 then return result+remaining
        at = instr(1,remaining,found[0])
        if at < 1 then return ""
        result += left(remaining,at-1)+found[1]+quote+found[2]+quote
        start += at-1+len(found[0])
    end for
    return ""
end function

function rpHdCinehaxEndpoint(operation as string, args as dynamic) as string
    if type(args) <> "roAssociativeArray" then return ""
    base = "https://cinehax.org/api/rest/v1/"
    kind = orbitText(args.kind,16)
    sourceKind = orbitText(args.sourceKind,16)
    if kind = "movie" then sourceKind = "movie"
    if kind = "series" and sourceKind = "" then sourceKind = "serie"
    if sourceKind <> "movie" and sourceKind <> "serie" and sourceKind <> "anime" and sourceKind <> "novel" then return ""
    page = orbitInteger(args.page,10000,1)
    if page < 1 then page = 1
    if operation = "catalog" then return base+"listing?kind="+sourceKind+"&order=recent&limit=20&page="+page.toStr()
    if operation = "search"
        query = rpHdOnlineEscape(args.query)
        if query = "" then return ""
        return base+"search?q="+query+"&limit=20&page="+page.toStr()
    end if
    if operation = "meta"
        slug = orbitText(args.slug,200)
        if not CreateObject("roRegex","^[a-z0-9áéíóúüñàèìòùâêîôûãõçªº-]{1,200}$","").isMatch(slug) then return ""
        return base+"content/"+sourceKind+"/"+rpHdOnlineEscape(slug)
    end if
    id = rpHdCinehaxId(args.id)
    if id = "" then return ""
    if operation = "seasons" then return base+"episode-seasons?item_id="+id
    if operation = "episodes"
        season = orbitInteger(args.season,999,-1)
        if season < 0 then return ""
        return base+"episodes?item_id="+id+"&season="+season.toStr()+"&limit=60&page="+page.toStr()
    end if
    return ""
end function

function rpHdCinehaxArt(value as dynamic, backdrop = false as boolean) as string
    path = orbitText(value,240)
    if not CreateObject("roRegex","^/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$","").isMatch(path) then return ""
    size = "w500"
    if backdrop then size = "w1280"
    return "https://image.tmdb.org/t/p/"+size+path
end function

function rpHdCinehaxItem(raw as dynamic, kind as string) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    sourceKind = orbitText(raw.kind,16)
    if kind = "movie"
        if sourceKind <> "movie" then return invalid
    else if kind = "series"
        if sourceKind <> "serie" and sourceKind <> "anime" and sourceKind <> "novel" then return invalid
    else
        return invalid
    end if
    id = rpHdCinehaxId(raw.catalog_item_id)
    tmdb = rpHdCinehaxId(raw.tmdb_id)
    title = orbitText(raw.title,200).trim()
    slug = orbitText(raw.slug,200)
    if id = "" or tmdb = "" or title = "" then return invalid
    if not CreateObject("roRegex","^[a-z0-9áéíóúüñàèìòùâêîôûãõçªº-]{1,200}$","").isMatch(slug) then return invalid
    year = orbitInteger(raw.year,2199)
    yearText = ""
    if year >= 1880 then yearText = year.toStr()
    return {
        id:"hdo-cinehax-"+id, imdbId:orbitImdb(raw.imdb_id), kind:kind
        provider:"cinehax", providerId:id, providerTmdbId:tmdb, providerKind:sourceKind, providerSlug:slug
        library:"hd-online", title:title, description:orbitText(raw.overview)
        poster:rpHdCinehaxArt(raw.poster_path), background:rpHdCinehaxArt(raw.backdrop_path,true)
        year:yearText, runtime:orbitInteger(raw.runtime,1440)*60, language:"", seasons:[]
    }
end function

function rpHdCinehaxCatalog(raw as dynamic, kind as string, page as integer) as object
    answer = {items:[],hasMore:false,nextPage:page+1,total:0}
    if type(raw) <> "roAssociativeArray" then return answer
    if type(raw.items) <> "roArray" then return answer
    seen = {}
    take = raw.items.count()
    if take > 200 then take = 200
    for i = 0 to take-1
        item = rpHdCinehaxItem(raw.items[i],kind)
        if item <> invalid
            if not seen.doesExist(item.id)
                answer.items.push(item)
                seen[item.id] = true
            end if
        end if
    end for
    pagination = raw.pagination
    if type(pagination) = "roAssociativeArray"
        answer.total = orbitInteger(pagination.total,1000000)
        current = orbitInteger(pagination.page,10000,page)
        if current < page then current = page
        answer.nextPage = current+1
        if GetInterface(pagination.has_next,"ifBoolean") <> invalid then answer.hasMore = pagination.has_next
    else
        answer.hasMore = take >= 20
    end if
    return answer
end function

function rpHdCinehaxMetadata(raw as dynamic, expected as object) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    item = rpHdCinehaxItem(raw.item,expected.kind)
    if item = invalid then return invalid
    if item.id <> expected.id or item.providerKind <> expected.providerKind then return invalid
    if item.providerSlug <> expected.providerSlug then return invalid
    if item.description = "" then item.description = orbitText(raw.overview)
    item.seasonNumbers = rpHdCinehaxSeasonNumbers(raw.episode_seasons)
    return item
end function

function rpHdCinehaxSeasonNumbers(raw as dynamic) as object
    result = []
    if type(raw) <> "roArray" then return result
    seen = {}
    count = 0
    for each season in raw
        count++
        if count > 1000 then exit for
        if type(season) = "roAssociativeArray"
            number = orbitInteger(season.season,999,-1)
            if number >= 0
                key = number.toStr()
                if not seen.doesExist(key)
                    result.push(number)
                    seen[key] = true
                end if
            end if
        end if
    end for
    result.sort()
    return result
end function

function rpHdCinehaxEpisodes(raw as dynamic, parent as object, requested as integer, page as integer) as object
    answer = {ok:false,seasons:[],seasonNumbers:[],hasMore:false,nextPage:page+1}
    if type(raw) <> "roAssociativeArray" then return answer
    if rpHdCinehaxId(raw.item_id) <> parent.providerId then return answer
    if orbitInteger(raw.season,999,-1) <> requested then return answer
    if type(raw.episodes) <> "roArray" then return answer
    entries = []
    seen = {}
    take = raw.episodes.count()
    if take > 200 then take = 200
    for i = 0 to take-1
        row = raw.episodes[i]
        if type(row) = "roAssociativeArray"
            season = orbitInteger(row.season,999,-1)
            number = orbitInteger(row.episode,9999)
            playable = false
            if GetInterface(row.playable,"ifBoolean") <> invalid then playable = row.playable
            if season = requested and number > 0 and playable
                id = "hdo-cinehax-"+parent.providerId+"-s"+season.toStr()+"-e"+number.toStr()
                if not seen.doesExist(id)
                    title = orbitText(row.title,200)
                    if title = "" then title = "Episodio "+number.toStr()
                    item = {
                        id:id, imdbId:"", kind:"episode", library:"hd-online",provider:"cinehax"
                        providerId:parent.providerId,providerTmdbId:parent.providerTmdbId,providerKind:parent.providerKind,providerSlug:parent.providerSlug
                        title:title,seriesTitle:parent.title,season:season,episode:number
                        poster:parent.poster,background:rpHdCinehaxArt(row.still_path,true)
                        description:orbitText(row.overview),year:parent.year,runtime:orbitInteger(row.runtime,1440)*60,language:"",seasons:[]
                    }
                    if item.background = "" then item.background = parent.background
                    if item.description = "" then item.description = parent.description
                    entries.push(item)
                    seen[id] = true
                end if
            end if
        end if
    end for
    entries.sortBy("episode")
    answer.seasons.push({number:requested,episodes:entries,loaded:true})
    answer.seasonNumbers.push(requested)
    pagination = raw.pagination
    if type(pagination) = "roAssociativeArray"
        current = orbitInteger(pagination.page,10000,page)
        if current < page then current = page
        answer.nextPage = current+1
        if GetInterface(pagination.has_next,"ifBoolean") <> invalid then answer.hasMore = pagination.has_next
    else
        answer.hasMore = take >= 60
    end if
    answer.ok = true
    return answer
end function

function rpHdCinehaxPlayer(item as object) as string
    tmdb = rpHdCinehaxId(item.providerTmdbId)
    if tmdb = "" then return ""
    if item.kind = "movie" then return "https://videoapp.mov/e/movie/"+tmdb
    if item.kind <> "episode" then return ""
    season = orbitInteger(item.season,999,-1)
    episode = orbitInteger(item.episode,9999)
    if season < 0 or episode < 1 then return ""
    return "https://videoapp.mov/e/tv/"+tmdb+"/"+season.toStr()+"/"+episode.toStr()
end function

function rpHdCinehaxIframe(raw as dynamic) as string
    text = orbitText(raw,2097153)
    if len(text) > 2097152 then return ""
    quotes = chr(34)+"'"
    pattern = "<iframe[^>]+src\s*=\s*["+quotes+"](https://vimeos\.net/embed-[a-zA-Z0-9_-]+(?:\.html)?(?:\?[^"+quotes+"<>#\s\\]{1,1600})?)["+quotes+"]"
    match = CreateObject("roRegex",pattern,"i").match(text)
    if match.count() < 2 then return ""
    return match[1].replace("&amp;","&").replace("&#38;","&")
end function

