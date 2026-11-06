' Artwork references and explicitly dated public popularity reference.
' Popularity is NOT live viewer counts or telemetry from Roku Plus users.
function rpLiveArtworkId(item as dynamic) as string
    if type(item) <> "roAssociativeArray" then return ""
    value = orbitText(item.id,180)
    if left(value,5) = "live:" then value = mid(value,6)
    return value.split("@")[0]
end function

function rpLiveApplyArtwork(items as dynamic, logos as dynamic) as object
    result = []
    if type(items) <> "roArray" then return result
    for each item in items
        copy = {}
        for each field in item
            copy[field] = item[field]
        end for
        localArt = copy.poster = "pkg:/images/ui/live-program-granja.png" or copy.poster = "pkg:/images/ui/live-program-casa.png"
        if not localArt and orbitHttpsUrl(copy.poster) = "" and type(logos) = "roAssociativeArray"
            copy.poster = orbitHttpsUrl(logos[rpLiveArtworkId(copy)])
        end if
        result.push(copy)
    end for
    return result
end function

function rpLivePopularityRank(item as dynamic) as integer
    ' ENCCA 2024, IFT: channels watched most frequently, URBAN respondents.
    ' This dated reference covers these Mexican broadcasters only.
    if type(item) <> "roAssociativeArray" then return 0
    if item.countryCode <> "mx" then return 0
    key = lcase(rpLiveArtworkId(item))
    ranks = {"lasestrellas.mx":1,"canal5.mx":2,"aztecauno.mx":3,"azteca7.mx":4,"forotv.mx":5,"nmasforo.mx":5,"canal6.mx":6,"multimedios.mx":6,"adn40.mx":7,"nu9ve.mx":8,"imagen television.mx":9,"imagentelevision.mx":9,"imagentv.mx":9,"canalonce.mx":10}
    if ranks.doesExist(key) then return ranks[key]
    return 0
end function

function rpLivePopularityOrder(items as dynamic) as object
    result = []
    if type(items) <> "roArray" then return result
    buckets = [[],[],[],[],[],[],[],[],[],[],[]]
    for each item in items
        buckets[rpLivePopularityRank(item)].push(item)
    end for
    for rank = 1 to 10
        for each item in buckets[rank]
            result.push(item)
        end for
    end for
    for each item in buckets[0]
        result.push(item)
    end for
    return result
end function

function rpLivePopularityNote() as string
    return "Favoritos primero · Popularidad de referencia: México urbano, ENCCA 2024. Resto sin ranking."
end function
