' Public HD catalog adapters. Pure normalization and text parsing, no I/O/eval.
' Import CatalogData.brs in the same scope. Resolved CDN URLs stay in memory.

function rpHdOnlineProvider(value as dynamic) as string
    name = lcase(orbitText(value,32))
    if name = "all" or name = "lamovie" or name = "allcalidad" or name = "cinehax" or name = "seriesmetro" or name = "cinecalidad" then return name
    return ""
end function

' Concrete catalogs only. The aggregate selection is never a network host.
function rpHdOnlineProviderIds() as object
    return ["lamovie","allcalidad","cinehax","seriesmetro","cinecalidad"]
end function

' Common spelling must not hide all options in literal provider searches.
function rpHdOnlineSearchQuery(value as dynamic) as string
    query = orbitText(value,120).trim()
    compact = lcase(query).replace(" ","").replace("-","")
    if compact = "spiderman" then return "Spider-Man"
    return query
end function

function rpHdOnlineEscape(value as dynamic) as string
    text = orbitText(value,240).trim()
    bytes = []
    index = 1
    while index <= len(text)
        number = asc(mid(text,index,1))
        if number >= 55296 and number <= 56319 and index < len(text)
            trailing = asc(mid(text,index+1,1))
            if trailing >= 56320 and trailing <= 57343
                number = 65536+(number-55296)*1024+(trailing-56320)
                index++
            end if
        end if
        if number < 128
            bytes.push(number)
        else if number < 2048
            bytes.push(192+(number \ 64))
            bytes.push(128+(number mod 64))
        else if number < 65536
            bytes.push(224+(number \ 4096))
            bytes.push(128+((number \ 64) mod 64))
            bytes.push(128+(number mod 64))
        else
            bytes.push(240+(number \ 262144))
            bytes.push(128+((number \ 4096) mod 64))
            bytes.push(128+((number \ 64) mod 64))
            bytes.push(128+(number mod 64))
        end if
        index++
    end while
    answer = ""
    digits = "0123456789ABCDEF"
    for each value in bytes
        if (value >= 48 and value <= 57) or (value >= 65 and value <= 90) or (value >= 97 and value <= 122) or value = 45 or value = 46 or value = 95 or value = 126
            answer += chr(value)
        else
            answer += "%" + mid(digits,(value \ 16)+1,1) + mid(digits,(value mod 16)+1,1)
        end if
    end for
    return answer
end function

function rpHdOnlineEndpoint(provider as dynamic, operation as string, args as dynamic) as string
    provider = rpHdOnlineProvider(provider)
    if provider = "" or provider = "all" or type(args) <> "roAssociativeArray" then return ""
    if provider = "cinehax" then return rpHdCinehaxEndpoint(operation,args)
    if provider = "seriesmetro" then return rpHdSeriesmetroEndpoint(operation,args)
    if provider = "cinecalidad" then return ""
    kind = orbitText(args.kind,10)
    postType = ""
    if kind = "movie" then postType = "movies"
    if kind = "series" then postType = "tvshows"
    page = orbitInteger(args.page,10000,1)
    if page < 1 then page = 1
    id = orbitInteger(args.id,999999999)
    season = orbitInteger(args.season,999,1)
    query = rpHdOnlineEscape(args.query)
    if provider = "lamovie"
        base = "https://lamovie.org/wp-api/v1/"
        if operation = "catalog" and postType <> "" then return base + "listing/"+postType+"?page="+page.toStr()+"&orderBy=popular&order=desc&postType="+postType+"&postsPerPage=20"
        if operation = "search" and postType <> "" and query <> "" then return base+"search?q="+query+"&postType="+postType+"&postsPerPage=20&page="+page.toStr()
        if operation = "meta" and postType <> ""
            slug = orbitText(args.slug,200)
            if CreateObject("roRegex","^[a-z0-9-]{1,200}$","").isMatch(slug) then return base+"single/"+postType+"?slug="+slug+"&postType="+postType
        end if
        if operation = "episodes" and id > 0 then return base+"single/episodes/list?_id="+id.toStr()+"&season="+season.toStr()+"&page="+page.toStr()+"&postsPerPage=200"
        if operation = "player" and id > 0 then return base+"player?postId="+id.toStr()+"&demo=0"
    else
        base = "https://allcalidad.re/api/rest/"
        if operation = "catalog" and postType <> "" then return base+"listing?page="+page.toStr()+"&post_type="+postType+"&posts_per_page=20"
        if operation = "search" and postType <> "" and query <> "" then return base+"search?query="+query+"&page="+page.toStr()+"&post_type="+postType+"&posts_per_page=20"
        if operation = "episodes" and id > 0 then return base+"episodes?post_id="+id.toStr()
        if operation = "player" and id > 0 then return base+"player?post_id="+id.toStr()+"&_any=1"
    end if
    return ""
end function

function rpHdOnlineArt(raw as dynamic, provider as string) as string
    path = orbitText(raw,600)
    if not CreateObject("roRegex","^/(thumbs|backdrops|logos)/[a-zA-Z0-9_.-]+\.(webp|jpg|jpeg|png)$","").isMatch(path) then return ""
    if provider = "lamovie" then return "https://lamovie.org/wp-content/uploads"+path
    if provider = "allcalidad" then return "https://allcalidad.re/wp-content/uploads"+path
    return ""
end function

function rpHdOnlineItem(raw as dynamic, provider as string, kind as string) as dynamic
    provider = rpHdOnlineProvider(provider)
    if provider = "" or provider = "all" or provider = "cinehax" or provider = "seriesmetro" or provider = "cinecalidad" or type(raw) <> "roAssociativeArray" then return invalid
    expected = "movies"
    if kind = "series" then expected = "tvshows"
    if kind <> "movie" and kind <> "series" then return invalid
    if orbitText(raw.type,20) <> expected then return invalid
    number = orbitInteger(raw._id,999999999)
    title = orbitText(raw.title,200).trim()
    if number < 1 or title = "" then return invalid
    images = raw.images
    if type(images) <> "roAssociativeArray" then images = {}
    runtime = orbitText(raw.runtime,16).toFloat()
    if runtime < 0 or runtime > 1440 then runtime = 0
    return {
        id: "hdo-"+provider+"-"+number.toStr(), imdbId: "", kind: kind
        provider: provider, providerId: number, providerSlug: orbitText(raw.slug,200)
        library: "hd-online", title: title, description: orbitText(raw.overview)
        poster: rpHdOnlineArt(images.poster,provider), background: rpHdOnlineArt(images.backdrop,provider)
        year: left(orbitText(raw.release_date,32),4), runtime: int(runtime*60), language: "", seasons: []
    }
end function

function rpHdOnlineCatalog(raw as dynamic, provider as string, kind as string, page as integer) as object
    if provider = "cinehax" then return rpHdCinehaxCatalog(raw,kind,page)
    if provider = "seriesmetro" then return rpHdSeriesmetroCatalog(raw,kind,page)
    if provider = "cinecalidad" then return {items:[],hasMore:false,nextPage:page+1,total:0}
    answer = {items:[], hasMore:false, nextPage:page+1, total:0}
    if type(raw) <> "roAssociativeArray" then return answer
    if type(raw.data) <> "roAssociativeArray" then return answer
    if type(raw.data.posts) <> "roArray" then return answer
    seen = {}
    take = raw.data.posts.count()
    if take > 200 then take = 200
    for i = 0 to take-1
        item = rpHdOnlineItem(raw.data.posts[i],provider,kind)
        if item <> invalid
            if not seen.doesExist(item.id)
                answer.items.push(item)
                seen[item.id] = true
            end if
        end if
    end for
    pagination = raw.data.pagination
    if type(pagination) = "roAssociativeArray"
        answer.total = orbitInteger(pagination.total,1000000)
        lastPage = orbitInteger(pagination.last_page,10000)
        current = orbitInteger(pagination.current_page,10000,page)
        answer.nextPage = current+1
        answer.hasMore = lastPage > current and take > 0
    else
        answer.hasMore = take >= 20
    end if
    return answer
end function

function rpHdOnlineMetadata(raw as dynamic, provider as string, kind as string, expectedId as string) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    item = rpHdOnlineItem(raw.data,provider,kind)
    if item = invalid then return invalid
    if item.id <> expectedId then return invalid
    return item
end function

function rpHdOnlineEpisodes(raw as dynamic, provider as string, parent as dynamic) as object
    answer = {seasons:[], seasonNumbers:[], hasMore:false, nextPage:1}
    if type(raw) <> "roAssociativeArray" or type(parent) <> "roAssociativeArray" then return answer
    provider = rpHdOnlineProvider(provider)
    if provider = "" or provider = "all" or provider = "cinehax" or provider = "seriesmetro" or provider = "cinecalidad" then return answer
    data = raw.data
    posts = []
    if type(data) = "roArray"
        posts = data
    else if type(data) = "roAssociativeArray"
        if type(data.posts) = "roArray" then posts = data.posts
        if type(data.seasons) = "roArray"
            for each value in data.seasons
                number = orbitInteger(value,999,-1)
                if number >= 0 then answer.seasonNumbers.push(number)
            end for
        end if
        if type(data.pagination) = "roAssociativeArray"
            current = orbitInteger(data.pagination.current_page,10000,1)
            answer.nextPage = current+1
            answer.hasMore = orbitInteger(data.pagination.last_page,10000) > current
        end if
    end if
    seasonMap = {}
    seen = {}
    take = posts.count()
    if take > 5000 then take = 5000
    for i = 0 to take-1
        ep = posts[i]
        if type(ep) = "roAssociativeArray"
            number = orbitInteger(ep._id,999999999)
            seasonNumber = orbitInteger(ep.season_number,999,-1)
            episodeNumber = orbitInteger(ep.episode_number,9999)
            if number > 0 and seasonNumber >= 0 and episodeNumber > 0
                id = "hdo-"+provider+"-"+number.toStr()
                if not seen.doesExist(id)
                    title = orbitText(ep.title,200)
                    if title = "" then title = "Episodio "+episodeNumber.toStr()
                    item = {
                        id:id, imdbId:"", kind:"episode", library:"hd-online", provider:provider, providerId:number
                        providerSlug:"", title:title, seriesTitle:parent.title, season:seasonNumber, episode:episodeNumber
                        poster:parent.poster, background:parent.background, description:orbitText(ep.overview)
                        year:parent.year, runtime:0, language:"", seasons:[]
                    }
                    if item.description = "" then item.description = parent.description
                    key = seasonNumber.toStr()
                    if not seasonMap.doesExist(key) then seasonMap[key] = {number:seasonNumber,episodes:[]}
                    seasonMap[key].episodes.push(item)
                    seen[id] = true
                end if
            end if
        end if
    end for
    haveDeclaredSeasons = answer.seasonNumbers.count() > 0
    for number = 0 to 999
        key = number.toStr()
        if seasonMap.doesExist(key)
            seasonMap[key].episodes.sortBy("episode")
            answer.seasons.push(seasonMap[key])
            if not haveDeclaredSeasons then answer.seasonNumbers.push(number)
        end if
    end for
    return answer
end function

function rpHdOnlineEmbeds(raw as dynamic) as object
    result = []
    if type(raw) <> "roAssociativeArray" then return result
    if type(raw.data) <> "roAssociativeArray" then return result
    if type(raw.data.embeds) <> "roArray" then return result
    count = 0
    for each embed in raw.data.embeds
        count++
        if count > 30 then exit for
        if type(embed) = "roAssociativeArray"
            url = orbitHttpsUrl(embed.url)
            language = orbitText(embed.lang,80)
            score = 0
            lower = lcase(language)
            if instr(1,lower,"latino") > 0 then score = 100
            if score = 0 and (instr(1,lower,"castellano") > 0 or instr(1,lower,"español") > 0) then score = 60
            if CreateObject("roRegex","^https://vimeos\.net/embed-[a-zA-Z0-9_-]+(\.html)?$","").isMatch(url) and score > 0
                result.push({url:url,language:language,quality:orbitText(embed.quality,40),score:score})
            end if
        end if
    end for
    ordered = []
    for each priority in [100,60]
        for each row in result
            if row.score = priority then ordered.push(row)
        end for
    end for
    return ordered
end function

function rpHdOnlineHex(text as string) as integer
    if not CreateObject("roRegex","^[0-9a-fA-F]{1,8}$","").isMatch(text) then return -1
    result = 0
    for i = 1 to len(text)
        n = instr(1,"0123456789abcdef",lcase(mid(text,i,1)))-1
        result = result*16+n
    end for
    return result
end function

function rpHdOnlineJsString(text as string) as string
    result = ""
    i = 1
    while i <= len(text)
        char = mid(text,i,1)
        advanceBy = 1
        if char = chr(92) and i < len(text)
            i++
            char = mid(text,i,1)
            if char = "x" and i+2 <= len(text)
                value = rpHdOnlineHex(mid(text,i+1,2))
                if value >= 0
                    char = chr(value)
                    advanceBy = 3
                end if
            else if char = "u" and i+4 <= len(text)
                value = rpHdOnlineHex(mid(text,i+1,4))
                if value >= 0 and value < 128
                    char = chr(value)
                    advanceBy = 5
                end if
            end if
            if char = "n" then char = chr(10)
            if char = "r" then char = chr(13)
            if char = "t" then char = chr(9)
        end if
        result += char
        i += advanceBy
    end while
    return result
end function

function rpHdOnlineToken(number as integer, radix as integer) as string
    alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    result = ""
    if number = 0 then return "0"
    while number > 0
        result = mid(alphabet,(number mod radix)+1,1)+result
        number = number \ radix
    end while
    return result
end function

function rpHdOnlineTokenIndex(token as string, radix as integer, maximum as integer) as integer
    result = 0
    alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for i = 1 to len(token)
        value = instr(1,alphabet,mid(token,i,1))-1
        if value < 0 or value >= radix then return -1
        result = result*radix+value
        if result > maximum then return -1
    end for
    return result
end function

function rpHdOnlineUnpack(html as dynamic) as string
    text = orbitText(html,524289)
    if text = "" or len(text) > 524288 then return ""
    pattern = "}\s*\(\s*'((?:\\.|[^'\\])*)'\s*,\s*([0-9]+)\s*,\s*([0-9]+)\s*,\s*'((?:\\.|[^'\\])*)'\.split\('\|'\)"
    parts = CreateObject("roRegex",pattern,"s").match(text)
    if parts.count() < 5 then return text
    radix = orbitInteger(parts[2],62)
    count = orbitInteger(parts[3],5000)
    if radix < 2 or count < 1 then return text
    payload = rpHdOnlineJsString(parts[1])
    words = rpHdOnlineJsString(parts[4]).split("|")
    if len(payload) > 262144 then return ""
    result = ""
    token = ""
    alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
    for i = 1 to len(payload)+1
        char = ""
        if i <= len(payload) then char = mid(payload,i,1)
        if char <> "" and instr(1,alphabet,char) > 0
            token += char
        else
            if token <> ""
                index = rpHdOnlineTokenIndex(token,radix,count-1)
                if index >= 0 and index < words.count()
                    if words[index] <> ""
                        result += words[index]
                    else
                        result += token
                    end if
                else
                    result += token
                end if
                token = ""
            end if
            result += char
        end if
        if len(text)+len(result)+1 > 1048576 then return ""
    end for
    return text+chr(10)+result
end function

function rpHdOnlineCdn(value as dynamic) as string
    url = orbitHttpsUrl(value)
    if not CreateObject("roRegex","^https://(([a-z0-9-]+\.)?vimeos\.(net|zip)|([a-z0-9-]+\.)?fastream\.to)/","i").isMatch(url) then return ""
    return url
end function

function rpHdOnlineMediaUrl(html as dynamic) as string
    text = rpHdOnlineUnpack(html)
    quotes = chr(34)+"'"
    pattern = "file\s*:\s*["+quotes+"]([^"+quotes+"]+\.m3u8[^"+quotes+"]*)["+quotes+"]"
    match = CreateObject("roRegex",pattern,"i").match(text)
    if match.count() >= 2
        url = rpHdOnlineCdn(rpHdOnlineJsString(match[1]))
        if url <> "" then return url
    end if
    ' New public player format: read a literal JSON array, never execute JS.
    match = CreateObject("roRegex",chr(34)+"stream_urls"+chr(34)+"\s*:\s*(\[[^\]]{1,20000}\])","i").match(text)
    if match.count() >= 2
        urls = ParseJson(match[1])
        if type(urls) = "roArray"
            count = 0
            for each rawUrl in urls
                count++
                if count > 10 then exit for
                url = rpHdOnlineCdn(rawUrl)
                if url <> "" and instr(1,url,".m3u8") > 0 then return url
            end for
        end if
    end if
    return ""
end function

function rpHdOnlineJoin(base as string, relative as string) as string
    relative = relative.trim()
    if relative = "" then return ""
    if instr(1,relative,"..") > 0 or instr(1,relative,chr(92)) > 0 then return ""
    if left(relative,8) = "https://" then return rpHdOnlineCdn(relative)
    if left(relative,2) = "//" then return rpHdOnlineCdn("https:"+relative)
    root = CreateObject("roRegex","^(https://[^/?#]+)","").match(base)
    if root.count() < 2 then return ""
    if left(relative,1) = "/" then return rpHdOnlineCdn(root[1]+relative)
    clean = base.split("?")[0].split("#")[0]
    last = 0
    for i = 1 to len(clean)
        if mid(clean,i,1) = "/" then last = i
    end for
    return rpHdOnlineCdn(left(clean,last)+relative)
end function

function rpHdOnlineAttributes(line as string) as object
    answer = {}
    separatorAt = instr(1,line,":")
    if separatorAt > 0 then line = mid(line,separatorAt+1)
    quote = false
    buffer = ""
    parts = []
    for i = 1 to len(line)+1
        char = ","
        if i <= len(line) then char = mid(line,i,1)
        if char = chr(34) then quote = not quote
        if char = "," and not quote
            parts.push(buffer)
            buffer = ""
        else
            buffer += char
        end if
    end for
    for each part in parts
        separatorAt = instr(1,part,"=")
        if separatorAt > 1
            key = left(part,separatorAt-1).trim()
            value = mid(part,separatorAt+1).trim()
            if left(value,1) = chr(34) and right(value,1) = chr(34) then value = mid(value,2,len(value)-2)
            answer[key] = value
        end if
    end for
    return answer
end function

function rpHdOnlineMaster(body as dynamic, baseUrl as string) as object
    answer = {variants:[],audioTracks:[],encrypted:false}
    text = orbitText(body,1048577)
    if len(text) > 1048576 or rpHdOnlineCdn(baseUrl) = "" then return answer
    if left(text,7) <> "#EXTM3U" then return answer
    lines = text.split(chr(10))
    pending = invalid
    for each rawLine in lines
        line = rawLine.trim()
        if left(line,11) = "#EXT-X-KEY:"
            attrs = rpHdOnlineAttributes(line)
            if attrs.METHOD <> "NONE" then answer.encrypted = true
        else if left(line,13) = "#EXT-X-MEDIA:"
            attrs = rpHdOnlineAttributes(line)
            if attrs.TYPE = "AUDIO"
                answer.audioTracks.push({group:orbitText(attrs["GROUP-ID"],100),name:orbitText(attrs.NAME,80),language:orbitText(attrs.LANGUAGE,20),default:attrs.DEFAULT = "YES",url:rpHdOnlineJoin(baseUrl,orbitText(attrs.URI,4096))})
            end if
        else if left(line,18) = "#EXT-X-STREAM-INF:"
            pending = rpHdOnlineAttributes(line)
        else if line <> "" and left(line,1) <> "#" and pending <> invalid
            dims = orbitText(pending.RESOLUTION,32).split("x")
            width = 0
            height = 0
            if dims.count() = 2
                width = orbitInteger(dims[0],16384)
                height = orbitInteger(dims[1],16384)
            end if
            url = rpHdOnlineJoin(baseUrl,line)
            if url <> ""
                answer.variants.push({url:url,codecs:orbitText(pending.CODECS,200),width:width,height:height,fps:orbitText(pending["FRAME-RATE"],32).toFloat(),bandwidth:orbitInteger(pending.BANDWIDTH,100000000),audioGroup:orbitText(pending.AUDIO,100)})
            end if
            pending = invalid
        end if
    end for
    return answer
end function

' Generic AVC envelope is necessary, and optional callback must confirm actual
' device support. No resolution label is used to infer video or audio codecs.
function rpHdOnlineSelectVariant(master as dynamic, decoderAccept = invalid as dynamic) as dynamic
    if type(master) <> "roAssociativeArray" then return invalid
    if master.encrypted = true or type(master.variants) <> "roArray" then return invalid
    selected = invalid
    score = -1
    for each variant in master.variants
        if type(variant) = "roAssociativeArray"
        codecs = lcase(orbitText(variant.codecs,200))
        avc = CreateObject("roRegex","(^|,)\s*avc1\.([0-9a-f]{6})(\s*,|$)","").match(codecs)
        audio = CreateObject("roRegex","(^|,)\s*mp4a\.40\.2(\s*,|$)","").isMatch(codecs)
        other = CreateObject("roRegex","(hvc1|hev1|av01|vp09|ac-3|ec-3|opus)","").isMatch(codecs)
        if avc.count() >= 3 and audio and not other and codecs.split(",").count() = 2
            profile = rpHdOnlineHex(left(avc[2],2))
            level = rpHdOnlineHex(right(avc[2],2))
            width = orbitInteger(variant.width,1920)
            height = orbitInteger(variant.height,1080)
            fps = variant.fps
            if GetInterface(fps,"ifInt") = invalid and GetInterface(fps,"ifFloat") = invalid and GetInterface(fps,"ifDouble") = invalid then fps = 0
            if fps <= 0 then fps = 30
            profileOk = profile = 66 or profile = 77 or profile = 100
            macroblocks = ((width+15) \ 16)*((height+15) \ 16)
            if profileOk and level >= 10 and level <= 41 and width >= 16 and height >= 16 and fps <= 60 and macroblocks <= 8192 and macroblocks*fps <= 245760
                accepted = true
                if decoderAccept <> invalid
                    response = decoderAccept(variant)
                    accepted = GetInterface(response,"ifBoolean") <> invalid
                    if accepted then accepted = response
                end if
                if accepted
                    candidateScore = width*height
                    if candidateScore > score
                        selected = variant
                        score = candidateScore
                    end if
                end if
            end if
        end if
        end if
    end for
    return selected
end function

' Parse at most a small initial TS sample. Metadata alone must not make a
' video-only HLS child appear to carry usable audio. Only clear AVC + ADTS
' AAC-LC in the PAT-selected program is accepted; no key/decryption logic.
function rpHdOnlineTsPacket(data as dynamic, offset as integer) as dynamic
    if offset < 0 or offset+188 > data.count() then return invalid
    if data[offset] <> 71 then return invalid
    b1 = orbitInteger(data[offset+1],255,-1)
    b2 = orbitInteger(data[offset+2],255,-1)
    b3 = orbitInteger(data[offset+3],255,-1)
    if b1 < 0 or b2 < 0 or b3 < 0 or b1 >= 128 then return invalid
    control = (b3 \ 16) mod 4
    if control = 0 or control = 2 then return invalid
    payloadAt = offset+4
    if control = 3
        adaptationLength = orbitInteger(data[payloadAt],183,-1)
        if adaptationLength < 0 then return invalid
        payloadAt += 1+adaptationLength
    end if
    if payloadAt >= offset+188 then return invalid
    return {pid:(b1 mod 32)*256+b2,pusi:((b1 \ 64) mod 2)=1,payloadAt:payloadAt,endAt:offset+188,counter:b3 mod 16,scrambled:(b3 \ 64)>0}
end function

function rpHdOnlineTsSection(data as dynamic, pid as integer, tableId as integer) as dynamic
    buffer = []
    collecting = false
    expected = 0
    previous = -1
    for offset = 0 to data.count()-188 step 188
        packet = rpHdOnlineTsPacket(data,offset)
        if packet <> invalid
            if packet.pid = pid and not packet.scrambled
                cursor = packet.payloadAt
                append = false
                if packet.pusi
                    pointer = orbitInteger(data[cursor],183,-1)
                    cursor += 1+pointer
                    buffer = []
                    expected = 0
                    collecting = pointer >= 0 and cursor < packet.endAt
                    if collecting
                        collecting = data[cursor] = tableId
                        append = collecting
                    end if
                else if collecting
                    append = packet.counter = ((previous+1) mod 16)
                    if not append then collecting = false
                end if
                if append
                    previous = packet.counter
                    while cursor < packet.endAt
                        value = orbitInteger(data[cursor],255,-1)
                        if value < 0 then return invalid
                        buffer.push(value)
                        cursor++
                        if buffer.count() = 3
                            if buffer[1] < 128 then return invalid
                            expected = 3+(buffer[1] mod 16)*256+buffer[2]
                            if expected < 12 or expected > 1024 then return invalid
                        end if
                        if expected > 0 and buffer.count() >= expected then return buffer
                    end while
                end if
            end if
        end if
    end for
    return invalid
end function

function rpHdOnlineMuxedAvcAac(data as dynamic) as boolean
    if type(data) <> "roByteArray" and type(data) <> "roArray" then return false
    if data.count() < 188*4 or data.count() > 131072 then return false
    if data[0] <> 71 or data[188] <> 71 or data[376] <> 71 then return false
    pat = rpHdOnlineTsSection(data,0,0)
    if pat = invalid then return false
    if pat.count() < 16 or (pat[5] mod 2) <> 1 then return false
    program = 0
    pmtPid = -1
    cursor = 8
    while cursor+4 <= pat.count()-4
        number = pat[cursor]*256+pat[cursor+1]
        if number > 0 and pmtPid < 0
            program = number
            pmtPid = (pat[cursor+2] mod 32)*256+pat[cursor+3]
        end if
        cursor += 4
    end while
    if pmtPid < 1 then return false
    pmt = rpHdOnlineTsSection(data,pmtPid,2)
    if pmt = invalid then return false
    if pmt.count() < 16 or (pmt[5] mod 2) <> 1 then return false
    if pmt[3]*256+pmt[4] <> program then return false
    cursor = 12+(pmt[10] mod 16)*256+pmt[11]
    videoPid = -1
    audioPid = -1
    while cursor+5 <= pmt.count()-4
        streamType = pmt[cursor]
        streamPid = (pmt[cursor+1] mod 32)*256+pmt[cursor+2]
        esLength = (pmt[cursor+3] mod 16)*256+pmt[cursor+4]
        if cursor+5+esLength > pmt.count()-4 then return false
        if streamType = 27 and videoPid < 0 then videoPid = streamPid
        if streamType = 15 and audioPid < 0 then audioPid = streamPid
        if streamType = 36 or streamType = 3 or streamType = 4 or streamType = 17 or streamType = 129 or streamType = 135 then return false
        cursor += 5+esLength
    end while
    if videoPid < 1 or audioPid < 1 or videoPid = audioPid then return false
    videoPes = false
    audioLc = false
    for offset = 0 to data.count()-188 step 188
        packet = rpHdOnlineTsPacket(data,offset)
        if packet <> invalid
            if packet.pid = videoPid or packet.pid = audioPid
                if packet.scrambled then return false
                start = packet.payloadAt
                if packet.pusi and start+9 <= packet.endAt
                    prefix = data[start] = 0 and data[start+1] = 0 and data[start+2] = 1
                    if prefix
                        streamId = data[start+3]
                        if packet.pid = videoPid and streamId >= 224 and streamId <= 239 then videoPes = true
                        if packet.pid = audioPid and streamId >= 192 and streamId <= 223
                            headerLength = orbitInteger(data[start+8],175,-1)
                            adts = start+9+headerLength
                            if headerLength >= 0 and adts+7 <= packet.endAt
                                a0 = orbitInteger(data[adts],255,-1)
                                a1 = orbitInteger(data[adts+1],255,-1)
                                a2 = orbitInteger(data[adts+2],255,-1)
                                a3 = orbitInteger(data[adts+3],255,-1)
                                if a0 = 255 and a1 >= 240 and ((a1 \ 2) mod 4) = 0 and a2 >= 0 and a3 >= 0
                                    objectType = (a2 \ 64)+1
                                    sampleRateIndex = (a2 \ 4) mod 16
                                    channels = (a2 mod 2)*4+(a3 \ 64)
                                    if objectType = 2 and sampleRateIndex <= 12 and channels >= 1 and channels <= 2 then audioLc = true
                                end if
                            end if
                        end if
                    end if
                end if
            end if
        end if
    end for
    return videoPes and audioLc
end function
