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

function rpHdOnlineEpisodeArt(ep as dynamic, provider as string) as string
    if type(ep) <> "roAssociativeArray" then return ""
    images = ep.images
    if type(images) = "roAssociativeArray"
        for each key in ["still","thumbnail","poster","backdrop","cover"]
            if images.doesExist(key)
                image = rpHdOnlineArt(images[key],provider)
                if image <> "" then return image
            end if
        end for
    end if
    for each key in ["thumbnail","still","poster","image","featured_image","cover"]
        if ep.doesExist(key)
            image = rpHdOnlineArt(ep[key],provider)
            if image <> "" then return image
        end if
    end for
    return ""
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
                    title = orbitText(ep.title,200).trim()
                    if title = "" then title = orbitText(ep.name,200).trim()
                    if title = "" then title = orbitText(ep.episode_title,200).trim()
                    if title = "" then title = "Episodio "+episodeNumber.toStr()
                    episodePoster = rpHdOnlineEpisodeArt(ep,provider)
                    if episodePoster = "" then episodePoster = parent.poster
                    episodeDescription = orbitText(ep.overview,1200)
                    if episodeDescription = "" then episodeDescription = orbitText(ep.description,1200)
                    item = {
                        id:id, imdbId:"", kind:"episode", library:"hd-online", provider:provider, providerId:number
                        providerSlug:"", title:title, seriesTitle:parent.title, season:seasonNumber, episode:episodeNumber
                        poster:episodePoster, background:parent.background, description:episodeDescription
                        year:parent.year, runtime:orbitInteger(ep.runtime,86400), language:"", seasons:[]
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

function rpHdOnlineSkipSpace(value as string, index as integer) as integer
    while index <= len(value)
        code = asc(mid(value,index,1))
        if code <> 9 and code <> 10 and code <> 13 and code <> 32 then exit while
        index++
    end while
    return index
end function

function rpHdOnlineReadQuoted(value as string, index as integer) as object
    answer = {ok:false,value:"",next:index}
    if index > len(value) or mid(value,index,1) <> "'" then return answer
    index++
    result = ""
    while index <= len(value)
        char = mid(value,index,1)
        if char = chr(92) and index < len(value)
            result += char + mid(value,index+1,1)
            index += 2
        else if char = "'"
            answer.ok = true
            answer.value = result
            answer.next = index+1
            return answer
        else
            result += char
            index++
        end if
        if len(result) > 262144 then return answer
    end while
    return answer
end function

function rpHdOnlineReadNumber(value as string, index as integer) as object
    answer = {ok:false,value:0,next:index}
    first = index
    while index <= len(value)
        code = asc(mid(value,index,1))
        if code < 48 or code > 57 then exit while
        index++
    end while
    if index = first then return answer
    answer.ok = true
    answer.value = val(mid(value,first,index-first))
    answer.next = index
    return answer
end function

function rpHdOnlineUnpack(html as dynamic) as string
    text = orbitText(html,524289)
    if text = "" or len(text) > 524288 then return ""
    ' Parse the common Dean Edwards packer arguments without roRegex.
    ' Expected shape: }('payload', radix, count, 'word|list'.split('|')
    marker = 0
    while marker < len(text)
        found = instr(marker+1,text,"}")
        if found = 0 then exit while
        index = rpHdOnlineSkipSpace(text,found+1)
        if index <= len(text) and mid(text,index,1) = "("
            index = rpHdOnlineSkipSpace(text,index+1)
            packed = rpHdOnlineReadQuoted(text,index)
            if packed.ok
                index = rpHdOnlineSkipSpace(text,packed.next)
                if index <= len(text) and mid(text,index,1) = ","
                    radixPart = rpHdOnlineReadNumber(text,rpHdOnlineSkipSpace(text,index+1))
                    if radixPart.ok
                        index = rpHdOnlineSkipSpace(text,radixPart.next)
                        if index <= len(text) and mid(text,index,1) = ","
                            countPart = rpHdOnlineReadNumber(text,rpHdOnlineSkipSpace(text,index+1))
                            if countPart.ok
                                index = rpHdOnlineSkipSpace(text,countPart.next)
                                if index <= len(text) and mid(text,index,1) = ","
                                    wordsPart = rpHdOnlineReadQuoted(text,rpHdOnlineSkipSpace(text,index+1))
                                    if wordsPart.ok
                                        radix = radixPart.value
                                        count = countPart.value
                                        if radix >= 2 and radix <= 62 and count > 0 and count <= 5000
                                            payload = rpHdOnlineJsString(packed.value)
                                            words = rpHdOnlineJsString(wordsPart.value).split("|")
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
                                                        wordIndex = rpHdOnlineTokenIndex(token,radix,count-1)
                                                        if wordIndex >= 0 and wordIndex < words.count()
                                                            if words[wordIndex] <> ""
                                                                result += words[wordIndex]
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
                                        end if
                                    end if
                                end if
                            end if
                        end if
                    end if
                end if
            end if
        end if
        marker = found
    end while
    return text
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
            key = ucase(left(part,separatorAt-1).trim())
            value = mid(part,separatorAt+1).trim()
            if left(value,1) = chr(34) and right(value,1) = chr(34) then value = mid(value,2,len(value)-2)
            answer[key] = value
        end if
    end for
    return answer
end function

function rpHdOnlineMaster(body as dynamic, baseUrl as string) as object
    answer = {variants:[],audioTracks:[],encrypted:false,mediaTagCount:0,audioMediaTagCount:0,audioGroupCount:0,variantAudioGroupCount:0}
    text = orbitText(body,1048577)
    if len(text) > 1048576 or rpHdOnlineCdn(baseUrl) = "" then return answer
    if left(text,7) <> "#EXTM3U" then return answer
    lines = text.split(chr(10))
    pending = invalid
    for each rawLine in lines
        line = rawLine.trim()
        if left(lcase(line),11) = "#ext-x-key:"
            attrs = rpHdOnlineAttributes(line)
            if attrs.METHOD <> "NONE" then answer.encrypted = true
        else if left(lcase(line),13) = "#ext-x-media:"
            answer.mediaTagCount++
            attrs = rpHdOnlineAttributes(line)
            mediaType = lcase(orbitText(attrs.TYPE,20))
            if mediaType = "audio"
                answer.audioMediaTagCount++
                groupId = orbitText(attrs["GROUP-ID"],100)
                if groupId <> "" then answer.audioGroupCount++
                answer.audioTracks.push({group:groupId,name:orbitText(attrs.NAME,80),language:orbitText(attrs.LANGUAGE,20),default:lcase(orbitText(attrs.DEFAULT,10)) = "yes",url:rpHdOnlineJoin(baseUrl,orbitText(attrs.URI,4096))})
            end if
        else if left(lcase(line),18) = "#ext-x-stream-inf:"
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
                answer.variants.push({url:url,codecs:orbitText(pending.CODECS,200),width:width,height:height,fps:orbitText(pending["FRAME-RATE"],32).toFloat(),bandwidth:orbitInteger(pending.BANDWIDTH,100000000),averageBandwidth:orbitInteger(pending["AVERAGE-BANDWIDTH"],100000000),videoRange:orbitText(pending["VIDEO-RANGE"],20),hdcpLevel:orbitText(pending["HDCP-LEVEL"],20),audioGroup:orbitText(pending.AUDIO,100)})
                if orbitText(pending.AUDIO,100) <> "" then answer.variantAudioGroupCount++
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
    selectedBandwidth = 100000001
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
                    candidateBandwidth = orbitInteger(variant.averageBandwidth,100000000)
                    if candidateBandwidth <= 0 then candidateBandwidth = orbitInteger(variant.bandwidth,100000000)
                    if candidateBandwidth <= 0 then candidateBandwidth = 100000000
                    ' Keep the highest supported resolution, but among equal resolutions
                    ' start with the lower-bitrate rendition to reduce initial transfer.
                    if candidateScore > score or (candidateScore = score and candidateBandwidth < selectedBandwidth)
                        selected = variant
                        score = candidateScore
                        selectedBandwidth = candidateBandwidth
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


function rpHdOnlineTsTimingProfile(data as dynamic, videoPid as integer, audioPid as integer) as object
    result = {videoPackets:0,audioPackets:0,videoContinuityErrors:0,audioContinuityErrors:0,videoPesStarts:0,audioPesStarts:0,videoPtsCount:0,audioPtsCount:0,videoDtsCount:0,audioDtsCount:0,pcrCount:0,discontinuityFlags:0,firstVideoPts:-1,lastVideoPts:-1,firstAudioPts:-1,lastAudioPts:-1,firstPcr:-1,lastPcr:-1,invalidPackets:0,transportErrors:0,scrambledPackets:0}
    if type(data) <> "roByteArray" and type(data) <> "roArray" then return result
    if data.count() < 188*4 or data.count() > 4194304 then return result
    previousVideo = -1
    previousAudio = -1
    for offset = 0 to data.count()-188 step 188
        if data[offset] <> 71
            result.invalidPackets++
            return result
        end if
        b1 = orbitInteger(data[offset+1],255,-1)
        b2 = orbitInteger(data[offset+2],255,-1)
        b3 = orbitInteger(data[offset+3],255,-1)
        if b1 < 0 or b2 < 0 or b3 < 0
            result.invalidPackets++
            return result
        end if
        if (b1 \ 128) = 1 then result.transportErrors++
        if (b3 \ 64) mod 2 = 1 then result.scrambledPackets++
        pid = (b1 mod 32)*256+b2
        pusi = ((b1 \ 64) mod 2) = 1
        control = (b3 \ 16) mod 4
        cc = b3 mod 16
        if control = 0 then return result
        adaptationLength = 0
        flags = 0
        if control = 2 or control = 3
            adaptationLength = orbitInteger(data[offset+4],183,-1)
            if adaptationLength < 0 then return result
            if adaptationLength > 0 then flags = orbitInteger(data[offset+5],255,0)
            if adaptationLength >= 7 and (flags mod 32) >= 16 and (flags mod 32) < 32
                pcrBase = data[offset+6]*33554432 + data[offset+7]*131072 + data[offset+8]*512 + data[offset+9]*2 + (data[offset+10] \ 128)
                result.pcrCount++
                if result.firstPcr < 0 then result.firstPcr = pcrBase
                result.lastPcr = pcrBase
            end if
            if adaptationLength > 0 and (flags mod 2) = 1 then result.discontinuityFlags++
        end if
        if pid = videoPid or pid = audioPid
            if control = 1 or control = 3
                if pid = videoPid
                    result.videoPackets++
                    if previousVideo >= 0 and cc <> ((previousVideo+1) mod 16) and not (adaptationLength > 0 and (flags mod 2) = 1) then result.videoContinuityErrors++
                    previousVideo = cc
                else
                    result.audioPackets++
                    if previousAudio >= 0 and cc <> ((previousAudio+1) mod 16) and not (adaptationLength > 0 and (flags mod 2) = 1) then result.audioContinuityErrors++
                    previousAudio = cc
                end if
                payloadAt = offset+4
                if control = 3 then payloadAt += 1+adaptationLength
                if pusi and payloadAt+13 < offset+188 and data[payloadAt] = 0 and data[payloadAt+1] = 0 and data[payloadAt+2] = 1
                    if pid = videoPid then result.videoPesStarts++ else result.audioPesStarts++
                    flagsByte = orbitInteger(data[payloadAt+7],255,0)
                    if (flagsByte \ 128) mod 2 = 1
                        pts0 = data[payloadAt+9]
                        pts1 = data[payloadAt+10]
                        pts2 = data[payloadAt+11]
                        pts3 = data[payloadAt+12]
                        pts4 = data[payloadAt+13]
                        ptsValue = ((pts0 \ 2) mod 8)*1073741824 + pts1*4194304 + ((pts2 \ 2) mod 128)*32768 + pts3*128 + ((pts4 \ 2) mod 128)
                        if pid = videoPid
                            result.videoPtsCount++
                            if result.firstVideoPts < 0 then result.firstVideoPts = ptsValue
                            result.lastVideoPts = ptsValue
                        else
                            result.audioPtsCount++
                            if result.firstAudioPts < 0 then result.firstAudioPts = ptsValue
                            result.lastAudioPts = ptsValue
                        end if
                    end if
                    if (flagsByte \ 64) mod 2 = 1
                        if pid = videoPid then result.videoDtsCount++ else result.audioDtsCount++
                    end if
                end if
            end if
        end if
    end for
    return result
end function

function rpHdOnlineTsStartupProfile(data as dynamic) as object
    profile = {valid:false,sampleBytes:0,pat:false,pmt:false,videoPid:-1,audioPid:-1,firstVideoPesByte:-1,firstNalType:0,firstVclType:0,idrPresent:false,idrByte:-1,spsPresent:false,ppsPresent:false,spsProfileIdc:-1,spsConstraints:-1,spsLevelIdc:-1}
    if type(data) <> "roByteArray" and type(data) <> "roArray" then return profile
    if data.count() < 188*4 or data.count() > 131072 then return profile
    profile.sampleBytes = data.count()
    if data[0] <> 71 or data[188] <> 71 or data[376] <> 71 then return profile
    pat = rpHdOnlineTsSection(data,0,0)
    if pat = invalid then return profile
    if pat.count() < 16 or (pat[5] mod 2) <> 1 then return profile
    profile.pat = true
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
    if pmtPid < 1 then return profile
    pmt = rpHdOnlineTsSection(data,pmtPid,2)
    if pmt = invalid then return profile
    if pmt.count() < 16 or (pmt[5] mod 2) <> 1 then return profile
    if pmt[3]*256+pmt[4] <> program then return profile
    profile.pmt = true
    cursor = 12+(pmt[10] mod 16)*256+pmt[11]
    videoPid = -1
    audioPid = -1
    while cursor+5 <= pmt.count()-4
        streamType = pmt[cursor]
        streamPid = (pmt[cursor+1] mod 32)*256+pmt[cursor+2]
        esLength = (pmt[cursor+3] mod 16)*256+pmt[cursor+4]
        if cursor+5+esLength > pmt.count()-4 then return profile
        if streamType = 27 and videoPid < 0 then videoPid = streamPid
        if streamType = 15 and audioPid < 0 then audioPid = streamPid
        cursor += 5+esLength
    end while
    profile.videoPid = videoPid
    profile.audioPid = audioPid
    if videoPid < 1 then return profile
    for offset = 0 to data.count()-188 step 188
        packet = rpHdOnlineTsPacket(data,offset)
        if packet <> invalid
            if packet.pid = videoPid and not packet.scrambled
                start = packet.payloadAt
                if packet.pusi and profile.firstVideoPesByte < 0
                    if start+4 < packet.endAt
                        if data[start] = 0 and data[start+1] = 0 and data[start+2] = 1 and data[start+3] >= 224 and data[start+3] <= 239
                            profile.firstVideoPesByte = start
                        end if
                    end if
                end if
                cursor = packet.payloadAt
                while cursor+4 < packet.endAt
                    nalAt = -1
                    if data[cursor] = 0 and data[cursor+1] = 0 and data[cursor+2] = 1
                        nalAt = cursor+3
                    else if data[cursor] = 0 and data[cursor+1] = 0 and data[cursor+2] = 0 and data[cursor+3] = 1
                        nalAt = cursor+4
                    end if
                    if nalAt >= 0
                        nalType = data[nalAt] mod 32
                        if nalType = 7
                            profile.spsPresent = true
                            if nalAt+3 < packet.endAt
                                profile.spsProfileIdc = data[nalAt+1]
                                profile.spsConstraints = data[nalAt+2]
                                profile.spsLevelIdc = data[nalAt+3]
                            end if
                        end if
                        if nalType = 8 then profile.ppsPresent = true
                        if (nalType = 1 or nalType = 5) and profile.firstVclType = 0 then profile.firstVclType = nalType
                        if nalType = 5 and not profile.idrPresent
                            profile.idrPresent = true
                            profile.idrByte = offset+nalAt
                        end if
                        cursor = nalAt+1
                    else
                        cursor++
                    end if
                end while
            end if
        end if
    end for
    profile.valid = true
    return profile
end function

' Diagnostic 3.5.58: extract AAC ADTS frames from one bounded MPEG-TS sample.
' This is read-only: it never changes the stream URL, manifest, or playback.
function rpHdOnlineTsAdtsProfile(data as dynamic, audioPid as integer) as object
    result = {valid:false,payloadBytes:0,frames:0,invalidHeaders:0,truncatedFrames:0,firstFrameLength:0,lastFrameLength:0,minFrameLength:0,maxFrameLength:0,profile:-1,sampleRateIndex:-1,channelConfig:-1,rawDataBlocks:0}
    if type(data) <> "roByteArray" and type(data) <> "roArray" then return result
    if data.count() < 188*4 or data.count() > 131072 or audioPid < 1 then return result
    audio = CreateObject("roByteArray")
    for offset = 0 to data.count()-188 step 188
        packet = rpHdOnlineTsPacket(data,offset)
        if packet <> invalid and packet.pid = audioPid and not packet.scrambled
            cursor = packet.payloadAt
            if packet.pusi
                if cursor+9 > packet.endAt then continue for
                if data[cursor] <> 0 or data[cursor+1] <> 0 or data[cursor+2] <> 1 then continue for
                streamId = data[cursor+3]
                if streamId < 192 or streamId > 223 then continue for
                headerLength = orbitInteger(data[cursor+8],255,-1)
                if headerLength < 0 then continue for
                cursor += 9+headerLength
            end if
            while cursor < packet.endAt
                audio.push(data[cursor])
                cursor++
            end while
        end if
    end for
    result.payloadBytes = audio.count()
    if audio.count() < 7 then return result
    cursor = 0
    while cursor+7 <= audio.count()
        b0 = orbitInteger(audio[cursor],255,-1)
        b1 = orbitInteger(audio[cursor+1],255,-1)
        b2 = orbitInteger(audio[cursor+2],255,-1)
        b3 = orbitInteger(audio[cursor+3],255,-1)
        b4 = orbitInteger(audio[cursor+4],255,-1)
        b5 = orbitInteger(audio[cursor+5],255,-1)
        b6 = orbitInteger(audio[cursor+6],255,-1)
        if b0 = 255 and b1 >= 240 and ((b1 \ 2) mod 4) = 0
            profile = (b2 \ 64)
            sampleRate = (b2 \ 2) mod 16
            channels = (b2 mod 2)*4+(b3 \ 64)
            frameLength = (b3 mod 4)*2048+(b4*8)+(b5 \ 32)
            headerLength = 7
            if (b1 mod 2) = 0 then headerLength = 9
            if sampleRate <= 12 and channels <= 7 and frameLength >= headerLength
                if cursor+frameLength > audio.count()
                    result.truncatedFrames++
                    exit while
                end if
                result.frames++
                if result.frames = 1
                    result.firstFrameLength = frameLength
                    result.minFrameLength = frameLength
                    result.maxFrameLength = frameLength
                    result.profile = profile
                    result.sampleRateIndex = sampleRate
                    result.channelConfig = channels
                else
                    if frameLength < result.minFrameLength then result.minFrameLength = frameLength
                    if frameLength > result.maxFrameLength then result.maxFrameLength = frameLength
                    if profile <> result.profile or sampleRate <> result.sampleRateIndex or channels <> result.channelConfig then result.invalidHeaders++
                end if
                result.lastFrameLength = frameLength
                result.rawDataBlocks += (b6 mod 4)+1
                cursor += frameLength
            else
                result.invalidHeaders++
                cursor++
            end if
        else
            cursor++
        end if
    end while
    result.valid = result.frames > 0
    return result
end function



' Diagnostic 3.5.59: validate consecutive ADTS frames after extracting complete audio PES payloads.
function rpHdOnlineTsAdtsHeader(data as dynamic, offset as integer) as object
    result = {valid:false,length:0,profile:-1,rateIndex:-1,channels:-1}
    if offset < 0 or offset+7 > data.count() then return result
    b0 = orbitInteger(data[offset],255,-1)
    b1 = orbitInteger(data[offset+1],255,-1)
    b2 = orbitInteger(data[offset+2],255,-1)
    b3 = orbitInteger(data[offset+3],255,-1)
    b4 = orbitInteger(data[offset+4],255,-1)
    b5 = orbitInteger(data[offset+5],255,-1)
    if b0 <> 255 or b1 < 0 or b2 < 0 or b3 < 0 or b4 < 0 or b5 < 0 then return result
    if b1 < 240 or ((b1 \ 2) mod 4) <> 0 then return result
    rateIndex = (b2 \ 2) mod 16
    channels = (b2 mod 2)*4+(b3 \ 64)
    frameLength = (b3 mod 4)*2048+b4*8+(b5 \ 32)
    headerLength = 7
    if (b1 mod 2) = 0 then headerLength = 9
    if rateIndex > 12 or frameLength < headerLength then return result
    result.valid = true
    result.length = frameLength
    result.profile = b2 \ 64
    result.rateIndex = rateIndex
    result.channels = channels
    return result
end function

function rpHdOnlineTsAdtsSequenceProfile(data as dynamic, audioPid as integer) as object
    result = {valid:false,tsPackets:0,pesStarts:0,pesPayloadBytes:0,firstPesBytes:0,maxPesBytes:0,continuityErrors:0,adtsCandidates:0,confirmedRuns:0,confirmedFrames:0,truncatedFrames:0,unframedBytes:0,firstFrameLength:0,lastFrameLength:0,profile:-1,rateIndex:-1,channels:-1}
    if type(data) <> "roByteArray" and type(data) <> "roArray" then return result
    if data.count() < 188*4 or data.count() > 4194304 or audioPid < 1 then return result
    audio = CreateObject("roByteArray")
    collecting = false
    previousCounter = -1
    currentPesBytes = 0
    for offset = 0 to data.count()-188 step 188
        packet = rpHdOnlineTsPacket(data,offset)
        if packet <> invalid and packet.pid = audioPid and not packet.scrambled
            result.tsPackets++
            continuityOk = true
            if previousCounter >= 0 and packet.counter <> ((previousCounter+1) mod 16)
                result.continuityErrors++
                continuityOk = false
            end if
            previousCounter = packet.counter
            if packet.pusi
                if currentPesBytes > 0
                    if result.pesStarts = 1 then result.firstPesBytes = currentPesBytes
                    if currentPesBytes > result.maxPesBytes then result.maxPesBytes = currentPesBytes
                end if
                currentPesBytes = 0
                collecting = false
                cursor = packet.payloadAt
                if cursor+9 <= packet.endAt
                    if data[cursor] = 0 and data[cursor+1] = 0 and data[cursor+2] = 1
                        streamId = orbitInteger(data[cursor+3],255,-1)
                        headerLength = orbitInteger(data[cursor+8],255,-1)
                        if streamId >= 192 and streamId <= 223 and headerLength >= 0 and cursor+9+headerLength <= packet.endAt
                            cursor += 9+headerLength
                            collecting = true
                            result.pesStarts++
                        end if
                    end if
                end if
            else if not continuityOk
                collecting = false
            end if
            if collecting
                cursor = packet.payloadAt
                if packet.pusi then cursor += 9+orbitInteger(data[packet.payloadAt+8],255,0)
                while cursor < packet.endAt
                    audio.push(data[cursor])
                    cursor++
                    currentPesBytes++
                    result.pesPayloadBytes++
                end while
            end if
        end if
    end for
    if currentPesBytes > 0
        if result.pesStarts = 1 then result.firstPesBytes = currentPesBytes
        if currentPesBytes > result.maxPesBytes then result.maxPesBytes = currentPesBytes
    end if
    if audio.count() < 7 then return result
    cursor = 0
    confirmedBytes = 0
    while cursor+7 <= audio.count()
        frame = rpHdOnlineTsAdtsHeader(audio,cursor)
        if frame.valid and cursor+frame.length <= audio.count()
            result.adtsCandidates++
            nextOffset = cursor+frame.length
            nextFrame = rpHdOnlineTsAdtsHeader(audio,nextOffset)
            if nextFrame.valid and nextOffset+nextFrame.length <= audio.count() and nextFrame.profile = frame.profile and nextFrame.rateIndex = frame.rateIndex and nextFrame.channels = frame.channels
                runFrames = 2
                runEnd = nextOffset+nextFrame.length
                while runEnd+7 <= audio.count()
                    following = rpHdOnlineTsAdtsHeader(audio,runEnd)
                    if not following.valid or runEnd+following.length > audio.count() or following.profile <> frame.profile or following.rateIndex <> frame.rateIndex or following.channels <> frame.channels then exit while
                    runFrames++
                    runEnd += following.length
                end while
                result.confirmedRuns++
                result.confirmedFrames += runFrames
                if result.confirmedRuns = 1
                    result.firstFrameLength = frame.length
                    result.profile = frame.profile
                    result.rateIndex = frame.rateIndex
                    result.channels = frame.channels
                end if
                result.lastFrameLength = nextFrame.length
                confirmedBytes += runEnd-cursor
                cursor = runEnd
            else
                if nextOffset+7 > audio.count() and nextOffset < audio.count() then result.truncatedFrames++
                cursor++
            end if
        else
            if frame.valid and cursor+frame.length > audio.count() then result.truncatedFrames++
            cursor++
        end if
    end while
    result.unframedBytes = audio.count()-confirmedBytes
    result.valid = result.confirmedFrames >= 2
    return result
end function


' Optional TVmaze enrichment for series only. Provider IDs and playback fields are never changed.
function rpHdTvmazeEnrichAnswer(answer as object, request as object, fetcher as dynamic) as object
    if not answer.ok then return answer
    operation = orbitText(request.operation,20)
    item = invalid
    if operation = "meta" and type(answer.item) = "roAssociativeArray"
        item = answer.item
    else if operation = "episodes" and type(request.item) = "roAssociativeArray"
        item = request.item
    end if
    if type(item) <> "roAssociativeArray" then return answer
    if orbitText(item.kind,16) <> "series" then return answer
    title = orbitText(item.title,200).trim()
    if title = "" then return answer

    providerName = orbitText(item.provider,32)
    cacheKey = lcase(title.trim())
    searchTitle = title
    ' Translate known provider-localized titles to their canonical TVmaze names.
    ' These aliases affect lookup only; provider titles and playback IDs stay untouched.
    if cacheKey = "hora de aventura" then searchTitle = "Adventure Time"
    if cacheKey = "merlina" or cacheKey = "merlina (2022)" then searchTitle = "Wednesday"
    if cacheKey = "juego de tronos" or cacheKey = "juego de tronos (2011)" then searchTitle = "Game of Thrones"
    if cacheKey = "bojack horseman (2014)" then searchTitle = "BoJack Horseman"
    if instr(1,cacheKey,"cÃ³mo conoc") = 1 or instr(1,cacheKey,"cómo conoc") = 1 or instr(1,cacheKey,"como conoc") = 1 then searchTitle = "How I Met Your Mother"
    if cacheKey = "el juego del calamar" then searchTitle = "Squid Game"
    if instr(1,cacheKey,"mythic quest:") = 1 then searchTitle = "Mythic Quest"
    if cacheKey = "el juego de la muerte (2023)" or cacheKey = "el juego de la muerte" then searchTitle = "Death's Game"
    if cacheKey = "el juego de gracie darling" then searchTitle = "Playing Gracie Darling"
    if cacheKey = "phony: la otra madre" then searchTitle = "Phony"
    if cacheKey = "chicago en llamas" then searchTitle = "Chicago Fire"
    if cacheKey = "estamos muertos" or cacheKey = "estamos muertos (2022)" then searchTitle = "All of Us Are Dead"
    if cacheKey = "reacher (2022)" then searchTitle = "Reacher"
    if cacheKey = "frasier (1993)" then searchTitle = "Frasier"
    if cacheKey = "el rey de queens" then searchTitle = "The King of Queens"
    if cacheKey = "asesinato para principiantes" or cacheKey = "asesinato para principiantes (2024)" then searchTitle = "A Good Girl's Guide to Murder"
    if cacheKey = "2 chicas quebradas" then searchTitle = "2 Broke Girls"
    if cacheKey = "el adn del delito" then searchTitle = "DNA do Crime"
    if cacheKey = "anatomía según grey" then searchTitle = "Grey's Anatomy"
    if cacheKey = "buscando a wanda" then searchTitle = "Where's Wanda?"
    if cacheKey = "coraje, el perro cobarde" or cacheKey = "coraje, el perro cobarde (1999)" then searchTitle = "Courage the Cowardly Dog"
    if cacheKey = "el intercambio" then searchTitle = "Bytet"
    if cacheKey = "breaking bad (2008)" then searchTitle = "Breaking Bad"
    if cacheKey = "the blacklist (2013)" then searchTitle = "The Blacklist"
    if cacheKey = "marshals: una historia de yellowstone (2026)" then searchTitle = "Marshals"
    if cacheKey = "la lista terminal (2022)" then searchTitle = "The Terminal List"
    if cacheKey = "visionquest (2026)" then searchTitle = "VisionQuest"
    if cacheKey = "2 chicas quebradas (2011)" then searchTitle = "2 Broke Girls"
    aliasLookup = searchTitle <> title
    cache = invalid
    print "[RokuPlus tvmaze] start op="; operation; " provider="; providerName; " title="; title
    if type(request.tvmazeCache) = "roAssociativeArray"
        if orbitText(request.tvmazeCache.key,200) = cacheKey
            if type(request.tvmazeCache.episodes) = "roArray"
                cache = request.tvmazeCache
            end if
        end if
    end if

    if cache = invalid
        ' Search by the source's series title; TVmaze is public and needs no API key.
        searchUrl = "https://api.tvmaze.com/search/shows?q="+rpHdOnlineEscape(searchTitle)
        if searchTitle <> title then print "[RokuPlus tvmaze] search_alias local="; title; " query="; searchTitle
        rpHdTaskBeginSlice(3)
        response = fetcher(searchUrl,"tvmaze","https://www.tvmaze.com/")
        if not response.ok
            print "[RokuPlus tvmaze] search_failed provider="; providerName; " title="; title
            return answer
        end if
        matches = ParseJson(response.body)
        if type(matches) <> "roArray"
            print "[RokuPlus tvmaze] search_invalid_json title="; title
            return answer
        end if
        print "[RokuPlus tvmaze] search_results="; matches.count(); " title="; title
        candidateLogCount = 0
        for each candidateMatch in matches
            if candidateLogCount < 5 and type(candidateMatch) = "roAssociativeArray" and type(candidateMatch.show) = "roAssociativeArray"
                candidateLogCount++
                print "[RokuPlus tvmaze] candidate title="; orbitText(candidateMatch.show.name,200); " score="; orbitText(candidateMatch.score,30)
            end if
        end for
        if matches.count() = 0 and instr(1,lcase(title)," y ") > 0
            alternateTitle = CreateObject("roRegex"," y ","i").replace(title," and ")
            alternateUrl = "https://api.tvmaze.com/search/shows?q="+rpHdOnlineEscape(alternateTitle)
            rpHdTaskBeginSlice(2)
            alternateResponse = fetcher(alternateUrl,"tvmaze","https://www.tvmaze.com/")
            if alternateResponse.ok then matches = ParseJson(alternateResponse.body)
        end if
        if type(matches) <> "roArray" or matches.count() = 0 then return answer

        show = invalid
        matchMode = "fallback"
        for each match in matches
            if type(match) = "roAssociativeArray" and type(match.show) = "roAssociativeArray"
                candidate = match.show
                candidateName = lcase(orbitText(candidate.name,200).trim()).replace("Â·","-").replace("·","-")
                if candidateName = lcase(searchTitle)
                    show = candidate
                    matchMode = "exact"
                    exit for
                end if
            end if
        end for
        ' A configured canonical alias must resolve exactly; never attach a nearby
        ' but unrelated show just because it ranked first in TVmaze search.
        if show = invalid and aliasLookup
            print "[RokuPlus tvmaze] alias_exact_match_missing local="; title; " query="; searchTitle
            return answer
        end if
        ' Never attach a merely similar result to a different series. Localized
        ' provider titles must be mapped explicitly above to a canonical exact title.
        if show = invalid
            print "[RokuPlus tvmaze] exact_show_match_missing local="; title; " query="; searchTitle
            return answer
        end if
        if type(show) <> "roAssociativeArray"
            print "[RokuPlus tvmaze] show_not_found title="; title
            return answer
        end if
        showId = orbitInteger(show.id,999999999)
        if showId < 1
            print "[RokuPlus tvmaze] invalid_show_id title="; title
            return answer
        end if
        print "[RokuPlus tvmaze] selected_show="; orbitText(show.name,200); " show_id="; showId; " match="; matchMode

        poster = ""
        image = show.image
        if type(image) = "roAssociativeArray" then poster = orbitText(image.medium,1000)
        summary = rpHdTvmazeText(show.summary)

        rpHdTaskBeginSlice(2)
        episodesUrl = "https://api.tvmaze.com/shows/"+showId.toStr()+"/episodes"
        episodeResponse = fetcher(episodesUrl,"tvmaze","https://www.tvmaze.com/")
        if not episodeResponse.ok
            print "[RokuPlus tvmaze] episodes_fetch_failed show_id="; showId
            return answer
        end if
        tvEpisodes = ParseJson(episodeResponse.body)
        if type(tvEpisodes) <> "roArray"
            print "[RokuPlus tvmaze] episodes_invalid_json show_id="; showId
            return answer
        end if
        print "[RokuPlus tvmaze] tvmaze_episode_count="; tvEpisodes.count(); " show_id="; showId

        ' Keep only one series in the Scene cache to bound retained memory.
        cache = {key:cacheKey,showId:showId,poster:poster,summary:summary,episodes:tvEpisodes}
    else
        showId = orbitInteger(cache.showId,999999999)
        poster = orbitText(cache.poster,1000)
        summary = orbitText(cache.summary,12000)
        tvEpisodes = cache.episodes
    end if

    answer.tvmazeCache = cache
    print "[RokuPlus tvmaze] cache_ready show_id="; showId; " provider="; providerName
    if poster <> "" and operation = "meta" then answer.item.poster = poster
    if summary <> "" and operation = "meta" then answer.item.description = summary

    if operation = "meta"
        if type(answer.item.seasons) = "roArray"
            for i = 0 to answer.item.seasons.count()-1
                answer.item.seasons[i] = rpHdTvmazeEnrichSeason(answer.item.seasons[i],tvEpisodes)
            end for
        end if
    else if operation = "episodes"
        if type(answer.seasons) = "roArray"
            for i = 0 to answer.seasons.count()-1
                answer.seasons[i] = rpHdTvmazeEnrichSeason(answer.seasons[i],tvEpisodes)
            end for
        end if
    end if
    return answer
end function

function rpHdTvmazeEnrichSeason(season as object, tvEpisodes as object) as object
    if type(season) <> "roAssociativeArray" then return season
    seasonNumber = orbitInteger(season.number,999,-1)
    if seasonNumber < 0 or type(season.episodes) <> "roArray" then return season
    matchedCount = 0
    renamedCount = 0
    imageCount = 0
    checkedCount = 0
    for each localEpisode in season.episodes
        if type(localEpisode) = "roAssociativeArray"
            episodeNumber = orbitInteger(localEpisode.episode,9999)
            if episodeNumber > 0
                checkedCount++
                foundMatch = false
                for each tvEpisode in tvEpisodes
                    if type(tvEpisode) = "roAssociativeArray"
                        if orbitInteger(tvEpisode.season,999,-1) = seasonNumber and orbitInteger(tvEpisode.number,9999) = episodeNumber
                            foundMatch = true
                            matchedCount++
                            episodeTitle = orbitText(tvEpisode.name,200)
                            existingTitle = lcase(orbitText(localEpisode.title,200).trim())
                            genericTitle = existingTitle = "" or existingTitle = "episodio "+episodeNumber.toStr() or existingTitle = "episode "+episodeNumber.toStr()
                            if not genericTitle
                                genericTitle = CreateObject("roRegex","(temporada|season)\s*[0-9]+\s*[-:·, ]*\s*(cap[ií]tulo|episodio|episode)\s*[0-9]+$","i").isMatch(existingTitle)
                            end if
                            if not genericTitle
                                genericTitle = CreateObject("roRegex","^s[0-9]{1,3}e[0-9]{1,4}$","i").isMatch(existingTitle)
                            end if
                            if checkedCount <= 12
                                print "[RokuPlus tvmaze] episode_title S"; seasonNumber; "E"; episodeNumber; " local="; orbitText(localEpisode.title,200); " tvmaze="; episodeTitle; " generic="; genericTitle
                            end if
                            tvmazeGenericTitle = CreateObject("roRegex","^(episodio|episode|cap[ií]tulo|chapter)[ ]*[0-9]+$","i").isMatch(episodeTitle.trim())
                            if episodeTitle <> "" and genericTitle and not tvmazeGenericTitle
                                localEpisode.title = episodeTitle
                                renamedCount++
                            else if tvmazeGenericTitle and checkedCount <= 12
                                print "[RokuPlus tvmaze] skip_generic_tvmaze_title S"; seasonNumber; "E"; episodeNumber; " title="; episodeTitle
                            end if
                            episodeDescription = rpHdTvmazeText(tvEpisode.summary)
                            if episodeDescription <> "" then localEpisode.description = episodeDescription
                            episodeImage = tvEpisode.image
                            if type(episodeImage) = "roAssociativeArray"
                                still = orbitText(episodeImage.original,1000)
                                if still = "" then still = orbitText(episodeImage.medium,1000)
                                if still <> ""
                                    localEpisode.poster = still
                                    localEpisode.background = still
                                    imageCount++
                                end if
                            end if
                            exit for
                        end if
                    end if
                end for
                if not foundMatch and checkedCount <= 12
                    print "[RokuPlus tvmaze] no_episode_match local=S"; seasonNumber; "E"; episodeNumber
                end if
                if not foundMatch and seasonNumber = 8
                    print "[RokuPlus tvmaze] unmatched_detail S"; seasonNumber; "E"; episodeNumber; " title="; orbitText(localEpisode.title,200)
                end if
            end if
        end if
    end for
    print "[RokuPlus tvmaze] season_result=S"; seasonNumber; " local="; checkedCount; " matched="; matchedCount; " renamed="; renamedCount; " images="; imageCount
    return season
end function

function rpHdTvmazeText(value as dynamic) as string
    text = orbitText(value,12000)
    text = CreateObject("roRegex","<[^>]+>","s").replaceAll(text," ")
    for each pair in [["&amp;","&"],["&quot;",chr(34)],["&#039;","'"],["&#39;","'"],["&nbsp;"," "],["&#8217;","'"],["&#8211;","-"],["&#8212;","-"]]
        text = text.replace(pair[0],pair[1])
    end for
    return left(CreateObject("roRegex","\s+","").replaceAll(text," ").trim(),2400)
end function
