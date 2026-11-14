' Local viewing state for Roku Plus. Stores metadata and playback clocks only.
function rpWatchSection(profileId = "p1" as string) as object
    safeId = rpNormalizeProfileId(profileId)
    return CreateObject("roRegistrySection", "RokuPlusWatch_" + safeId)
end function

function rpWatchLoad(profileId = "p1" as string) as object
    section = rpWatchSection(profileId)
    if GetInterface(section, "ifRegistrySection") = invalid then return []
    raw = section.read("stateV1")
    if (GetInterface(raw, "ifString") = invalid or len(raw) = 0) and rpNormalizeProfileId(profileId) = "p1"
        legacy = CreateObject("roRegistrySection", "RokuPlusWatch")
        if GetInterface(legacy, "ifRegistrySection") <> invalid then raw = legacy.read("stateV1")
        if GetInterface(raw, "ifString") <> invalid and len(raw) > 0
            if len(raw) <= 65536 then section.write("stateV1",raw): section.flush()
        end if
    end if
    if GetInterface(raw, "ifString") = invalid or len(raw) = 0 or len(raw) > 65536 then return []
    parsed = ParseJson(raw)
    if type(parsed) <> "roArray" then return []
    ' Registry contents can outlive app upgrades or be partially malformed.
    ' Keep only records with a safe identity and finite playback clocks.
    clean = []
    for each entry in parsed
        if type(entry) = "roAssociativeArray"
            if entry.doesExist("id") and GetInterface(entry.id,"ifString") <> invalid
                safeId = orbitText(entry.id,180)
                if safeId <> "" and left(safeId,5) <> "live:"
                    position = 0
                    duration = 0
                    if entry.doesExist("position") then position = rpWatchNumber(entry.position)
                    if entry.doesExist("duration") then duration = rpWatchNumber(entry.duration)
                    entry.position = position
                    entry.duration = duration
                    if not entry.doesExist("watched") then entry.watched = false
                    if not entry.doesExist("listed") then entry.listed = false
                    clean.push(entry)
                    if clean.count() >= 60 then exit for
                end if
            end if
        end if
    end for
    unique = []
    seenIds = {}
    for each record in clean
        if not seenIds.doesExist(record.id)
            seenIds[record.id] = true
            unique.push(record)
        end if
    end for
    return unique
end function

function rpWatchSave(items as object, profileId = "p1" as string) as boolean
    if type(items) <> "roArray" then return false
    while items.count() > 60
        items.delete(items.count()-1)
    end while
    payload = FormatJson(items)
    if GetInterface(payload, "ifString") = invalid or len(payload) > 65536 then return false
    section = rpWatchSection(profileId)
    if GetInterface(section, "ifRegistrySection") = invalid then return false
    if section.write("stateV1", payload) <> true then return false
    return section.flush() = true
end function

function rpWatchIndex(items as object, itemId as string) as integer
    if type(items) <> "roArray" or itemId = "" then return -1
    for i = 0 to items.count()-1
        if type(items[i]) = "roAssociativeArray"
            if items[i].doesExist("id")
                if GetInterface(items[i].id,"ifString") <> invalid and items[i].id = itemId then return i
            end if
        end if
    end for
    return -1
end function

function rpWatchNumber(value as dynamic) as dynamic
    numeric = GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifLongInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid
    if not numeric then return 0
    if value <> value or value < 0 or value > 9000000000000.0 then return 0
    return value
end function

function rpWatchRecord(item as object, position = 0 as dynamic, duration = 0 as dynamic) as object
    record = {id:orbitText(item.id,180), title:orbitText(item.title,180), kind:orbitText(item.kind,20), poster:orbitText(item.poster,2048), background:orbitText(item.background,2048), year:orbitText(item.year,20), provider:orbitText(item.provider,32), imdbId:orbitText(item.imdbId,180), position:0, duration:0, watched:false, listed:false, updated:0}
    if GetInterface(position,"ifFloat") <> invalid or GetInterface(position,"ifInt") <> invalid or GetInterface(position,"ifLongInt") <> invalid or GetInterface(position,"ifDouble") <> invalid then record.position = position
    if GetInterface(duration,"ifFloat") <> invalid or GetInterface(duration,"ifInt") <> invalid or GetInterface(duration,"ifLongInt") <> invalid or GetInterface(duration,"ifDouble") <> invalid then record.duration = duration
    ' Preserve the online HD source identity needed by the provider resolver.
    ' The public item id alone is not sufficient for every provider operation.
    if item.doesExist("providerId")
        if GetInterface(item.providerId,"ifInt") <> invalid or GetInterface(item.providerId,"ifLongInt") <> invalid
            if item.providerId > 0 then record.providerId = item.providerId
        else if GetInterface(item.providerId,"ifString") <> invalid
            ' CineCalidad uses a canonical slug as its provider identifier.
            providerIdText = orbitText(item.providerId,200)
            if providerIdText <> "" then record.providerId = providerIdText
        end if
    end if
    if item.doesExist("providerSlug") then record.providerSlug = orbitText(item.providerSlug,200)
    if record.provider = "lamovie"
        slugPresent = false
        slugValue = ""
        if item.doesExist("providerSlug")
            slugValue = orbitText(item.providerSlug,200)
            slugPresent = slugValue <> ""
        end if
        print "[RokuPlus identity] watch-record id="; record.id; " providerId="; orbitText(record.providerId,40); " slugPresent="; slugPresent; " slug="; slugValue
    end if
    ' CineHax requires these two source-specific identity fields to rebuild
    ' its resolver request after Continue Watching restores a saved record.
    if item.doesExist("providerTmdbId") then record.providerTmdbId = orbitText(item.providerTmdbId,40)
    if item.doesExist("providerKind") then record.providerKind = orbitText(item.providerKind,16)
    if item.doesExist("season") then record.season = item.season
    if item.doesExist("episode") then record.episode = item.episode
    if item.doesExist("seriesTitle") then record.seriesTitle = orbitText(item.seriesTitle,180)
    if item.doesExist("seriesProviderSlug") then record.seriesProviderSlug = orbitText(item.seriesProviderSlug,200)
    return record
end function

function rpWatchUpdate(items as object, item as object, position as dynamic, duration as dynamic) as object
    if type(items) <> "roArray" or type(item) <> "roAssociativeArray" then return items
    id = orbitText(item.id,180)
    if id = "" or left(id,5) = "live:" then return items
    index = rpWatchIndex(items,id)
    record = rpWatchRecord(item,position,duration)
    if index >= 0
        old = items[index]
        if old.doesExist("watched")
            if old.watched = true then record.watched = true
        end if
        if old.doesExist("listed")
            if old.listed = true then record.listed = true
        end if
        ' Progress events may carry a reduced item object. Never let an
        ' incomplete event erase provider identity needed by Continue Watching.
        identityFields = ["provider", "providerId", "providerSlug", "providerTmdbId", "providerKind", "season", "episode", "seriesTitle", "seriesProviderSlug", "imdbId"]
        for each field in identityFields
            keepOld = false
            if old.doesExist(field)
                if not record.doesExist(field)
                    keepOld = true
                else if record[field] = invalid
                    keepOld = true
                else if GetInterface(record[field], "ifString") <> invalid
                    if record[field] = "" then keepOld = true
                end if
                if keepOld then record[field] = old[field]
            end if
        end for
        ' Keep artwork and descriptive metadata if a later progress sample
        ' only contains the playback identity and clocks.
        displayFields = ["title", "kind", "poster", "background", "year"]
        for each field in displayFields
            if old.doesExist(field) and record.doesExist(field)
                if record[field] = "" then record[field] = old[field]
            end if
        end for
    end if
    if record.duration > 0 and record.position >= record.duration * 0.92 then record.watched = true
    if index >= 0 then items.delete(index)
    items.unshift(record)
    while items.count() > 60
        items.delete(items.count()-1)
    end while
    return items
end function

function rpWatchToggle(items as object, item as object, field as string) as object
    if type(items) <> "roArray" or type(item) <> "roAssociativeArray" then return items
    id = orbitText(item.id,180)
    if id = "" then return items
    index = rpWatchIndex(items,id)
    if index < 0
        record = rpWatchRecord(item)
        items.unshift(record)
        index = 0
    end if
    current = false
    if items[index].doesExist(field)
        if items[index][field] = true then current = true
    end if
    items[index][field] = not current
    items[index].updated = 0
    return items
end function

function rpWatchGet(items as object, itemId as string) as dynamic
    index = rpWatchIndex(items,itemId)
    if index < 0 then return invalid
    return items[index]
end function

function rpWatchContinue(items as object) as object
    result = []
    if type(items) <> "roArray" then return result
    for each item in items
        if type(item) = "roAssociativeArray"
            hasId = false
            if item.doesExist("id")
                if GetInterface(item.id,"ifString") <> invalid then hasId = true
            end if
            watched = false
            if item.doesExist("watched")
                if item.watched = true then watched = true
            end if
            position = 0
            duration = 0
            if item.doesExist("position") then position = rpWatchNumber(item.position)
            if item.doesExist("duration") then duration = rpWatchNumber(item.duration)
            if hasId and not watched and position > 15 and (duration <= 0 or position < duration * 0.92)
                result.push(item)
                if result.count() >= 6 then exit for
            end if
        end if
    end for
    return result
end function
