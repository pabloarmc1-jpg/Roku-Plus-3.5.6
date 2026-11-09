' Guest subtitle search adapter. No account or API key is required.
' Provider documentation: https://subtitles.website/docs/
sub init()
    m.top.functionName = "runSubtitleSearch"
end sub

sub runSubtitleSearch()
    answer = {ok:false,operation:m.top.operation,items:[],subtitleText:"",message:"No se pudo consultar el catálogo de subtítulos."}
    operation = m.top.operation
    if operation = "search"
        title = left(m.top.title,160).trim()
        imdb = left(m.top.imdbId,24).trim()
        language = lcase(left(m.top.language,8).trim())
        if language = "" then language = "es"
        if title = "" and imdb = ""
            answer.message = "No hay título ni IMDb para buscar subtítulos."
            m.top.result = answer
            return
        end if
        transfer = subtitleTransfer()
        endpoint = "https://subtitles.website/strapi/api/search/subtitles?"
        if imdb <> ""
            if not CreateObject("roRegex","^tt[0-9]{5,12}$","").isMatch(imdb)
                imdb = ""
            end if
        end if
        if imdb <> ""
            endpoint += "imdb=" + transfer.Escape(imdb)
        else
            endpoint += "title=" + transfer.Escape(title)
        end if
        endpoint += "&language=" + transfer.Escape(language) + "&format=srt"
        body = subtitleGet(transfer,endpoint)
        if GetInterface(body,"ifString") = invalid or len(body) = 0
            answer.message = "El servicio de subtítulos no respondió."
            m.top.result = answer
            return
        end if
        parsed = ParseJson(body)
        if type(parsed) <> "roAssociativeArray"
            answer.message = "La respuesta del servicio no tiene un formato válido."
            m.top.result = answer
            return
        end if
        if type(parsed.data) <> "roArray"
            answer.message = "La respuesta del servicio no incluye resultados."
            m.top.result = answer
            return
        end if
        for each entry in parsed.data
            if answer.items.count() >= 12 then exit for
            if type(entry) = "roAssociativeArray"
                id = entry.id
                release = entry.release
                if GetInterface(id,"ifString") <> invalid and CreateObject("roRegex","^[a-zA-Z0-9_-]{6,80}$","").isMatch(id)
                    if GetInterface(release,"ifString") <> invalid
                        label = left(release,100)
                        lang = language
                        if type(entry.language) = "roAssociativeArray"
                            if GetInterface(entry.language.code,"ifString") <> invalid then lang = entry.language.code
                        end if
                        answer.items.push({id:id,label:label,language:lang})
                    end if
                end if
            end if
        end for
        answer.ok = true
        answer.message = ""
        if answer.items.count() = 0 then answer.message = "No se encontraron subtítulos en español para este título."
        print "[RokuPlus subtitles-online] search results="; answer.items.count()
        m.top.result = answer
        return
    else if operation = "download"
        subtitleId = m.top.subtitleId
        if GetInterface(subtitleId,"ifString") = invalid or not CreateObject("roRegex","^[a-zA-Z0-9_-]{6,80}$","").isMatch(subtitleId)
            answer.message = "El identificador del subtítulo no es válido."
            m.top.result = answer
            return
        end if
        transfer = subtitleTransfer()
        endpoint = "https://subtitles.website/strapi/api/search/download/" + subtitleId
        body = subtitleGet(transfer,endpoint)
        if GetInterface(body,"ifString") = invalid or len(body) = 0
            answer.message = "No se pudo obtener el enlace del subtítulo."
            m.top.result = answer
            return
        end if
        parsed = ParseJson(body)
        if type(parsed) <> "roAssociativeArray"
            answer.message = "El servicio no entregó un archivo de subtítulos."
            m.top.result = answer
            return
        end if
        if GetInterface(parsed.download_url,"ifString") = invalid
            answer.message = "El servicio no entregó un archivo de subtítulos."
            m.top.result = answer
            return
        end if
        path = parsed.download_url
        if left(path,9) <> "/uploads/" or instr(1,path,"..") > 0 or instr(1,path,chr(92)) > 0
            answer.message = "El enlace de descarga no es válido."
            m.top.result = answer
            return
        end if
        subtitleUrl = "https://subtitles.website/strapi" + path
        transfer = subtitleTransfer()
        subtitleText = subtitleGet(transfer,subtitleUrl)
        if GetInterface(subtitleText,"ifString") = invalid or len(subtitleText) = 0 or len(subtitleText) > 2097152
            answer.message = "El archivo SRT está vacío o supera el tamaño permitido."
            m.top.result = answer
            return
        end if
        if instr(1,subtitleText,"-->") = 0
            answer.message = "El archivo descargado no parece ser un SRT válido."
            m.top.result = answer
            return
        end if
        answer.ok = true
        answer.subtitleText = subtitleText
        answer.message = ""
        print "[RokuPlus subtitles-online] download bytes="; len(subtitleText)
        m.top.result = answer
        return
    end if
    answer.message = "Operación de subtítulos desconocida."
    m.top.result = answer
end sub

function subtitleTransfer() as object
    transfer = CreateObject("roUrlTransfer")
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.setTimeout(12000)
    transfer.addHeader("User-Agent","RokuPlus/1.0")
    transfer.addHeader("Accept","application/json,text/plain,*/*")
    return transfer
end function

function subtitleGet(transfer as object, endpoint as string) as dynamic
    if left(endpoint,37) <> "https://subtitles.website/strapi/api/" and left(endpoint,41) <> "https://subtitles.website/strapi/uploads/"
        if endpoint <> "https://subtitles.website/strapi/api/search/subtitles?" then return invalid
    end if
    transfer.setUrl(endpoint)
    return transfer.getToString()
end function
