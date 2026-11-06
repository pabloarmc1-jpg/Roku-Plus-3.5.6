' Local live-channel preferences. Persist only stable IDs, never media URLs,
' headers, cookies, resolved links or the television's playback position.

' Regional playlists may include channels originating outside the 21-country
' setup selector (for example US channels distributed in Latin America).
function rpLiveOriginCountry(value as dynamic) as string
    if GetInterface(value,"ifString") = invalid then return ""
    if not CreateObject("roRegex","^[A-Za-z]{2}$","").isMatch(value) then return ""
    return lcase(value)
end function

function rpLiveSourceIdValid(value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    if len(value) = 0 or len(value) > 86 then return false
    return CreateObject("roRegex","^(live|reality):[A-Za-z0-9._:@ -]+$","").isMatch(value)
end function

function rpLiveFavoriteKey(item as dynamic) as string
    if type(item) <> "roAssociativeArray" then return ""
    ' A parser-generated playlist index can identify a different channel after
    ' its next refresh. Such temporary IDs must never become saved favorites.
    if item.favoriteIdStable = false then return ""
    country = rpLiveOriginCountry(item.countryCode)
    if country = "" then return ""
    if not rpLiveSourceIdValid(item.id) then return ""
    ' Reversible ASCII hex preserves case and punctuation. Removing punctuation
    ' or lowercasing channel IDs would merge otherwise distinct channels.
    digits = "0123456789abcdef"
    encoded = ""
    for n = 1 to len(item.id)
        code = asc(mid(item.id,n,1))
        encoded += mid(digits,(code \ 16)+1,1) + mid(digits,(code mod 16)+1,1)
    end for
    return country+":v1:"+encoded
end function

function rpLiveFavoriteKeyValid(value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    if len(value) < 8 or len(value) > 180 then return false
    if rpLiveOriginCountry(left(value,2)) = "" then return false
    if left(value,2) <> lcase(left(value,2)) then return false
    if mid(value,3,4) <> ":v1:" then return false
    encoded = mid(value,7)
    if len(encoded) mod 2 <> 0 then return false
    if not CreateObject("roRegex","^[0-9a-f]+$","").isMatch(encoded) then return false
    decoded = ""
    digits = "0123456789abcdef"
    for n = 1 to len(encoded) step 2
        high = instr(1,digits,mid(encoded,n,1))-1
        low = instr(1,digits,mid(encoded,n+1,1))-1
        code = high*16+low
        if code < 32 or code > 126 then return false
        decoded += chr(code)
    end for
    return rpLiveSourceIdValid(decoded)
end function

function rpLiveNormalizeFavorites(raw as dynamic) as object
    keys = []
    if type(raw) <> "roArray" then return keys
    seen = {}
    for each value in raw
        if rpLiveFavoriteKeyValid(value)
            if not seen.doesExist(value)
                keys.push(value)
                seen[value] = true
                if keys.count() = 150 then exit for
            end if
        end if
    end for
    return keys
end function

function rpLiveIsFavorite(item as dynamic, favorites as dynamic) as boolean
    key = rpLiveFavoriteKey(item)
    if key = "" or type(favorites) <> "roArray" then return false
    for each saved in favorites
        if GetInterface(saved,"ifString") <> invalid
            if saved = key then return true
        end if
    end for
    return false
end function

function rpLiveReadFavoriteRecord(text as dynamic) as object
    result = {valid:false,keys:[]}
    if GetInterface(text,"ifString") = invalid then return result
    if len(text) = 0 or len(text) > 12288 then return result
    text = text.trim()
    if left(text,1) <> "{" or right(text,1) <> "}" then return result
    raw = ParseJson(text)
    if type(raw) <> "roAssociativeArray" then return result
    if GetInterface(raw.version,"ifInt") = invalid then return result
    if raw.version <> 1 or type(raw.keys) <> "roArray" then return result
    keys = rpLiveNormalizeFavorites(raw.keys)
    if keys.count() <> raw.keys.count() then return result
    result.valid = true
    result.keys = keys
    return result
end function

function rpLiveFavoritesFromText(text as dynamic) as object
    return rpLiveReadFavoriteRecord(text).keys
end function

function rpLiveLoadFavorites() as object
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return []
    return rpLiveFavoritesFromText(section.read("liveFavoritesV1"))
end function

function rpLiveStoreFavorites(section as object, keys as dynamic) as boolean
    if type(keys) <> "roArray" then return false
    normalized = rpLiveNormalizeFavorites(keys)
    ' Never silently drop malformed or excess favorites during a commit.
    if keys.count() <> normalized.count() then return false
    payload = FormatJson({version:1,keys:normalized})
    if GetInterface(payload,"ifString") = invalid then return false
    if len(payload) > 12288 then return false
    previousText = section.read("liveFavoritesV1")
    previous = rpLiveReadFavoriteRecord(previousText)
    if section.write("liveFavoritesV1",payload) <> true then return false
    if section.flush() = true then return true
    if previous.valid
        section.write("liveFavoritesV1",previousText)
    else
        section.delete("liveFavoritesV1")
    end if
    section.flush()
    return false
end function

function rpLiveSaveFavorites(keys as dynamic) as boolean
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    return rpLiveStoreFavorites(section,keys)
end function

function rpLiveFavoritesToggle(favorites as dynamic, item as dynamic) as object
    keys = rpLiveNormalizeFavorites(favorites)
    result = {ok:false,keys:keys,added:false,message:""}
    key = rpLiveFavoriteKey(item)
    if key = ""
        result.message = "Este canal no tiene un identificador compatible para guardarlo."
        return result
    end if
    kept = []
    found = false
    for each saved in keys
        if saved = key then found = true else kept.push(saved)
    end for
    if found
        result.ok = true
        result.keys = kept
        return result
    end if
    if keys.count() >= 150
        result.message = "Puedes guardar hasta 150 canales favoritos. Quita uno para añadir otro."
        return result
    end if
    candidate = []
    for each saved in keys
        candidate.push(saved)
    end for
    candidate.push(key)
    if len(FormatJson({version:1,keys:candidate})) > 12288
        result.message = "La lista de favoritos está llena. Quita uno para añadir otro."
        return result
    end if
    result.ok = true
    result.keys = candidate
    result.added = true
    return result
end function

function rpLiveChannelIdentity(item as dynamic) as string
    if type(item) <> "roAssociativeArray" then return ""
    if GetInterface(item.id,"ifString") = invalid then return ""
    if GetInterface(item.url,"ifString") = invalid then return ""
    country = rpLiveOriginCountry(item.countryCode)
    if country = "" or item.id = "" then return ""
    ' Length delimiters avoid ambiguous separators; retained only in memory.
    return country+":"+len(item.id).toStr()+":"+item.id+":"+len(item.url).toStr()+":"+item.url
end function

function rpLiveMergeChannels(countryChannels as dynamic, realities as dynamic) as object
    merged = []
    seen = {}
    seen.setModeCaseSensitive()
    for each input in [realities,countryChannels]
        if type(input) = "roArray"
            for each item in input
                identity = rpLiveChannelIdentity(item)
                if identity <> "" and not seen.doesExist(identity)
                    merged.push(item)
                    seen[identity] = true
                end if
            end for
        end if
    end for
    return merged
end function

function rpLiveVisibleChannels(allItems as dynamic, favorites as dynamic, filter as dynamic, countryCode as dynamic) as object
    first = []
    rest = []
    if type(allItems) <> "roArray" then return first
    if GetInterface(filter,"ifInt") = invalid then return first
    if filter < 0 or filter > 3 then return first
    country = orbitCountryCode(countryCode)
    seen = {}
    seen.setModeCaseSensitive()
    ' Resolve membership once rather than scanning all saved favorites for
    ' every channel in a large regional playlist. Keys are already normalized
    ' at the storage boundary; unexpected values cannot match a generated key.
    favoriteSet = {}
    favoriteSet.setModeCaseSensitive()
    if type(favorites) = "roArray"
        for each saved in favorites
            if GetInterface(saved,"ifString") <> invalid
                if len(saved) <= 180 then favoriteSet[saved] = true
            end if
        end for
    end if
    hasFavorites = favoriteSet.count() > 0
    for each item in allItems
        identity = rpLiveChannelIdentity(item)
        if identity <> "" and not seen.doesExist(identity)
            seen[identity] = true
            favorite = false
            if hasFavorites
                key = rpLiveFavoriteKey(item)
                if key <> "" then favorite = favoriteSet.doesExist(key)
            end if
            include = filter = 0 or filter = 2
            if filter = 1 then include = country <> "" and rpLiveOriginCountry(item.countryCode) = country
            if filter = 3 then include = favorite
            if include
                if favorite then first.push(item) else rest.push(item)
            end if
        end if
    end for
    for each item in rest
        first.push(item)
    end for
    return first
end function

' Search operates only on visible channel names/subtitles. Never inspect media
' URLs, headers, favorite keys, provider IDs or any saved credential-like data.
' This returns a new array in the supplied order, preserving favorite priority.
function rpLiveSearchChannels(items as dynamic, query as dynamic) as object
    result = []
    if type(items) <> "roArray" then return result
    rules = {
        accents:[["á","Á","a"],["é","É","e"],["í","Í","i"],["ó","Ó","o"],["ú","Ú","u"],["ü","Ü","u"],["ñ","Ñ","n"],["ã","Ã","a"],["õ","Õ","o"],["ç","Ç","c"]]
        parts:CreateObject("roRegex","[a-z]+|[0-9]+","")
        numeric:CreateObject("roRegex","^[0-9]+$","")
    }
    normalized = rpLiveSearchText(query,80,rules)
    tokens = []
    if normalized <> ""
        for each word in normalized.split(" ")
            if word <> "" then tokens.push({text:word,numeric:rules.numeric.isMatch(word)})
        end for
    end if
    for each item in items
        if type(item) = "roAssociativeArray"
            if tokens.count() = 0
                result.push(item)
            else
                title = ""
                subtitle = ""
                if GetInterface(item.title,"ifString") <> invalid then title = left(item.title,256)
                if GetInterface(item.subtitle,"ifString") <> invalid then subtitle = left(item.subtitle,256)
                haystack = rpLiveSearchText(title+" "+subtitle,513,rules)
                match = true
                for each word in tokens
                    if word.numeric
                        ' A request for Canal 5 must not silently match Canal 50.
                        found = instr(1," "+haystack+" "," "+word.text+" ") > 0
                    else
                        found = instr(1,haystack,word.text) > 0
                    end if
                    if not found
                        match = false
                        exit for
                    end if
                end for
                if match then result.push(item)
            end if
        end if
    end for
    return result
end function

function rpLiveSearchText(value as dynamic, maximum as integer, rules as object) as string
    if GetInterface(value,"ifString") = invalid then return ""
    text = lcase(left(value,maximum))
    for each pair in rules.accents
        text = text.replace(pair[0],pair[2]).replace(pair[1],pair[2])
    end for
    normalized = ""
    ' Matching letter and digit runs avoids replacement backreference syntax,
    ' whose behavior differs between Roku and the offline BrightScript runner.
    for each part in rules.parts.matchAll(text)
        if part.count() > 0 then normalized += part[0]+" "
    end for
    return normalized.trim()
end function
