' SeriesMetro SSR parser. Treat HTML/Packer as text; never execute site scripts.
function rpHdSeriesmetroEndpoint(operation as string, args as object) as string
    base = "https://www3.seriesmetro.net"
    page = orbitInteger(args.page,10000,1)
    if page < 1 then page = 1
    if operation = "catalog"
        route = "/cartelera-peliculas/"
        if args.kind = "series" then route = "/cartelera-series/"
        if args.kind <> "movie" and args.kind <> "series" then return ""
        if page > 1 then route += "page/"+page.toStr()+"/"
        return base+route
    else if operation = "search"
        query = rpHdOnlineEscape(args.query)
        if query = "" then return ""
        route = "/"
        if page > 1 then route += "page/"+page.toStr()+"/"
        return base+route+"?s="+query
    else if operation = "meta" or operation = "player"
        path = rpHdSeriesmetroPath(args.slug)
        if path <> "" then return base+path
    else if operation = "episodes"
        id = orbitInteger(args.id,999999999)
        season = orbitInteger(args.season,999,-1)
        if id > 0 and season >= 0 then return base+"/wp-admin/admin-ajax.php?post="+id.toStr()+"&season="+season.toStr()
    else if operation = "embed"
        id = orbitInteger(args.id,999999999)
        option = orbitInteger(args.option,100,-1)
        itemType = orbitInteger(args.itemType,100,-1)
        if id > 0 and option >= 0 and itemType >= 0 then return base+"/?trembed="+option.toStr()+"&trid="+id.toStr()+"&trtype="+itemType.toStr()
    end if
    return ""
end function

function rpHdSeriesmetroMatch(text as string, pattern as string) as string
    parts = CreateObject("roRegex",pattern,"si").match(text)
    if parts.count() > 1 then return parts[1]
    return ""
end function

function rpHdSeriesmetroAttr(tag as string, name as string) as string
    quotes = chr(34)+"'"
    return rpHdSeriesmetroMatch(tag,"(?:^|\s)"+name+"\s*=\s*["+quotes+"]([^"+quotes+"]*)["+quotes+"]")
end function

function rpHdSeriesmetroText(value as dynamic, maximum = 2400 as integer) as string
    text = orbitText(value,200000)
    text = CreateObject("roRegex","<[^>]+>","s").replaceAll(text," ")
    for each pair in [["&amp;","&"],["&quot;",chr(34)],["&#039;","'"],["&#39;","'"],["&#8217;","'"],["&#8211;","-"],["&#8212;","-"],["&nbsp;"," "],["&ntilde;","ñ"],["&aacute;","á"],["&eacute;","é"],["&iacute;","í"],["&oacute;","ó"],["&uacute;","ú"]]
        text = text.replace(pair[0],pair[1])
    end for
    return left(CreateObject("roRegex","\s+","").replaceAll(text," ").trim(),maximum)
end function

function rpHdSeriesmetroPath(value as dynamic) as string
    path = orbitText(value,400)
    prefix = "https://www3.seriesmetro.net"
    if left(path,len(prefix)) = prefix then path = mid(path,len(prefix)+1)
    if not CreateObject("roRegex","^/(pelicula|serie|capitulo)/[a-z0-9-]{1,200}/$","").isMatch(path) then return ""
    return path
end function

function rpHdSeriesmetroArt(value as dynamic) as string
    url = orbitText(value,600)
    if left(url,2) = "//" then url = "https:"+url
    if not CreateObject("roRegex","^https://image\.tmdb\.org/t/p/(w[0-9]+|original)/[a-zA-Z0-9_.-]+\.(jpg|png|webp)$","").isMatch(url) then return ""
    return url
end function

function rpHdSeriesmetroCatalog(html as dynamic, kind as string, page as integer) as object
    answer = {valid:false,items:[],hasMore:false,nextPage:page+1,total:0}
    text = orbitText(html,2097153)
    if len(text) > 2097152 or instr(1,lcase(text),"seriesmetro") = 0 then return answer
    if kind <> "movie" and kind <> "series" then return answer
    answer.valid = true
    seen = {}
    blocks = CreateObject("roRegex","<li\s+id="+chr(34)+"post-","i").split(text)
    for i = 1 to blocks.count()-1
        if i > 100 then exit for
        block = blocks[i]
        number = orbitInteger(rpHdSeriesmetroMatch(block,"^([0-9]+)"),999999999)
        path = rpHdSeriesmetroPath(rpHdSeriesmetroMatch(block,"<a[^>]+href="+chr(34)+"([^"+chr(34)+"]+/(?:pelicula|serie)/[^"+chr(34)+"]+)"))
        expected = "/pelicula/"
        if kind = "series" then expected = "/serie/"
        title = rpHdSeriesmetroText(rpHdSeriesmetroMatch(block,"<h2[^>]*class="+chr(34)+"entry-title"+chr(34)+"[^>]*>(.*?)</h2>"),200)
        if number > 0 and title <> "" and left(path,len(expected)) = expected
            id = "hdo-seriesmetro-"+number.toStr()
            if not seen.doesExist(id)
                year = rpHdSeriesmetroText(rpHdSeriesmetroMatch(block,"<span[^>]*class="+chr(34)+"year"+chr(34)+"[^>]*>(.*?)</span>"),4)
                poster = rpHdSeriesmetroArt(rpHdSeriesmetroMatch(block,"<img[^>]+src="+chr(34)+"([^"+chr(34)+"]+)"))
                answer.items.push({id:id,imdbId:"",kind:kind,library:"hd-online",provider:"seriesmetro",providerId:number,providerSlug:path,title:title,poster:poster,background:poster,description:"",year:year,runtime:0,language:"",seasons:[]})
                seen[id] = true
            end if
        end if
    end for
    ' Source pages contain eighteen entries before filtering movies/series.
    nextRoute = "/page/"+(page+1).toStr()+"/"
    answer.hasMore = instr(1,text,nextRoute) > 0
    return answer
end function

function rpHdSeriesmetroInputItem(value as dynamic) as dynamic
    if type(value) <> "roAssociativeArray" then return invalid
    if value.provider <> "seriesmetro" then return invalid
    number = orbitInteger(value.providerId,999999999)
    kind = orbitText(value.kind,10)
    path = rpHdSeriesmetroPath(value.providerSlug)
    id = "hdo-seriesmetro-"+number.toStr()
    season = orbitInteger(value.season,999,-1)
    episode = orbitInteger(value.episode,9999)
    if kind = "episode" then id += "-s"+season.toStr()+"-e"+episode.toStr()
    if number < 1 or value.id <> id or path = "" then return invalid
    if kind = "movie" and left(path,10) <> "/pelicula/" then return invalid
    if kind = "series" and left(path,7) <> "/serie/" then return invalid
    if kind = "episode"
        if left(path,10) <> "/capitulo/" or season < 0 or episode < 1 then return invalid
    else if kind <> "movie" and kind <> "series"
        return invalid
    end if
    return {id:id,imdbId:"",kind:kind,library:"hd-online",provider:"seriesmetro",providerId:number,providerSlug:path,title:orbitText(value.title,200),poster:rpHdSeriesmetroArt(value.poster),background:rpHdSeriesmetroArt(value.background),description:orbitText(value.description),year:orbitText(value.year,4),runtime:orbitInteger(value.runtime,86400),language:"",seasons:[],season:season,episode:episode,seriesTitle:orbitText(value.seriesTitle,200)}
end function

function rpHdSeriesmetroMetadata(html as dynamic, item as object) as dynamic
    text = orbitText(html,2097153)
    if len(text) > 2097152 then return invalid
    number = orbitInteger(rpHdSeriesmetroMatch(text,"postid-([0-9]+)"),999999999)
    if number <> item.providerId then return invalid
    title = rpHdSeriesmetroText(rpHdSeriesmetroMatch(text,"<h1[^>]*>(.*?)</h1>"),200)
    if title <> "" then item.title = title
    tags = CreateObject("roRegex","<meta\s+","i").split(text)
    for each tag in tags
        name = rpHdSeriesmetroAttr(tag,"property")
        if name = "" then name = rpHdSeriesmetroAttr(tag,"name")
        if name = "og:description" then item.description = rpHdSeriesmetroText(rpHdSeriesmetroAttr(tag,"content"))
        if name = "og:image"
            art = rpHdSeriesmetroArt(rpHdSeriesmetroAttr(tag,"content"))
            if art <> "" then item.background = art
        end if
    end for
    if item.kind = "series"
        seen = {}
        for each tag in CreateObject("roRegex","<a\s+","i").split(text)
            raw = rpHdSeriesmetroAttr(tag,"data-season")
            number = orbitInteger(raw,999,-1)
            if raw <> "" and number >= 0 then seen[number.toStr()] = true
        end for
        item.seasons = []
        for number = 0 to 999
            if seen.doesExist(number.toStr()) then item.seasons.push({number:number,episodes:[],loaded:false})
        end for
    end if
    return item
end function

function rpHdSeriesmetroEpisodes(html as dynamic, parent as object, requested as integer) as object
    answer = {number:requested,episodes:[],loaded:true}
    text = orbitText(html,2097153)
    if len(text) > 2097152 then return answer
    seen = {}
    for each block in CreateObject("roRegex","<article\s+","i").split(text)
        sequence = rpHdSeriesmetroMatch(block,"<span[^>]*class="+chr(34)+"num-epi"+chr(34)+"[^>]*>(.*?)</span>")
        numbers = CreateObject("roRegex","^([0-9]+)x([0-9]+)$","").match(sequence.trim())
        if numbers.count() = 3
            season = orbitInteger(numbers[1],999,-1)
            episode = orbitInteger(numbers[2],9999)
            path = rpHdSeriesmetroPath(rpHdSeriesmetroMatch(block,"<a[^>]+href="+chr(34)+"([^"+chr(34)+"]+/capitulo/[^"+chr(34)+"]+)"))
            if season = requested and episode > 0 and left(path,10) = "/capitulo/"
                id = "hdo-seriesmetro-"+parent.providerId.toStr()+"-s"+season.toStr()+"-e"+episode.toStr()
                if not seen.doesExist(id)
                    title = rpHdSeriesmetroText(rpHdSeriesmetroMatch(block,"<h2[^>]*class="+chr(34)+"entry-title"+chr(34)+"[^>]*>(.*?)</h2>"),200)
                    if title = "" then title = "Episodio "+episode.toStr()
                    answer.episodes.push({id:id,imdbId:"",kind:"episode",library:"hd-online",provider:"seriesmetro",providerId:parent.providerId,providerSlug:path,title:title,seriesTitle:parent.title,season:season,episode:episode,poster:parent.poster,background:parent.background,description:parent.description,year:parent.year,runtime:0,language:"",seasons:[]})
                    seen[id] = true
                end if
            end if
        end if
        if answer.episodes.count() >= 500 then exit for
    end for
    answer.episodes.sortBy("episode")
    return answer
end function

function rpHdSeriesmetroEmbedOptions(html as dynamic) as object
    answer = []
    text = orbitText(html,2097153)
    options = CreateObject("roRegex","<a[^>]+href="+chr(34)+"#options-","i").split(text)
    triplet = CreateObject("roRegex","[?]trembed=([0-9]+)(?:&#038;|&)trid=([0-9]+)(?:&#038;|&)trtype=([0-9]+)","").match(text)
    if triplet.count() < 4 then return answer
    id = orbitInteger(triplet[2],999999999)
    itemType = orbitInteger(triplet[3],100,-1)
    for each priority in [100,60]
        for i = 1 to options.count()-1
            block = options[i]
            index = orbitInteger(rpHdSeriesmetroMatch(block,"^([0-9]+)"),100,-1)
            label = rpHdSeriesmetroText(rpHdSeriesmetroMatch(block,"<span[^>]*class="+chr(34)+"server"+chr(34)+"[^>]*>(.*?)</span>"),80)
            score = 0
            lower = lcase(label)
            if instr(1,lower,"latino") > 0 then score = 100
            if score = 0 and (instr(1,lower,"castellano") > 0 or instr(1,lower,"español") > 0) then score = 60
            if score = priority and index >= 0
                url = rpHdSeriesmetroEndpoint("embed",{id:id,option:index,itemType:itemType})
                if url <> "" then answer.push({url:url,language:label,score:score})
            end if
            if answer.count() >= 6 then return answer
        end for
    end for
    return answer
end function

function rpHdSeriesmetroFastream(html as dynamic) as string
    text = orbitText(html,2097153)
    quotes = chr(34)+"'"
    url = rpHdSeriesmetroMatch(text,"<iframe[^>]+src=["+quotes+"](https://fastream\.to/[^"+quotes+"]+)["+quotes+"]")
    if not CreateObject("roRegex","^https://fastream\.to/(embed-)?[a-zA-Z0-9_-]+(\.html)?$","").isMatch(url) then return ""
    return url
end function
