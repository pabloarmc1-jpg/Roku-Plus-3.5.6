' Local viewing state for Roku Plus. Stores metadata and playback clocks only.
function rpWatchSection(profileId = "p1" as string) as object
    safeId = rpNormalizeProfileId(profileId)
    return CreateObject("roRegistrySection", "RokuPlusWatch_" + safeId)
end function

function rpWatchParse(raw as dynamic) as dynamic
    if GetInterface(raw, "ifString") = invalid or len(raw) = 0 or len(raw) > 65536 then return invalid
    parsed = ParseJson(raw)
    if type(parsed) <> "roArray" then return invalid
    ' Reject a partially malformed snapshot instead of treating skipped records
    ' as a valid (possibly empty) history that could overwrite the backup.
    unique = []
    seenIds = {}
    for each entry in parsed
        if type(entry) <> "roAssociativeArray" then return invalid
        if not entry.doesExist("id") or GetInterface(entry.id,"ifString") = invalid then return invalid
        safeId = orbitText(entry.id,180)
        if safeId = "" or len(entry.id) > 180 or safeId <> entry.id or left(safeId,5) = "live:" then return invalid

        position = 0
        duration = 0
        if entry.doesExist("position")
            if not rpWatchStoredNumberValid(entry.position) then return invalid
            position = entry.position
        end if
        if entry.doesExist("duration")
            if not rpWatchStoredNumberValid(entry.duration) then return invalid
            duration = entry.duration
        end if
        ' Repair a semantically invalid saved clock before accepting the snapshot.
        if duration > 0 and position > duration then position = duration
        if entry.doesExist("watched")
            if type(entry.watched) <> "Boolean" then return invalid
        end if
        if entry.doesExist("listed")
            if type(entry.listed) <> "Boolean" then return invalid
        end if

        ' Validate optional display/source strings before accepting the record.
        stringFields = ["title", "kind", "poster", "background", "year", "provider", "imdbId", "providerSlug", "providerTmdbId", "providerKind", "seriesTitle", "seriesId", "seriesImdbId", "seriesProviderSlug", "seriesProviderTmdbId", "seriesProviderKind"]
        for each field in stringFields
            if entry.doesExist(field)
                if GetInterface(entry[field],"ifString") = invalid then return invalid
            end if
        end for
        for each field in ["providerId", "seriesProviderId"]
            if entry.doesExist(field)
                value = entry[field]
                if GetInterface(value,"ifString") = invalid and not rpWatchStoredNumberValid(value) then return invalid
            end if
        end for
        for each coordinateField in ["season", "episode"]
            if entry.doesExist(coordinateField)
                minimum = 0
                maximum = 999
                if coordinateField = "episode"
                    minimum = 1
                    maximum = 9999
                end if
                if not rpWatchStoredIntegerValid(entry[coordinateField],minimum,maximum) then return invalid
                entry[coordinateField] = int(entry[coordinateField])
            end if
        end for
        if entry.doesExist("seriesSeasonNumbers")
            if type(entry.seriesSeasonNumbers) <> "roArray" or entry.seriesSeasonNumbers.count() > 100 then return invalid
            seenSeasons = {}
            normalizedSeasons = []
            for each seasonValue in entry.seriesSeasonNumbers
                if not rpWatchStoredIntegerValid(seasonValue,0,999) then return invalid
                seasonNumber = int(seasonValue)
                seasonKey = seasonNumber.toStr()
                if seenSeasons.doesExist(seasonKey) then return invalid
                seenSeasons[seasonKey] = true
                normalizedSeasons.push(seasonNumber)
            end for
            entry.seriesSeasonNumbers = normalizedSeasons
        end if

        if not seenIds.doesExist(safeId)
            seenIds[safeId] = true
            if unique.count() < 60
                entry.id = safeId
                entry.position = position
                entry.duration = duration
                if not entry.doesExist("watched") then entry.watched = false
                if not entry.doesExist("listed") then entry.listed = false
                unique.push(entry)
            end if
        end if
    end for
    return unique
end function

function rpWatchStoredIntegerValid(value as dynamic, minimum as integer, maximum as integer) as boolean
    if GetInterface(value,"ifString") <> invalid
        if len(value) = 0 or not CreateObject("roRegex","^[0-9]{1,4}$","").isMatch(value) then return false
        value = value.toInt()
    end if
    numeric = GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifLongInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid
    if not numeric or value <> value or value < minimum or value > maximum then return false
    if value <> int(value) then return false
    return true
end function

function rpWatchStoredNumberValid(value as dynamic) as boolean
    numeric = GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifLongInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid
    if not numeric then return false
    if value <> value or value < 0 or value > 9000000000000.0 then return false
    return true
end function

sub rpWatchLogCinehax(items as dynamic, stage as string, profileId as string, storageKey as string)
    if type(items) <> "roArray" then return
    for each record in items
        if type(record) = "roAssociativeArray" and orbitText(record.provider,32) = "cinehax"
            providerIdText = ""
            tmdbText = ""
            kindText = ""
            slugText = ""
            providerIdPresent = record.doesExist("providerId")
            tmdbPresent = record.doesExist("providerTmdbId")
            kindPresent = record.doesExist("providerKind")
            slugPresent = record.doesExist("providerSlug")
            if providerIdPresent
                if GetInterface(record.providerId,"ifString") <> invalid
                    providerIdText = orbitText(record.providerId,200)
                else if GetInterface(record.providerId,"ifInt") <> invalid or GetInterface(record.providerId,"ifLongInt") <> invalid
                    providerIdText = record.providerId.toStr()
                end if
            end if
            if tmdbPresent then tmdbText = orbitText(record.providerTmdbId,40)
            if kindPresent then kindText = orbitText(record.providerKind,16)
            if slugPresent then slugText = orbitText(record.providerSlug,200)
            print "[RokuPlus watch-persist] stage="; stage; " profile="; profileId; " key="; storageKey; " id="; orbitText(record.id,180); " providerIdPresent="; providerIdPresent; " providerId="; providerIdText; " tmdbPresent="; tmdbPresent; " tmdb="; tmdbText; " kindPresent="; kindPresent; " kind="; kindText; " slugPresent="; slugPresent; " slug="; slugText
        end if
    end for
end sub

function rpWatchLoad(profileId = "p1" as string) as object
    if rpNormalizeProfileId(profileId) <> profileId then return []
    section = rpWatchSection(profileId)
    if GetInterface(section, "ifRegistrySection") = invalid then return []
    raw = section.read("stateV1")
    loaded = rpWatchParse(raw)
    if type(loaded) = "roArray"
        rpWatchLogCinehax(loaded,"load-primary",profileId,"stateV1")
        ' Refresh the backup only from a successfully parsed primary state.
        backupCurrent = section.read("stateV1Backup")
        if GetInterface(backupCurrent,"ifString") = invalid
            if section.write("stateV1Backup",raw) = true then section.flush()
        else if backupCurrent <> raw
            if section.write("stateV1Backup",raw) = true then section.flush()
        end if
        return loaded
    end if
    ' The primary state is missing or invalid. Prefer the newest validated backup.
    backupRaw = section.read("stateV1Backup")
    recovered = rpWatchParse(backupRaw)
    if type(recovered) = "roArray"
        rpWatchLogCinehax(recovered,"load-backup",profileId,"stateV1Backup")
        restored = FormatJson(recovered)
        if GetInterface(restored,"ifString") <> invalid and len(restored) <= 65536
            if section.write("stateV1",restored) = true then section.flush()
        end if
        return recovered
    end if
    ' Only use the pre-profile legacy section when neither current copy is usable.
    if rpNormalizeProfileId(profileId) = "p1"
        legacy = CreateObject("roRegistrySection", "RokuPlusWatch")
        if GetInterface(legacy, "ifRegistrySection") <> invalid
            legacyRaw = legacy.read("stateV1")
            legacyItems = rpWatchParse(legacyRaw)
            if type(legacyItems) = "roArray"
                rpWatchLogCinehax(legacyItems,"load-legacy",profileId,"RokuPlusWatch/stateV1")
                ' Migrate only validated legacy JSON; never copy corrupt data.
                if section.write("stateV1",legacyRaw) = true then section.flush()
                if section.write("stateV1Backup",legacyRaw) = true then section.flush()
                return legacyItems
            end if
        end if
    end if
    return []
end function

' Reduce optional metadata before persistence when the Registry payload is too large.
' Playback clocks and source identity remain available for Continue Watching.
function rpWatchCompactForSave(items as object) as object
    if type(items) <> "roArray" then return items
    for each record in items
        if type(record) = "roAssociativeArray"
            if record.doesExist("poster") then record.delete("poster")
            if record.doesExist("background") then record.delete("background")
            ' Compact display-only text. Keep catalog IDs, provider slugs,
            ' resolver metadata and season coordinates intact for Continue Watching.
            displayLimits = {title:100, kind:20, year:12, seriesTitle:100}
            for each field in displayLimits
                if record.doesExist(field)
                    value = record[field]
                    if GetInterface(value,"ifString") <> invalid
                        record[field] = left(value,displayLimits[field])
                    end if
                end if
            end for
        end if
    end for
    return items
end function

function rpWatchSave(items as object, profileId = "p1" as string) as boolean
    if rpNormalizeProfileId(profileId) <> profileId then return false
    if type(items) <> "roArray" then return false
    ' Work on a JSON round-trip copy: compaction and size trimming must never
    ' mutate the live in-memory history before persistence is confirmed.
    copied = ParseJson(FormatJson(items))
    if type(copied) <> "roArray" then return false
    saveItems = copied
    while saveItems.count() > 60
        saveItems.delete(saveItems.count()-1)
    end while
    payload = FormatJson(saveItems)
    if GetInterface(payload, "ifString") = invalid then return false
    if len(payload) > 65536
        saveItems = rpWatchCompactForSave(saveItems)
        payload = FormatJson(saveItems)
    end if
    ' If an unusually large legacy record still exceeds the Registry limit,
    ' discard oldest entries from the save copy, preserving the live history.
    while GetInterface(payload, "ifString") <> invalid and len(payload) > 65536 and saveItems.count() > 1
        saveItems.delete(saveItems.count()-1)
        payload = FormatJson(saveItems)
    end while
    if GetInterface(payload, "ifString") = invalid or len(payload) > 65536 then return false
    if type(rpWatchParse(payload)) <> "roArray" then return false
    rpWatchLogCinehax(saveItems,"save-payload",profileId,"stateV1")
    section = rpWatchSection(profileId)
    if GetInterface(section, "ifRegistrySection") = invalid then return false
    previousPrimary = section.read("stateV1")
    if section.write("stateV1", payload) <> true then return false
    if section.flush() <> true
        ' A failed flush may leave the new value staged in this RegistrySection.
        ' Restore the last known primary so a later read cannot mistake it for
        ' a durable save; the backup remains untouched.
        if previousPrimary = "" then
            section.delete("stateV1")
        else
            section.write("stateV1",previousPrimary)
        end if
        section.flush()
        return false
    end if
    verifyItems = rpWatchParse(section.read("stateV1"))
    rpWatchLogCinehax(verifyItems,"save-readback",profileId,"stateV1")
    ' Save the backup only after the new primary state has been flushed.
    ' If backup flush fails, restore its previous staged value. The primary
    ' is already durable, so this does not turn a successful save into failure.
    previousBackup = section.read("stateV1Backup")
    if section.write("stateV1Backup",payload) = true
        if section.flush() <> true
            if previousBackup = "" then
                section.delete("stateV1Backup")
            else
                section.write("stateV1Backup",previousBackup)
            end if
            section.flush()
        end if
    end if
    return true
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

' Migrate a saved watch record only when IMDb identity and episode coordinates
' prove that the replacement catalog ID refers to the same playable content.
function rpWatchMigrateIdentity(items as object, oldItem as object, newItem as object) as object
    if type(items) <> "roArray" or type(oldItem) <> "roAssociativeArray" or type(newItem) <> "roAssociativeArray" then return items
    oldId = orbitText(oldItem.id,180)
    newId = orbitText(newItem.id,180)
    if oldId = "" or newId = "" or oldId = newId then return items
    oldImdb = lcase(orbitText(oldItem.imdbId,180))
    newImdb = lcase(orbitText(newItem.imdbId,180))
    oldKind = lcase(orbitText(oldItem.kind,20))
    newKind = lcase(orbitText(newItem.kind,20))
    if oldKind = "" or oldKind <> newKind then return items
    if oldKind <> "episode"
        if oldImdb = "" or newImdb = "" or oldImdb <> newImdb then return items
    end if
    if oldKind = "episode"
        oldSeriesImdb = orbitImdb(oldItem.seriesImdbId)
        newSeriesImdb = orbitImdb(newItem.seriesImdbId)
        oldSeriesTmdb = orbitText(oldItem.seriesProviderTmdbId,40)
        newSeriesTmdb = orbitText(newItem.seriesProviderTmdbId,40)
        if oldImdb <> "" and newImdb <> ""
            if oldImdb <> newImdb then return items
        else
            sameSeriesIdentity = false
            if oldSeriesImdb <> "" and newSeriesImdb <> ""
                if oldSeriesImdb <> newSeriesImdb then return items
                sameSeriesIdentity = true
            else if oldSeriesTmdb <> "" and newSeriesTmdb <> ""
                if oldSeriesTmdb = newSeriesTmdb then sameSeriesIdentity = true
            end if
            if not sameSeriesIdentity then return items
        end if
        if not oldItem.doesExist("season") or not newItem.doesExist("season") or not oldItem.doesExist("episode") or not newItem.doesExist("episode") then return items
        if not rpWatchStoredIntegerValid(oldItem.season,0,999) or not rpWatchStoredIntegerValid(newItem.season,0,999) or not rpWatchStoredIntegerValid(oldItem.episode,1,9999) or not rpWatchStoredIntegerValid(newItem.episode,1,9999) then return items
        oldSeason = int(oldItem.season)
        newSeason = int(newItem.season)
        oldEpisode = int(oldItem.episode)
        newEpisode = int(newItem.episode)
        if oldSeason <> newSeason or oldEpisode <> newEpisode then return items
    else
        if oldImdb = "" or newImdb = "" or oldImdb <> newImdb then return items
    end if
    oldIndex = rpWatchIndex(items,oldId)
    if oldIndex < 0 then return items
    newIndex = rpWatchIndex(items,newId)
    record = items[oldIndex]
    if newIndex >= 0
        ' Both IDs identify the same IMDb episode. Keep the current-ID record,
        ' but merge the old progress and flags before removing the obsolete ID.
        currentRecord = items[newIndex]
        oldPosition = 0
        oldDuration = 0
        currentPosition = 0
        currentDuration = 0
        if record.doesExist("position") then oldPosition = rpWatchNumber(record.position)
        if record.doesExist("duration") then oldDuration = rpWatchNumber(record.duration)
        if currentRecord.doesExist("position") then currentPosition = rpWatchNumber(currentRecord.position)
        if currentRecord.doesExist("duration") then currentDuration = rpWatchNumber(currentRecord.duration)
        useOldProgress = false
        if oldDuration > 0 and currentDuration > 0
            if oldPosition / oldDuration > currentPosition / currentDuration then useOldProgress = true
        else if oldDuration > 0 and currentDuration <= 0
            useOldProgress = true
        else if oldDuration <= 0 and currentDuration <= 0
            if oldPosition > currentPosition then useOldProgress = true
        end if
        if useOldProgress
            currentRecord.position = oldPosition
            currentRecord.duration = oldDuration
        end if
        oldWatched = false
        currentWatched = false
        if record.doesExist("watched")
            if record.watched = true then oldWatched = true
        end if
        if currentRecord.doesExist("watched")
            if currentRecord.watched = true then currentWatched = true
        end if
        currentRecord.watched = oldWatched or currentWatched
        oldListed = false
        currentListed = false
        if record.doesExist("listed")
            if record.listed = true then oldListed = true
        end if
        if currentRecord.doesExist("listed")
            if currentRecord.listed = true then currentListed = true
        end if
        currentRecord.listed = oldListed or currentListed
        oldUpdated = 0
        currentUpdated = 0
        if record.doesExist("updated") then oldUpdated = rpWatchNumber(record.updated)
        if currentRecord.doesExist("updated") then currentUpdated = rpWatchNumber(currentRecord.updated)
        if oldUpdated > currentUpdated then currentRecord.updated = oldUpdated
        if oldIndex < newIndex then newIndex = newIndex - 1
        items.delete(oldIndex)
        items.delete(newIndex)
        record = currentRecord
    else
        items.delete(oldIndex)
    end if
    record.id = newId
    ' Accept refreshed source identifiers only when the new metadata supplied them.
    identityFields = ["provider", "providerId", "providerSlug", "providerTmdbId", "providerKind", "season", "episode", "seriesTitle", "seriesId", "seriesImdbId", "seriesProviderId", "seriesProviderSlug", "seriesProviderTmdbId", "seriesProviderKind", "seriesSeasonNumbers", "imdbId"]
    for each field in identityFields
        if newItem.doesExist(field)
            newValue = newItem[field]
            if newValue <> invalid
                useValue = true
                if GetInterface(newValue,"ifString") <> invalid
                    if newValue = "" then useValue = false
                end if
                if useValue then record[field] = newValue
            end if
        end if
    end for
    if orbitText(newItem.title,180) <> "" then record.title = orbitText(newItem.title,180)
    if orbitText(newItem.poster,2048) <> "" then record.poster = orbitText(newItem.poster,2048)
    if orbitText(newItem.background,2048) <> "" then record.background = orbitText(newItem.background,2048)
    if orbitText(newItem.year,20) <> "" then record.year = orbitText(newItem.year,20)
    items.unshift(record)
    return items
end function

function rpWatchNumber(value as dynamic) as dynamic
    numeric = GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifLongInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid
    if not numeric then return 0
    if value <> value or value < 0 or value > 9000000000000.0 then return 0
    return value
end function

function rpWatchRecord(item as object, position = 0 as dynamic, duration = 0 as dynamic) as object
    record = {id:orbitText(item.id,180), title:orbitText(item.title,180), kind:orbitText(item.kind,20), poster:orbitText(item.poster,2048), background:orbitText(item.background,2048), year:orbitText(item.year,20), provider:orbitText(item.provider,32), imdbId:orbitText(item.imdbId,180), position:0, duration:0, watched:false, listed:false, updated:0}
    ' Normalize untrusted playback clocks before they enter persistent history.
    ' Invalid, negative, NaN or implausibly large values become zero.
    record.position = rpWatchNumber(position)
    record.duration = rpWatchNumber(duration)
    if record.duration > 0 and record.position > record.duration then record.position = record.duration
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
    if record.provider = "cinehax"
        print "[RokuPlus identity] watch-record provider=cinehax id="; record.id; " providerId="; orbitText(record.providerId,40); " tmdb="; orbitText(record.providerTmdbId,40); " kind="; orbitText(record.providerKind,16); " slug="; orbitText(record.providerSlug,200)
    end if
    if item.doesExist("season") and rpWatchStoredIntegerValid(item.season,0,999) then record.season = int(item.season)
    if item.doesExist("episode") and rpWatchStoredIntegerValid(item.episode,1,9999) then record.episode = int(item.episode)
    if item.doesExist("seriesTitle") then record.seriesTitle = orbitText(item.seriesTitle,180)
    if item.doesExist("seriesId") then record.seriesId = orbitText(item.seriesId,180)
    if item.doesExist("seriesImdbId") then record.seriesImdbId = orbitImdb(item.seriesImdbId)
    if item.doesExist("seriesProviderId") then record.seriesProviderId = item.seriesProviderId
    if item.doesExist("seriesProviderSlug") then record.seriesProviderSlug = orbitText(item.seriesProviderSlug,200)
    if item.doesExist("seriesProviderTmdbId") then record.seriesProviderTmdbId = orbitText(item.seriesProviderTmdbId,40)
    if item.doesExist("seriesProviderKind") then record.seriesProviderKind = orbitText(item.seriesProviderKind,16)
    if item.doesExist("seriesSeasonNumbers") and type(item.seriesSeasonNumbers) = "roArray"
        cleanSeasons = []
        seenSeasons = {}
        for each seasonValue in item.seriesSeasonNumbers
            if cleanSeasons.count() >= 100 then exit for
            if rpWatchStoredIntegerValid(seasonValue,0,999)
                seasonNumber = int(seasonValue)
                seasonKey = seasonNumber.toStr()
                if not seenSeasons.doesExist(seasonKey)
                    seenSeasons[seasonKey] = true
                    cleanSeasons.push(seasonNumber)
                end if
            end if
        end for
        record.seriesSeasonNumbers = cleanSeasons
    end if
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
        ' A fresh playback progress sample means the user has started watching
        ' this title again. Clear the previous watched flag; the 92% rule below
        ' will mark it watched again when the new playback reaches completion.
        if old.doesExist("watched")
            if old.watched = true then record.watched = false
        end if
        if old.doesExist("listed")
            if old.listed = true then record.listed = true
        end if
        ' Progress events may carry a reduced item object. Never let an
        ' incomplete event erase provider identity needed by Continue Watching.
        identityFields = ["provider", "providerId", "providerSlug", "providerTmdbId", "providerKind", "season", "episode", "seriesTitle", "seriesId", "seriesImdbId", "seriesProviderId", "seriesProviderSlug", "seriesProviderTmdbId", "seriesProviderKind", "seriesSeasonNumbers", "imdbId"]
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
    ' Keep the live in-memory history under the same cap as update/load/save.
    while items.count() > 60
        items.delete(items.count()-1)
    end while
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
