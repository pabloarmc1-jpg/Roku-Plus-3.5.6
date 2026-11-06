' CineCalidad movie-only public HTML adapter. Parse bounded text, never run scripts.
' Text/entity helpers are shared with the independently parsed SeriesMetro pages.
function rpHdCinecalidadEndpoint(operation as string, args as dynamic) as string
    if type(args) <> "roAssociativeArray" then return ""
    base = "https://www.cinecalidad.vg/"
    if operation = "meta" or operation = "player"
        slug = rpHdCinecalidadSlug(args.slug)
        if slug = "" then return ""
        return base+"pelicula/"+slug+"/"
    end if
    if args.kind <> "movie" then return ""
    if operation <> "catalog" and operation <> "search" then return ""
    page = orbitInteger(args.page,10000,1)
    if page < 1 then page = 1
    if page > 1 then base += "page/"+page.toStr()+"/"
    query = rpHdOnlineEscape(args.query)
    if operation = "search" and query = "" then return ""
    if query <> "" then base += "?s="+query
    return base
end function

function rpHdCinecalidadSlug(value as dynamic) as string
    text = orbitText(value,201)
    if not CreateObject("roRegex","^[a-z0-9][a-z0-9-]{0,199}$","").isMatch(text) then return ""
    return text
end function

function rpHdCinecalidadArt(value as dynamic) as string
    url = orbitHttpsUrl(value)
    match = CreateObject("roRegex","^https://image\.tmdb\.org/t/p/(?:original|w[0-9]{2,4})/([a-zA-Z0-9_-]+\.(?:jpg|jpeg|png|webp))$","").match(url)
    if match.count() < 2 then return ""
    return "https://image.tmdb.org/t/p/w500/"+match[1]
end function

function rpHdCinecalidadCatalog(raw as dynamic, kind as string, page as integer) as object
    answer = {items:[],hasMore:false,nextPage:page+1,total:0}
    if kind <> "movie" then return answer
    text = orbitText(raw,2097153)
    if len(text) > 2097152 then return answer
    blocks = CreateObject("roRegex","<article\b","i").split(text)
    seen = {}
    count = blocks.count()
    if count > 401 then count = 401
    quote = chr(34)+"'"
    for i = 1 to count-1
        block = blocks[i]
        slug = rpHdSeriesmetroMatch(block,"href\s*=\s*["+quote+"]https://www\.cinecalidad\.vg/pelicula/([a-z0-9-]+)/["+quote+"]")
        slug = rpHdCinecalidadSlug(slug)
        if slug <> "" and not seen.doesExist(slug)
            title = rpHdSeriesmetroText(rpHdSeriesmetroMatch(block,"<h2\b[^>]*>(.*?)</h2>"),200)
            if title = "" then title = rpHdSeriesmetroText(rpHdSeriesmetroMatch(block,"<span\b[^>]*class\s*=\s*["+quote+"]sr-only["+quote+"][^>]*>(.*?)</span>"),200)
            image = rpHdSeriesmetroMatch(block,"<img\b([^>]+)>")
            poster = rpHdCinecalidadArt(rpHdSeriesmetroAttr(image,"data-src"))
            if poster = "" then poster = rpHdCinecalidadArt(rpHdSeriesmetroAttr(image,"src"))
            year = rpHdSeriesmetroMatch(block,"<div\b[^>]*>\s*((?:19|20)[0-9]{2})\s*</div>")
            description = rpHdSeriesmetroText(rpHdSeriesmetroMatch(block,"<p\b[^>]*class\s*=\s*["+quote+"][^"+quote+"]*text-sm[^"+quote+"]*["+quote+"][^>]*>(.*?)</p>"))
            if title <> ""
                answer.items.push({
                    id:"hdo-cinecalidad-"+slug,imdbId:"",kind:"movie",library:"hd-online"
                    provider:"cinecalidad",providerId:slug,providerSlug:slug,title:title
                    description:description,poster:poster,background:poster,year:year,runtime:0,language:"",seasons:[]
                })
                seen[slug] = true
            end if
        end if
        if answer.items.count() >= 20 then exit for
    end for
    nextPath = "https://www.cinecalidad.vg/page/"+(page+1).toStr()+"/"
    answer.hasMore = instr(1,text,nextPath) > 0
    return answer
end function

function rpHdCinecalidadMetadata(raw as dynamic, expected as object) as dynamic
    text = orbitText(raw,2097153)
    if len(text) > 2097152 then return invalid
    quote = chr(34)+"'"
    canonicalTag = rpHdSeriesmetroMatch(text,"<link\b([^>]*\brel\s*=\s*["+quote+"]canonical["+quote+"][^>]*)>")
    canonical = rpHdSeriesmetroAttr(canonicalTag,"href")
    if canonical <> rpHdCinecalidadEndpoint("meta",{slug:expected.providerSlug}) then return invalid
    heading = rpHdSeriesmetroText(rpHdSeriesmetroMatch(text,"<h1\b[^>]*>(.*?)</h1>"),200)
    if heading = "" then return invalid
    year = rpHdSeriesmetroMatch(heading,"\(((?:19|20)[0-9]{2})\)")
    title = CreateObject("roRegex","\s*\((?:19|20)[0-9]{2}\)\s*$","").replace(heading,"").trim()
    firstFigure = rpHdSeriesmetroMatch(text,"<figure\b[^>]*>(.*?)</figure>")
    image = rpHdSeriesmetroMatch(firstFigure,"<img\b([^>]+)>")
    poster = rpHdCinecalidadArt(rpHdSeriesmetroAttr(image,"data-src"))
    if poster = "" then poster = expected.poster
    description = rpHdSeriesmetroText(rpHdSeriesmetroMatch(text,"<div\b[^>]*class\s*=\s*["+quote+"][^"+quote+"]*textwidget[^"+quote+"]*["+quote+"][^>]*>\s*<p\b[^>]*>(.*?)</p>"))
    if description = "" then description = expected.description
    if year = "" then year = expected.year
    return {
        id:expected.id,imdbId:"",kind:"movie",library:"hd-online",provider:"cinecalidad"
        providerId:expected.providerSlug,providerSlug:expected.providerSlug,title:title
        description:description,poster:poster,background:poster,year:year,runtime:0,language:"",seasons:[]
    }
end function

function rpHdCinecalidadEmbeds(raw as dynamic) as object
    text = orbitText(raw,2097153)
    result = []
    if len(text) > 2097152 then return result
    quote = chr(34)+"'"
    regex = CreateObject("roRegex","data-src\s*=\s*["+quote+"]([A-Za-z0-9+/=]{20,4096})["+quote+"]","i")
    seen = {}
    for guard = 1 to 60
        found = regex.match(text)
        if found.count() < 2 then exit for
        at = instr(1,text,found[0])
        if at < 1 then exit for
        text = mid(text,at+len(found[0]))
        url = rpHdCinecalidadBase64(found[1])
        allowed = CreateObject("roRegex","^https://vimeos\.net/embed-[a-zA-Z0-9_-]+(?:\.html)?$","").isMatch(url)
        if allowed and not seen.doesExist(url)
            result.push({url:url,language:"Español latino",quality:""})
            seen[url] = true
        end if
        if result.count() >= 6 then exit for
    end for
    return result
end function

' The page encodes ordinary ASCII embed URLs; decode only bounded canonical
' Base64, with no script, recursive decoding or executable byte interpretation.
function rpHdCinecalidadBase64(text as string) as string
    if len(text) < 4 or len(text) > 4096 or len(text) mod 4 <> 0 then return ""
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    result = ""
    for i = 1 to len(text) step 4
        chars = mid(text,i,4)
        a = instr(1,alphabet,mid(chars,1,1))-1
        b = instr(1,alphabet,mid(chars,2,1))-1
        c = instr(1,alphabet,mid(chars,3,1))-1
        d = instr(1,alphabet,mid(chars,4,1))-1
        if a < 0 or b < 0 then return ""
        padding = 0
        if mid(chars,3,1) = "="
            if mid(chars,4,1) <> "=" or i+3 <> len(text) or b mod 16 <> 0 then return ""
            c = 0
            d = 0
            padding = 2
        else if mid(chars,4,1) = "="
            if c < 0 or i+3 <> len(text) or c mod 4 <> 0 then return ""
            d = 0
            padding = 1
        end if
        if c < 0 or d < 0 then return ""
        values = [a*4+(b \ 16)]
        if padding < 2 then values.push((b mod 16)*16+(c \ 4))
        if padding < 1 then values.push((c mod 4)*64+d)
        for each value in values
            if value < 32 or value > 126 then return ""
            result += chr(value)
        end for
    end for
    return result
end function
