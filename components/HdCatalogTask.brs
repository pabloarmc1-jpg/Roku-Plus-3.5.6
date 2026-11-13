' Public HD source requests. No JavaScript evaluation, proxy or PC helper.
' Catalog aggregation keeps a 40-second total deadline and caps each provider slice at 9 seconds.
sub init()
    m.top.functionName = "runHdCatalogRequest"
end sub

sub runHdCatalogRequest()
    m.hdElapsed = CreateObject("roTimespan")
    m.hdElapsed.mark()
    m.hdTotalBudgetMs = 40000
    if m.top.operation = "resolve" then m.hdTotalBudgetMs = 60000
    request = {
        operation:m.top.operation, kind:m.top.kind, provider:m.top.provider
        query:m.top.query, skip:m.top.skip, item:m.top.item, season:m.top.season
        requestId:m.top.requestId, attempt:m.top.attempt, tvmazeCache:m.top.tvmazeCache
    }
    answer = rpHdTaskExecute(request)
    if not m.top.cancelRequested then m.top.result = answer
end sub

' Fetch/decoder/source injection exercises this exact orchestration offline.
function rpHdTaskExecute(request as object, fetcher = invalid as dynamic, decoderAccept = invalid as dynamic, catalogSources = invalid as dynamic) as object
    if fetcher = invalid then fetcher = rpHdTaskDownloadText
    if decoderAccept = invalid then decoderAccept = rpHdTaskCanDecode
    operation = orbitText(request.operation,20)
    kind = orbitText(request.kind,10)
    provider = rpHdOnlineProvider(request.provider)
    answer = {ok:false, cancelled:false, requestId:orbitText(request.requestId,120), operation:operation, kind:kind, provider:provider, message:"No se pudo completar la consulta HD."}
    m.hdProviderDeadline = 0
    if provider = ""
        answer.message = "Elige una fuente HD válida."
        return answer
    end if
    if operation = "search"
        return rpHdTaskGlobalSearch(request,answer,fetcher,catalogSources)
    end if
    if operation = "catalog"
        if kind <> "movie" and kind <> "series" then return answer
        if provider = "all" then return rpHdTaskCombinedCatalog(request,answer,fetcher,catalogSources)
        skip = orbitInteger(request.skip,200000)
        page = (skip \ 20)+1
        query = rpHdOnlineSearchQuery(request.query)
        catalog = rpHdTaskCatalogPage(provider,kind,page,query,fetcher)
        if not catalog.ok then return rpHdTaskFailure(answer,catalog)
        answer.items = catalog.items
        answer.hasMore = catalog.hasMore
        answer.nextSkip = catalog.nextSkip
        answer.total = catalog.total
        answer.totalKnown = catalog.totalKnown
        answer.ok = true
        answer.message = ""
        return answer
    end if
    ' A combined result keeps its own source identity for details and playback.
    ' Never resolve a title against whichever catalog happens to be selected.
    if provider = "all" and type(request.item) = "roAssociativeArray"
        provider = rpHdOnlineProvider(request.item.provider)
        if provider = "all" then provider = ""
    end if
    if provider = "cinehax"
        answer = rpHdCinehaxTask(request,answer,fetcher,decoderAccept)
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
    end if
    if provider = "seriesmetro"
        answer = rpHdSeriesmetroTask(request,answer,fetcher,decoderAccept)
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
    end if
    if provider = "cinecalidad"
        answer = rpHdCinecalidadTask(request,answer,fetcher,decoderAccept)
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
    end if
    item = rpHdTaskInputItem(request.item,provider)
    if item = invalid
        answer.message = "El título HD no tiene un identificador válido."
        return answer
    end if
    if operation = "meta"
        if item.kind <> "movie" and item.kind <> "series" then return answer
        if provider = "lamovie"
            endpoint = rpHdOnlineEndpoint(provider,"meta",{kind:item.kind,slug:item.providerSlug})
            response = rpHdTaskFetchJson(endpoint,fetcher)
            if not response.ok then return rpHdTaskFailure(answer,response)
            normalized = rpHdOnlineMetadata(response.data,provider,item.kind,item.id)
            if normalized = invalid
                answer.message = "No se encontraron los detalles de este título HD."
                return answer
            end if
            item = normalized
        end if
        if item.kind = "series"
            loaded = rpHdTaskLoadEpisodes(item,1,fetcher)
            if loaded.ok
                item.seasons = loaded.seasons
                item.seasonNumbers = loaded.seasonNumbers
            else
                ' Keep the series details usable when the first episode request is temporarily unavailable.
                ' The season browser will retry this season through the normal episodes operation.
                item.seasons = [{number:1,episodes:[],loaded:false}]
                item.seasonNumbers = [1]
                print "[RokuPlus series] meta_episode_load_deferred provider="; provider; " id="; item.id
            end if
        end if
        answer.item = item
        answer.ok = true
        answer.message = ""
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
    else if operation = "episodes"
        if item.kind <> "series" then return answer
        season = orbitInteger(request.season,999,1)
        if season < 0 then season = 1
        loaded = rpHdTaskLoadEpisodes(item,season,fetcher)
        if not loaded.ok then return rpHdTaskFailure(answer,loaded)
        answer.seasons = []
        for each loadedSeason in loaded.seasons
            if loadedSeason.loaded then answer.seasons.push(loadedSeason)
        end for
        answer.seasonNumbers = loaded.seasonNumbers
        answer.season = season
        answer.ok = true
        answer.message = ""
        return rpHdTvmazeEnrichAnswer(answer,request,fetcher)
    else if operation = "resolve"
        if item.kind <> "movie" and item.kind <> "episode" then return answer
        return rpHdTaskResolveItem(item,provider,answer,fetcher,decoderAccept,orbitInteger(request.attempt,999))
    end if
    answer.message = "La consulta HD no es válida."
    return answer
end function

function rpHdTaskResolveItem(item as object, provider as string, answer as object, fetcher as dynamic, decoderAccept as dynamic, retry as integer) as object
    ' Bound the initial player API so it cannot consume the whole operation.
    rpHdTaskBeginSlice(4)
    endpoint = rpHdOnlineEndpoint(provider,"player",{id:item.providerId})
    response = rpHdTaskFetchJson(endpoint,fetcher)
    m.hdProviderDeadline = 0
    if not response.ok then return rpHdTaskFailure(answer,response)
    embeds = rpHdOnlineEmbeds(response.data)
    return rpHdTaskResolveEmbeds(embeds,provider,answer,fetcher,decoderAccept,retry)
end function

' Adapters may discover Vimeos links differently but share media validation.
' Playlist checks and one bounded first-segment sample are diagnostic only.
function rpHdTaskAuditExternalAudio(master as object, selected as object, fetcher as dynamic, referer as string, videoAudit as dynamic) as object
    result = {checked:0,valid:0,segments:0,durationSets:0,samples:0,tsValid:0,aacSamples:0}
    if type(master.audioTracks) <> "roArray" then return result
    if selected.audioGroup = "" then return result
    for each track in master.audioTracks
        if track.group = selected.audioGroup and track.url <> ""
            result.checked++
            response = fetcher(track.url,"media",referer)
            if response.cancelled
                print "[RokuPlus audio-audit] cancelled before playlist validation"
                return result
            end if
            if response.ok and rpHdTaskMediaManifest(response.body,track.url)
                segments = rpHdTaskSegmentList(response.body,track.url)
                durations = rpHdTaskSegmentDurations(response.body,segments.count())
                if segments.count() > 0
                    result.valid++
                    result.segments += segments.count()
                    if durations.count() = segments.count() then result.durationSets++
                    print "[RokuPlus audio-audit] language="; track.language; " name="; track.name; " playlist=valid segments="; segments.count(); " durations="; durations.count()
                    if result.samples < 2
                        sample = fetcher(segments[0],"audio-sample",referer)
                        if sample.cancelled
                            print "[RokuPlus audio-audit] cancelled before segment sample"
                            return result
                        end if
                        if sample.ok
                            result.samples++
                            audit = rpHdTaskAuditAudioSegment(sample.bytes)
                            if audit.aligned and audit.syncErrors = 0 and audit.packetCount > 0 then result.tsValid++
                            if audit.aac and audit.adtsCandidates > 0 then result.aacSamples++
                            print "[RokuPlus audio-sample] language="; track.language; " bytes="; audit.bytes; " packets="; audit.packetCount; " trailingBytes="; audit.trailingBytes
                            print "[RokuPlus audio-sample] language="; track.language; " aligned="; audit.aligned; " syncErrors="; audit.syncErrors; " pat="; audit.patPackets; " pmt="; audit.pmtPackets
                            print "[RokuPlus audio-sample] language="; track.language; " audioPids="; audit.audioPids; " aac="; audit.aac; " adtsCandidates="; audit.adtsCandidates
                            print "[RokuPlus audio-sample] language="; track.language; " ptsCount="; audit.ptsCount; " firstPts90k="; audit.firstPts; " lastPts90k="; audit.lastPts; " continuityErrors="; audit.continuityErrors
                            if audit.ptsCount > 0 and type(videoAudit) = "roAssociativeArray" and videoAudit.videoPtsCount > 0
                                deltaPts = audit.firstPts-videoAudit.firstVideoPts
                                if deltaPts > 4294967296 then deltaPts -= 8589934592
                                if deltaPts < -4294967296 then deltaPts += 8589934592
                                print "[RokuPlus audio-sync] language="; track.language; " videoFirstPts90k="; videoAudit.firstVideoPts; " audioFirstPts90k="; audit.firstPts; " deltaMs="; deltaPts/90.0
                            else
                                print "[RokuPlus audio-sync] language="; track.language; " pts_comparison=unavailable"
                            end if
                        else
                            print "[RokuPlus audio-sample] language="; track.language; " request_failed status="; sample.httpStatus
                        end if
                    end if
                else
                    print "[RokuPlus audio-audit] language="; track.language; " name="; track.name; " playlist=empty"
                end if
            else
                print "[RokuPlus audio-audit] language="; track.language; " name="; track.name; " playlist=unavailable_or_rejected"
            end if
        end if
    end for
    print "[RokuPlus audio-audit] checked="; result.checked; " valid="; result.valid; " segments="; result.segments; " durationSets="; result.durationSets
    print "[RokuPlus audio-audit] samples="; result.samples; " tsValid="; result.tsValid; " aacSamples="; result.aacSamples
    return result
end function

' Inspect only complete 188-byte packets from a bounded sample; never mutate playback data.
function rpHdTaskAuditAudioSegment(payload as object) as object
    result = {bytes:0,packetCount:0,trailingBytes:0,aligned:false,syncErrors:0,patPackets:0,pmtPackets:0,pmtPid:-1,videoPid:-1,aac:false,audioPids:"",ptsCount:0,firstPts:-1,lastPts:-1,videoPtsCount:0,firstVideoPts:-1,lastVideoPts:-1,adtsCandidates:0,continuityErrors:0}
    if type(payload) <> "roByteArray" then return result
    total = payload.count()
    result.bytes = total
    if total < 188 then return result
    result.packetCount = total \ 188
    result.trailingBytes = total mod 188
    result.aligned = true
    lastCounters = {}
    haveCounters = {}
    audioPidFlags = {}
    for packetIndex = 0 to result.packetCount-1
        offset = packetIndex*188
        if payload[offset] <> &H47
            result.syncErrors++
        else
            pid = (payload[offset+1] mod 32)*256+payload[offset+2]
            header = payload[offset+3]
            adaptationControl = (header \ 16) mod 4
            continuity = header mod 16
            hasPayload = adaptationControl = 1 or adaptationControl = 3
            payloadStart = offset+4
            if adaptationControl = 3 then payloadStart = offset+5+payload[offset+4]
            if hasPayload and payloadStart < offset+188
                key = pid.toStr()
                if pid <> 8191
                    if haveCounters[key] = true
                        if continuity <> ((lastCounters[key]+1) mod 16) then result.continuityErrors++
                    end if
                    lastCounters[key] = continuity
                    haveCounters[key] = true
                end if
                if pid = 0
                    pointer = payload[payloadStart]
                    sectionStart = payloadStart+1+pointer
                    if sectionStart+12 <= offset+188 and payload[sectionStart] = 0
                        sectionLength = (payload[sectionStart+1] mod 16)*256+payload[sectionStart+2]
                        sectionEnd = sectionStart+3+sectionLength
                        if sectionEnd <= offset+188
                            entry = sectionStart+8
                            while entry+4 <= sectionEnd-4
                                programNumber = payload[entry]*256+payload[entry+1]
                                if programNumber > 0
                                    result.pmtPid = (payload[entry+2] mod 32)*256+payload[entry+3]
                                    exit while
                                end if
                                entry += 4
                            end while
                        end if
                    end if
                else if pid = result.pmtPid and result.pmtPid >= 0
                    pointer = payload[payloadStart]
                    sectionStart = payloadStart+1+pointer
                    if sectionStart+12 <= offset+188 and payload[sectionStart] = 2
                        sectionLength = (payload[sectionStart+1] mod 16)*256+payload[sectionStart+2]
                        sectionEnd = sectionStart+3+sectionLength
                        if sectionEnd <= offset+188
                            result.pmtPackets++
                            programInfoLength = (payload[sectionStart+10] mod 16)*256+payload[sectionStart+11]
                            entry = sectionStart+12+programInfoLength
                            while entry+5 <= sectionEnd-4
                                streamType = payload[entry]
                                elementaryPid = (payload[entry+1] mod 32)*256+payload[entry+2]
                                esInfoLength = (payload[entry+3] mod 16)*256+payload[entry+4]
                                if streamType = 27
                                    result.videoPid = elementaryPid
                                else if streamType = 15 or streamType = 17
                                    result.aac = true
                                    if not audioPidFlags.doesExist(elementaryPid.toStr())
                                        audioPidFlags[elementaryPid.toStr()] = true
                                        if result.audioPids <> "" then result.audioPids += ","
                                        result.audioPids += elementaryPid.toStr()
                                    end if
                                end if
                                entry += 5+esInfoLength
                            end while
                        end if
                    end if
                end if
                isAudioPid = audioPidFlags.doesExist(pid.toStr()) and audioPidFlags[pid.toStr()]
                isVideoPid = pid = result.videoPid and result.videoPid >= 0
                if isAudioPid or isVideoPid
                    dataStart = payloadStart
                    if payload[offset+1] >= 64 and payload[offset+1] < 128
                        if payloadStart+9 < offset+188 and payload[payloadStart] = 0 and payload[payloadStart+1] = 0 and payload[payloadStart+2] = 1
                            pesFlags = (payload[payloadStart+7] \ 64) mod 4
                            pesHeaderLength = payload[payloadStart+8]
                            if (pesFlags = 2 or pesFlags = 3) and pesHeaderLength >= 5 and payloadStart+14 <= offset+188
                                pts = rpHdTaskReadPts(payload,payloadStart+9)
                                if pts >= 0
                                    if isAudioPid
                                        if result.ptsCount = 0 then result.firstPts = pts
                                        result.lastPts = pts
                                        result.ptsCount++
                                    else
                                        if result.videoPtsCount = 0 then result.firstVideoPts = pts
                                        result.lastVideoPts = pts
                                        result.videoPtsCount++
                                    end if
                                end if
                            end if
                            dataStart = payloadStart+9+pesHeaderLength
                        end if
                    end if
                    if isAudioPid and dataStart < offset+188
                        for scan = dataStart to offset+186
                            if payload[scan] = 255 and payload[scan+1] >= 240 and payload[scan+1] <= 247 then result.adtsCandidates++
                        end for
                    end if
                end if
            end if
        end if
    end for
    result.patPackets = 0
    for packetIndex = 0 to result.packetCount-1
        offset = packetIndex*188
        if payload[offset] = &H47
            pid = (payload[offset+1] mod 32)*256+payload[offset+2]
            if pid = 0 then result.patPackets++
        end if
    end for
    return result
end function

function rpHdTaskReadPts(payload as object, offset as integer) as dynamic
    if offset < 0 or offset+4 >= payload.count() then return -1
    b0 = payload[offset]
    b1 = payload[offset+1]
    b2 = payload[offset+2]
    b3 = payload[offset+3]
    b4 = payload[offset+4]
    return (b0 mod 16)*536870912+b1*4194304+(b2 \ 4)*32768+b3*128+(b4 \ 2)
end function

function rpHdTaskResolveEmbeds(embeds as object, provider as string, answer as object, fetcher as dynamic, decoderAccept as dynamic, retry = 0 as integer, embedReferer = "" as string, mediaReferer = "https://vimeos.net/" as string) as object
    count = embeds.count()
    if count > 6 then count = 6
    answer.embedAttempts = 0
    answer.variantAttempts = 0
    embedOffset = 0
    if count > 0 then embedOffset = retry mod count
    if embedReferer = "" then embedReferer = rpHdTaskProviderReferer(provider)
    for i = 0 to count-1
        embedIndex = (i+embedOffset) mod count
        embed = embeds[embedIndex]
        ' The HLS host may validate the page that embeds its player.
        ' Use the exact validated embed page as Referer instead of a fixed site root.
        mediaReferer = embed.url
        answer.embedAttempts++
        rpHdTaskBeginSlice(count-i)
        response = fetcher(embed.url,"embed",embedReferer)
        if response.cancelled then return rpHdTaskFailure(answer,response)
        if response.ok
            masterUrl = rpHdOnlineMediaUrl(response.body)
            if masterUrl <> ""
                response = fetcher(masterUrl,"media",mediaReferer)
                if response.cancelled then return rpHdTaskFailure(answer,response)
                if response.ok
                    master = rpHdOnlineMaster(response.body,masterUrl)
                    print "[RokuPlus hls] master variants="; master.variants.count(); " audioTracks="; master.audioTracks.count(); " mediaTags="
                    print "[RokuPlus hls] master variants="; "cont"; master.mediaTagCount; " audioMediaTags="; master.audioMediaTagCount; " audioGroups="
                    print "[RokuPlus hls] master variants="; "cont"; master.audioGroupCount; " variantAudioGroups="; master.variantAudioGroupCount; " encrypted="
                    print "[RokuPlus hls] master variants="; "cont"; master.encrypted
                    for each audioTrack in master.audioTracks
                        uriState = "missing"
                        if audioTrack.url <> "" then uriState = "present"
                        print "[RokuPlus hls] audio group="; audioTrack.group; " language="; audioTrack.language; " name="; audioTrack.name; " default="
                        print "[RokuPlus hls] audio group="; "cont"; audioTrack.default; " uri="; uriState
                    end for
                    candidates = {variants:[],audioTracks:master.audioTracks,encrypted:master.encrypted}
                    for each variant in master.variants
                        print "[RokuPlus hls] variant group="; variant.audioGroup; " resolution="; variant.width; "x"; variant.height; " fps="; variant.fps
                        print "[RokuPlus hls] variant group="; "cont"; " bandwidth="; variant.bandwidth; " averageBandwidth="; variant.averageBandwidth; " codecs="
                        print "[RokuPlus hls] variant group="; "cont"; variant.codecs; " videoRange="; variant.videoRange; " hdcp="; variant.hdcpLevel
                        if rpHdTaskSpanishAudio(master,variant) then candidates.variants.push(variant)
                    end for
                    print "[RokuPlus hls] spanish-compatible variants="; candidates.variants.count()
                    ' Use every Spanish-compatible rendition; do not pin playback to one resolution.
                    choices = rpHdTaskStableVariants(candidates,decoderAccept)
                    print "[RokuPlus hls-test] eligibleVariants="; choices.count()
                    variantOffset = 0
                    if choices.count() > 0 then variantOffset = (retry \ count) mod choices.count()
                    for qualityAttempt = 0 to choices.count()-1
                        if rpHdTaskSliceExpired() then exit for
                        variantIndex = (qualityAttempt+variantOffset) mod choices.count()
                        selected = choices[variantIndex]
                        print "[RokuPlus hls-test] selectedPlaylist="; rpHdTaskSafeUrl(selected.url)
                        answer.variantAttempts++
                        child = fetcher(selected.url,"media",mediaReferer)
                        if child.cancelled then return rpHdTaskFailure(answer,child)
                        playable = child.ok and rpHdTaskMediaManifest(child.body,selected.url)
                        segmentUrl = ""
                        candidateStage = "child_fetch_failed"
                        if child.ok
                            candidateStage = "manifest_rejected"
                            if playable
                                candidateStage = "segment_not_ts"
                                segmentUrl = rpHdTaskFirstSegment(child.body,selected.url)
                                ' Only this tested TS path has an AVC/AAC byte validator.
                                ' Codec labels alone must not send a dead or silent stream to Video.
                                playable = rpHdTaskTsSegment(segmentUrl)
                                if playable
                                    candidateStage = "sample_fetch_failed"
                                    sample = fetcher(segmentUrl,"sample",mediaReferer)
                                    if sample.cancelled then return rpHdTaskFailure(answer,sample)
                                    if sample.ok
                                        playable = rpHdOnlineMuxedAvcAac(sample.bytes)
                                        candidateStage = "sample_rejected"
                                        if playable then candidateStage = "accepted"

                                        ' Keep startup validation to one bounded TS sample.
                                        ' Extra segment-boundary and full-segment probes delayed playback
                                        ' without changing the native HLS stream returned to Roku.
                                    end if
                                end if
                            end if
                        end if
                        print "[RokuPlus candidate] result="; candidateStage
                        if playable
                            relaySegments = rpHdTaskSegmentList(child.body,selected.url)
                            if relaySegments.count() > 1
                                ' Diagnostic-only: inspect external audio playlists; playback remains the validated video TS relay.
                                rpHdTaskBeginSlice(1)
                                videoAudit = rpHdTaskAuditAudioSegment(sample.bytes)
                                audioAudit = rpHdTaskAuditExternalAudio(master,selected,fetcher,mediaReferer,videoAudit)
                                answer.segmentUrls = relaySegments
                                answer.tsRelayEnabled = true
                                segmentDurations = rpHdTaskSegmentDurations(child.body,relaySegments.count())
                                if segmentDurations.count() = relaySegments.count()
                                    answer.segmentDurations = segmentDurations
                                    print "[RokuPlus ts-relay] candidate_segments="; relaySegments.count(); " duration_entries="; segmentDurations.count()
                                else
                                    answer.segmentDurations = []
                                    print "[RokuPlus ts-relay] duration_metadata_unavailable segments="; relaySegments.count()
                                end if
                                answer.url = relaySegments[0]
                                answer.streamFormat = "ts"
                                answer.mediaHeaders = {Referer:mediaReferer, "User-Agent":rpHdTaskUserAgent()}
                                answer.description = "H.264 · "+selected.height.toStr()+"p"
                                if selected.audioGroup <> "" and rpHdTaskSpanishAudio(master,selected) then answer.description = "Audio español verificado · H.264 · "+selected.height.toStr()+"p"
                                answer.language = embed.language
                                answer.width = selected.width
                                answer.height = selected.height
                                answer.codecs = selected.codecs
                                answer.seekSupport = "ts-relay"
                                print "[RokuPlus resolve] provider="; provider; " format=ts playlist=segment-relay height="; selected.height
                                answer.attemptUsed = embedIndex+variantIndex*count
                                answer.ok = true
                                answer.message = ""
                                m.hdProviderDeadline = 0
                                return answer
                            else
                                candidateStage = "relay_segments_unavailable"
                                print "[RokuPlus ts-relay] disabled reason=segment_list_unavailable"
                            end if
                        end if
                    end for
                end if
            end if
        end if
    end for
    m.hdProviderDeadline = 0
    answer.message = "No hay una fuente H.264 en español compatible disponible para este título. Prueba otra opción de la misma película."
    return answer
end function

' Audit the complete child playlist without printing signed segment URLs or query tokens.
sub rpHdTaskLogManifest(body as dynamic, baseUrl as string)
    text = orbitText(body,2097153)
    lineCount = 0
    segmentCount = 0
    extinfCount = 0
    totalDuration = 0.0
    minDuration = 0.0
    maxDuration = 0.0
    targetDuration = ""
    targetValue = 0.0
    mediaSequence = ""
    playlistType = ""
    version = ""
    discontinuities = 0
    byteRanges = 0
    programDates = 0
    invalidExtinf = 0
    targetOverruns = 0
    hasEndList = false
    hasIndependent = false
    hasMap = false
    hasKey = false
    firstSegment = ""
    for each raw in text.split(chr(10))
        line = raw.trim()
        if line <> ""
            lineCount++
            if left(line,8) = "#EXTINF:"
                extinfCount++
                value = mid(line,9).split(",")[0].trim()
                parsedDuration = value.toFloat()
                if parsedDuration > 0
                    totalDuration += parsedDuration
                    if minDuration = 0 or parsedDuration < minDuration then minDuration = parsedDuration
                    if parsedDuration > maxDuration then maxDuration = parsedDuration
                    if targetValue > 0 and parsedDuration > targetValue then targetOverruns++
                else
                    invalidExtinf++
                end if
            else if left(line,21) = "#EXT-X-TARGETDURATION"
                targetDuration = mid(line,instr(1,line,":")+1).trim()
                targetValue = targetDuration.toFloat()
            else if left(line,21) = "#EXT-X-MEDIA-SEQUENCE"
                mediaSequence = mid(line,instr(1,line,":")+1).trim()
            else if left(line,20) = "#EXT-X-PLAYLIST-TYPE"
                playlistType = mid(line,instr(1,line,":")+1).trim()
            else if left(line,14) = "#EXT-X-VERSION"
                version = mid(line,instr(1,line,":")+1).trim()
            else if left(line,14) = "#EXT-X-ENDLIST"
                hasEndList = true
            else if left(line,20) = "#EXT-X-DISCONTINUITY"
                discontinuities++
            else if left(line,17) = "#EXT-X-BYTERANGE:"
                byteRanges++
            else if left(line,24) = "#EXT-X-PROGRAM-DATE-TIME"
                programDates++
            else if left(line,28) = "#EXT-X-INDEPENDENT-SEGMENTS"
                hasIndependent = true
            else if left(line,11) = "#EXT-X-MAP:"
                hasMap = true
            else if left(line,11) = "#EXT-X-KEY:"
                hasKey = true
            else if left(line,1) <> "#"
                segmentCount++
                resolved = rpHdOnlineJoin(baseUrl,line)
                if firstSegment = "" then firstSegment = rpHdTaskSafeUrl(resolved)
                if resolved = "" then print "[RokuPlus hls-manifest] WARNING unresolvedSegment index="; segmentCount
            end if
        end if
    end for
    averageDuration = 0.0
    if extinfCount > 0 then averageDuration = totalDuration/extinfCount
    print "[RokuPlus hls-manifest] version="; version; " targetDuration="; targetDuration; " mediaSequence="; mediaSequence; " playlistType="; playlistType
    print "[RokuPlus hls-manifest] segments="; segmentCount; " extinfCount="; extinfCount; " totalDuration="; totalDuration; " endList="; hasEndList
    print "[RokuPlus hls-manifest] duration min="; minDuration; " max="; maxDuration; " avg="; averageDuration; " invalid="; invalidExtinf; " targetOverruns="; targetOverruns
    print "[RokuPlus hls-manifest] discontinuities="; discontinuities; " byteRanges="; byteRanges; " programDates="; programDates
    print "[RokuPlus hls-manifest] discontinuities="; "cont"; " independent="; hasIndependent; " map="; hasMap; " key="; hasKey; " lines="
    print "[RokuPlus hls-manifest] discontinuities="; "cont"; lineCount
    if firstSegment <> "" then print "[RokuPlus hls-manifest] firstSegment="; firstSegment
end sub

' Return only a host for diagnostics; never print media URLs, paths, or tokens.
function rpHdTaskSafeHost(value as dynamic) as string
    url = orbitText(value,4096)
    match = CreateObject("roRegex","^https://([^/?#]+)","i").match(url)
    if match.count() < 2 then return "unknown"
    return lcase(match[1])
end function

' Diagnostic URL: omit query strings and fragments so signed CDN tokens are not printed.
function rpHdTaskSafeUrl(value as dynamic) as string
    url = orbitText(value,4096)
    queryAt = instr(1,url,"?")
    fragmentAt = instr(1,url,"#")
    cutAt = 0
    if queryAt > 0 then cutAt = queryAt
    if fragmentAt > 0 and (cutAt = 0 or fragmentAt < cutAt) then cutAt = fragmentAt
    if cutAt > 0 then url = left(url,cutAt-1)
    return url
end function

function rpHdTaskResponseHeader(headers as dynamic, wanted as string) as string
    if type(headers) <> "roAssociativeArray" then return ""
    for each name in headers
        if lcase(name) = lcase(wanted) then return left(orbitText(headers[name],256),256)
    end for
    return ""
end function

function rpHdTaskStableVariants(master as object, decoderAccept as dynamic) as object
    choices = []
    candidates = {variants:master.variants,encrypted:master.encrypted}
    for attempt = 1 to 4
        selected = rpHdTaskSelectStableVariant(candidates,decoderAccept)
        if selected = invalid then exit for
        choices.push(selected)
        remaining = []
        for each variant in candidates.variants
            if variant.url <> selected.url then remaining.push(variant)
        end for
        candidates.variants = remaining
    end for
    return choices
end function

' Prefer a reasonable HD stream before trying more demanding resolutions.
' Every choice still passes the common AVC/AAC and native decoder guards.
function rpHdTaskSelectStableVariant(master as object, decoderAccept as dynamic) as dynamic
    preferred = {variants:[],encrypted:master.encrypted}
    for each variant in master.variants
        height = orbitInteger(variant.height,1080)
        bandwidth = orbitInteger(variant.bandwidth,100000000)
        if height <= 720 and (bandwidth <= 4000000 or bandwidth = 0)
            preferred.variants.push(variant)
        end if
    end for
    selected = rpHdOnlineSelectVariant(preferred,decoderAccept)
    if selected <> invalid then return selected
    lower = {variants:[],encrypted:master.encrypted}
    for each variant in master.variants
        if variant.height <= 720 then lower.variants.push(variant)
    end for
    selected = rpHdOnlineSelectVariant(lower,decoderAccept)
    if selected <> invalid then return selected
    return rpHdOnlineSelectVariant(master,decoderAccept)
end function

function rpHdTaskTsSegment(url as string) as boolean
    return rpHdOnlineCdn(url) <> "" and CreateObject("roRegex","\.ts(\?[^#]*)?$","i").isMatch(url)
end function

' Remove a trailing year from a series display title and retain it as metadata.
' This allows providers with different IDs/title formatting to be deduplicated.
' Cross-provider identity: trust matching external IDs first. If both records
' carry conflicting external IDs, never merge them by title. Title/year is a
' conservative fallback for providers that do not expose shared identifiers.
' Canonical identity for the one confirmed translated series pair.
' This is deliberately an exact alias, not fuzzy title matching.
function rpHdTaskKnownSeriesTitleKey(title as dynamic) as string
    key = lcase(orbitText(title,200).trim())
    key = CreateObject("roRegex","\s*\\(((?:19|20)[0-9]{2})\\)\s*$","").replace(key,"").trim()
    key = key.replace("á","a").replace("é","e").replace("í","i").replace("ó","o").replace("ú","u").replace("ñ","n")
    key = CreateObject("roRegex","\s+","").replace(key,"")
    if key = "thelastmanonearth" or key = "elultimohombreenlatierra"
        return "tmdb-tv-61888"
    end if
    return ""
end function

function rpHdTaskSameCatalogItem(existing as dynamic, item as dynamic) as boolean
    if type(existing) <> "roAssociativeArray" or type(item) <> "roAssociativeArray" then return false
    if orbitText(existing.kind,16) <> orbitText(item.kind,16) then return false
    existingTmdb = orbitText(existing.providerTmdbId,40)
    itemTmdb = orbitText(item.providerTmdbId,40)
    if existingTmdb <> "" and itemTmdb <> ""
        return existingTmdb = itemTmdb
    end if
    existingImdb = lcase(orbitText(existing.imdbId,40))
    itemImdb = lcase(orbitText(item.imdbId,40))
    if existingImdb <> "" and itemImdb <> ""
        return existingImdb = itemImdb
    end if
    if existingTmdb <> "" or itemTmdb <> "" or existingImdb <> "" or itemImdb <> ""
        ' One source has an ID and the other does not: allow a strict title/year fallback.
        ' Conflicting IDs were already rejected above.
    end if
    if orbitText(existing.kind,16) = "series"
        existingKnownKey = rpHdTaskKnownSeriesTitleKey(existing.title)
        itemKnownKey = rpHdTaskKnownSeriesTitleKey(item.title)
        if existingKnownKey <> "" and existingKnownKey = itemKnownKey then return true
    end if
    existingKey = CreateObject("roRegex","\s+","").replace(lcase(orbitText(existing.title,200).trim()),"")
    itemKey = CreateObject("roRegex","\s+","").replace(lcase(orbitText(item.title,200).trim()),"")
    if existingKey = "" or itemKey = "" or existingKey <> itemKey then return false
    existingYear = orbitText(existing.year,4)
    itemYear = orbitText(item.year,4)
    return existingYear = "" or itemYear = "" or existingYear = itemYear
end function

function rpHdTaskNormalizeSeriesTitle(item as dynamic) as dynamic
    if type(item) <> "roAssociativeArray" then return item
    title = orbitText(item.title,200).trim()
    match = CreateObject("roRegex","\s*\(((?:19|20)[0-9]{2})\)\s*$","").match(title)
    if match.count() > 1
        if orbitText(item.year,4) = "" then item.year = match[1]
        title = CreateObject("roRegex","\s*\(((?:19|20)[0-9]{2})\)\s*$","").replace(title,"").trim()
        item.title = title
    end if
    return item
end function

' skip encodes source-page rounds in steps of twenty, not displayed-card count.
' JSON providers request twenty records; SSR pages may contain more cards.
' Round-robin output keeps source order while merging the same series across providers.
function rpHdTaskGlobalSearch(request as object, answer as object, fetcher as dynamic, sources as dynamic) as object
    query = rpHdOnlineSearchQuery(request.query)
    if query = "" then return answer
    merged = []
    failures = 0
    successes = 0
    for each searchKind in ["movie","series"]
        partRequest = {
            operation:"catalog", kind:searchKind, provider:request.provider
            query:query, skip:0, requestId:request.requestId
        }
        partAnswer = {
            ok:false, cancelled:false, requestId:answer.requestId
            operation:"catalog", kind:searchKind, provider:answer.provider
            items:[], message:""
        }
        if answer.provider = "all"
            partAnswer = rpHdTaskCombinedCatalog(partRequest,partAnswer,fetcher,sources)
        else
            response = rpHdTaskCatalogPage(answer.provider,searchKind,1,query,fetcher)
            partAnswer.ok = response.ok
            partAnswer.cancelled = response.cancelled
            partAnswer.message = response.message
            if response.ok then partAnswer.items = response.items
        end if
        if partAnswer.cancelled then return rpHdTaskFailure(answer,partAnswer)
        if partAnswer.ok
            successes++
            for each resultItem in partAnswer.items
                merged.push(resultItem)
            end for
        else
            failures++
        end if
    end for
    answer.items = orbitUniqueCatalogItems(merged)
    answer.ok = successes > 0
    answer.partial = failures > 0
    answer.hasMore = false
    answer.nextSkip = 0
    answer.message = ""
    if not answer.ok then answer.message = "Ninguna fuente respondió a la búsqueda. Vuelve a intentar."
    return answer
end function

function rpHdTaskCombinedCatalog(request as object, answer as object, fetcher as dynamic, sources = invalid as dynamic) as object
    skip = orbitInteger(request.skip,200000)
    page = (skip \ 20)+1
    query = rpHdOnlineSearchQuery(request.query)
    if type(sources) <> "roArray" then sources = rpHdOnlineProviderIds()
    applicable = []
    for each value in sources
        source = rpHdOnlineProvider(value)
        if source <> "" and source <> "all"
            ' A movies-only adapter must not mask failures of every series source.
            if source <> "cinecalidad" or answer.kind <> "series" then applicable.push(source)
        end if
    end for
    sources = applicable
    pages = []
    failures = []
    successes = []
    total = 0
    totalKnown = true
    more = false
    rows = 0
    count = sources.count()
    if count > 8 then count = 8
    for i = 0 to count-1
        source = rpHdOnlineProvider(sources[i])
        if source <> "" and source <> "all"
            rpHdTaskBeginSlice(count-i)
            sourceElapsed = CreateObject("roTimespan")
            sourceElapsed.mark()
            response = rpHdTaskCatalogPage(source,answer.kind,page,query,fetcher)
            sourceMs = sourceElapsed.totalMilliseconds()
            m.hdProviderDeadline = 0
            print "[RokuPlus catalog] source="; source; " elapsed_ms="; sourceMs; " ok="; response.ok; " cancelled="; response.cancelled
            if response.cancelled then return rpHdTaskFailure(answer,response)
            if response.ok
                catalog = response
                pages.push(catalog.items)
                if catalog.items.count() > rows then rows = catalog.items.count()
                successes.push(source)
                total += catalog.total
                if catalog.totalKnown = false then totalKnown = false
                if catalog.total = 0 and (catalog.items.count() > 0 or catalog.hasMore) then totalKnown = false
                if catalog.hasMore then more = true
            else
                failures.push(source)
            end if
        end if
    end for
    answer.items = []
    deduped = []
    if rows > 200 then rows = 200
    for row = 0 to rows-1
        for each entries in pages
            if row < entries.count()
                item = entries[row]
                if answer.kind = "series" or answer.kind = "movie"
                    if answer.kind = "series" then item = rpHdTaskNormalizeSeriesTitle(item)
                    duplicateIndex = -1
                    for existingIndex = 0 to deduped.count()-1
                        existing = deduped[existingIndex]
                        if rpHdTaskSameCatalogItem(existing,item)
                            duplicateIndex = existingIndex
                            exit for
                        end if
                    end for
                    if duplicateIndex < 0
                        deduped.push(item)
                    else
                        ' Keep the first provider identity and fill only missing display metadata.
                        existing = deduped[duplicateIndex]
                        if existing.year = "" and item.year <> "" then existing.year = item.year
                        if existing.poster = "" and item.poster <> "" then existing.poster = item.poster
                        if existing.background = "" and item.background <> "" then existing.background = item.background
                        if existing.description = "" and item.description <> "" then existing.description = item.description
                        if existing.providerTmdbId = "" and item.providerTmdbId <> "" then existing.providerTmdbId = item.providerTmdbId
                        if existing.imdbId = "" and item.imdbId <> "" then existing.imdbId = item.imdbId
                    end if
                else
                    deduped.push(item)
                end if
            end if
        end for
    end for
    answer.items = deduped
    answer.sourceFailures = failures
    answer.sourcesSearched = successes
    answer.partial = failures.count() > 0
    if failures.count() > 0 then totalKnown = false
    answer.totalKnown = totalKnown
    answer.total = 0
    if totalKnown then answer.total = total
    answer.hasMore = more
    answer.nextSkip = page*20
    answer.ok = successes.count() > 0
    if answer.ok
        answer.message = ""
        if answer.partial then answer.message = "Algunas fuentes no respondieron. Se muestran las opciones disponibles."
    else
        answer.message = "Ninguna fuente HD respondió. Vuelve a intentar la búsqueda."
    end if
    return answer
end function

function rpHdTaskCatalogPage(provider as string, kind as string, page as integer, query as string, fetcher as dynamic) as object
    if provider = "seriesmetro"
        response = rpHdSeriesmetroCatalogRequest({operation:"catalog",provider:provider,kind:kind,skip:(page-1)*20,query:query},fetcher)
        response.totalKnown = false
        if response.ok then response.totalKnown = response.items.count() = 0 and not response.hasMore
        return response
    end if
    if provider = "cinecalidad"
        response = rpHdCinecalidadCatalogRequest({operation:"catalog",provider:provider,kind:kind,skip:(page-1)*20,query:query},fetcher)
        response.totalKnown = false
        if response.ok then response.totalKnown = response.items.count() = 0 and not response.hasMore
        return response
    end if
    action = "catalog"
    if query <> "" then action = "search"
    endpoint = rpHdOnlineEndpoint(provider,action,{kind:kind,page:page,query:query})
    response = rpHdTaskFetchCatalog(endpoint,provider,fetcher)
    if not response.ok then return response
    catalog = rpHdOnlineCatalog(response.data,provider,kind,page)
    totalKnown = true
    if catalog.total = 0 and (catalog.items.count() > 0 or catalog.hasMore) then totalKnown = false
    ' CineHax search paginates a mixed movie/series response before filtering.
    if provider = "cinehax" and query <> "" then totalKnown = false
    total = 0
    if totalKnown then total = catalog.total
    return {ok:true,cancelled:false,message:"",items:catalog.items,hasMore:catalog.hasMore,nextSkip:(catalog.nextPage-1)*20,total:total,totalKnown:totalKnown}
end function

' Reserve a fair share of the remaining operation deadline for each source.
' The injected offline fetcher has no clock; only real network requests use it.
sub rpHdTaskBeginSlice(remaining as integer)
    m.hdProviderDeadline = 0
    if remaining < 1 then remaining = 1
    if m.hdElapsed <> invalid
        now = m.hdElapsed.totalMilliseconds()
        totalBudget = 40000
        if GetInterface(m.hdTotalBudgetMs,"ifInt") <> invalid then totalBudget = m.hdTotalBudgetMs
        budget = (totalBudget-now) \ remaining
        ' In "Todas", one slow provider must not consume the entire window
        ' reserved for the remaining sources. Keep a fair share, capped at 9s.
        if budget > 9000 then budget = 9000
        if budget < 0 then budget = 0
        m.hdProviderDeadline = now+budget
    end if
end sub

function rpHdTaskSliceExpired() as boolean
    if m.hdElapsed = invalid then return false
    now = m.hdElapsed.totalMilliseconds()
    totalBudget = 40000
    if GetInterface(m.hdTotalBudgetMs,"ifInt") <> invalid then totalBudget = m.hdTotalBudgetMs
    if now >= totalBudget then return true
    if GetInterface(m.hdProviderDeadline,"ifInt") <> invalid
        if m.hdProviderDeadline > 0 and now >= m.hdProviderDeadline then return true
    end if
    return false
end function

function rpHdTaskLoadEpisodes(parent as object, season as integer, fetcher as dynamic) as object
    answer = {ok:false,cancelled:false,message:"No se pudieron cargar los episodios HD.",seasons:[],seasonNumbers:[]}
    provider = parent.provider
    pages = []
    declared = []
    page = 1
    complete = false
    for attempt = 1 to 12
        endpoint = rpHdOnlineEndpoint(provider,"episodes",{id:parent.providerId,season:season,page:page})
        response = rpHdTaskFetchJson(endpoint,fetcher)
        if not response.ok then return rpHdTaskFailure(answer,response)
        normalized = rpHdOnlineEpisodes(response.data,provider,parent)
        pages.push(normalized.seasons)
        for each number in normalized.seasonNumbers
            if not rpHdTaskHasNumber(declared,number) then declared.push(number)
        end for
        if not normalized.hasMore or provider = "allcalidad"
            complete = true
            exit for
        end if
        if normalized.nextPage <= page then exit for
        page = normalized.nextPage
    end for
    if not complete
        answer.message = "Esta temporada es demasiado extensa para cargarla ahora. Vuelve a intentar."
        return answer
    end if
    merged = rpHdTaskMergeSeasons(pages,declared,season,provider = "allcalidad")
    answer.seasons = merged.seasons
    answer.seasonNumbers = merged.seasonNumbers
    answer.ok = answer.seasons.count() > 0
    if answer.ok then answer.message = ""
    return answer
end function

function rpHdTaskMergeSeasons(pages as object, declared as object, requested as integer, allLoaded as boolean) as object
    map = {}
    seen = {}
    for each page in pages
        for each season in page
            key = season.number.toStr()
            if not map.doesExist(key) then map[key] = {number:season.number,episodes:[],loaded:true}
            for each item in season.episodes
                if not seen.doesExist(item.id)
                    map[key].episodes.push(item)
                    seen[item.id] = true
                end if
            end for
        end for
    end for
    for each number in declared
        key = number.toStr()
        if not map.doesExist(key) then map[key] = {number:number,episodes:[],loaded:allLoaded or number = requested}
    end for
    answer = {seasons:[],seasonNumbers:[]}
    for number = 0 to 999
        key = number.toStr()
        if map.doesExist(key)
            map[key].episodes.sortBy("episode")
            answer.seasons.push(map[key])
            answer.seasonNumbers.push(number)
        end if
    end for
    return answer
end function

function rpHdTaskHasNumber(numbers as object, value as integer) as boolean
    for each number in numbers
        if number = value then return true
    end for
    return false
end function

function rpHdTaskInputItem(value as dynamic, provider as string) as dynamic
    if type(value) <> "roAssociativeArray" or provider = "" or provider = "all" then return invalid
    number = orbitInteger(value.providerId,999999999)
    kind = orbitText(value.kind,10)
    if number < 1 or rpHdOnlineProvider(value.provider) <> provider then return invalid
    if kind <> "movie" and kind <> "series" and kind <> "episode" then return invalid
    id = "hdo-"+provider+"-"+number.toStr()
    if value.id <> id then return invalid
    return {
        id:id,imdbId:"",kind:kind,library:"hd-online",provider:provider,providerId:number
        providerSlug:orbitText(value.providerSlug,200),title:orbitText(value.title,200)
        poster:orbitHttpsUrl(value.poster),background:orbitHttpsUrl(value.background)
        description:orbitText(value.description),year:orbitText(value.year,4)
        runtime:orbitInteger(value.runtime,86400),language:"",seasons:[]
        season:orbitInteger(value.season,999),episode:orbitInteger(value.episode,9999)
        seriesTitle:orbitText(value.seriesTitle,200)
    }
end function

function rpHdTaskFetchJson(endpoint as string, fetcher as dynamic) as object
    response = fetcher(endpoint,"api","")
    if not response.ok then return response
    body = response.body
    if instr(1,endpoint,"https://cinehax.org/api/rest/v1/") = 1 then body = rpHdCinehaxJsonText(body)
    data = ParseJson(body)
    if type(data) <> "roAssociativeArray"
        response.ok = false
        response.message = "La fuente HD devolvió datos que no se pueden leer."
        return response
    end if
    response.data = data
    return response
end function

function rpHdTaskFetchCatalog(endpoint as string, provider as string, fetcher as dynamic) as object
    response = rpHdTaskFetchJson(endpoint,fetcher)
    if not response.ok then return response
    valid = false
    if provider = "cinehax"
        valid = type(response.data.items) = "roArray"
    else if type(response.data.data) = "roAssociativeArray"
        valid = type(response.data.data.posts) = "roArray"
    end if
    if not valid
        response.ok = false
        response.message = "La fuente HD no devolvió un catálogo válido."
    end if
    return response
end function

function rpHdTaskFailure(answer as object, response as object) as object
    answer.ok = false
    answer.cancelled = response.cancelled = true
    message = orbitText(response.message,200)
    if message <> "" then answer.message = message
    return answer
end function

' A master playlist may link each video variant to an external audio group.
' Accept Spanish audio regardless of DEFAULT/AUTOSELECT ordering in the provider manifest.
function rpHdTaskAudioGroupCount(master as object, groupId as string) as integer
    count = 0
    for each track in master.audioTracks
        if track.group = groupId and track.url <> "" then count++
    end for
    return count
end function

' Keep the original master so Roku can expose alternate audio tracks.
' The selected rendition must pass the device capability guard; the Video node's
' maxVideoDecodeResolution ceiling is applied before playback to constrain ABR.
function rpHdTaskNativeAudioMasterSafe(master as object, selected as object, decoderAccept as dynamic) as boolean
    if master.encrypted or selected.audioGroup = "" then return false
    if type(master.audioTracks) <> "roArray" or type(master.variants) <> "roArray" then return false
    if rpHdTaskAudioGroupCount(master,selected.audioGroup) < 2 then return false
    spanishTrackFound = false
    for each track in master.audioTracks
        if track.group = selected.audioGroup
            language = lcase(orbitText(track.language,40))
            name = lcase(orbitText(track.name,120))
            if language = "es" or language = "spa" or left(language,3) = "es-" or instr(1,name,"español") > 0 or instr(1,name,"espanol") > 0 or instr(1,name,"spanish") > 0 or instr(1,name,"latino") > 0 or instr(1,name,"castellano") > 0
                spanishTrackFound = true
            end if
            if track.url = "" then return false
        end if
    end for
    if not spanishTrackFound then return false
    if selected.audioGroup = "" or selected.height > 720 or selected.width > 1280 then return false
    candidate = {variants:[selected],encrypted:false}
    if rpHdOnlineSelectVariant(candidate,decoderAccept) = invalid then return false
    return true
end function

function rpHdTaskSpanishAudio(master as object, variant as object) as boolean
    if variant.audioGroup = "" then return true
    for each track in master.audioTracks
        if track.group = variant.audioGroup
            language = lcase(orbitText(track.language,40))
            name = lcase(orbitText(track.name,120))
            if language = "es" or language = "spa" or left(language,3) = "es-" then return true
            if instr(1,name,"español") > 0 or instr(1,name,"espanol") > 0 or instr(1,name,"spanish") > 0 or instr(1,name,"latino") > 0 or instr(1,name,"castellano") > 0 then return true
        end if
    end for
    return false
end function

function rpHdTaskMediaManifest(body as dynamic, baseUrl as string) as boolean
    text = orbitText(body,2097153)
    if len(text) > 2097152 or left(text,7) <> "#EXTM3U" then return false
    if rpHdOnlineCdn(baseUrl) = "" then return false
    segments = 0
    for each raw in text.split(chr(10))
        line = raw.trim()
        if left(line,11) = "#EXT-X-KEY:"
            attrs = rpHdOnlineAttributes(line)
            if attrs.METHOD <> "NONE" then return false
        else if left(line,18) = "#EXT-X-STREAM-INF:"
            return false
        else if left(line,11) = "#EXT-X-MAP:"
            attrs = rpHdOnlineAttributes(line)
            if rpHdOnlineJoin(baseUrl,orbitText(attrs.URI,4096)) = "" then return false
        else if line <> "" and left(line,1) <> "#"
            if rpHdOnlineJoin(baseUrl,line) = "" then return false
            segments++
        end if
    end for
    return segments > 0
end function

function rpHdTaskExternalAudio(master as object, variant as object) as boolean
    for each track in master.audioTracks
        if track.group = variant.audioGroup and track.url <> "" then return true
    end for
    return false
end function

function rpHdTaskSegmentDurations(body as string, expectedCount as integer) as object
    durations = []
    pendingDuration = -1.0
    text = orbitText(body,2097153)
    if len(text) > 2097152 or expectedCount < 1 then return durations
    for each raw in text.split(chr(10))
        line = raw.trim()
        if left(line,8) = "#EXTINF:"
            value = Mid(line,9)
            comma = Instr(1,value,",")
            if comma > 0 then value = Left(value,comma-1)
            duration = Val(value)
            if duration <= 0 or duration > 3600 then return []
            pendingDuration = duration
        else if line <> "" and left(line,1) <> "#"
            if pendingDuration <= 0 then return []
            durations.push(pendingDuration)
            pendingDuration = -1.0
            if durations.count() > expectedCount then return []
        end if
    end for
    if durations.count() <> expectedCount then return []
    return durations
end function

function rpHdTaskSegmentList(body as string, baseUrl as string) as object
    segments = []
    for each raw in body.split(chr(10))
        line = raw.trim()
        if line <> "" and left(line,1) <> "#"
            url = rpHdOnlineJoin(baseUrl,line)
            if url = "" then return []
            segments.push(url)
            if segments.count() > 2000 then return []
        end if
    end for
    return segments
end function

function rpHdTaskFirstSegment(body as string, baseUrl as string) as string
    for each raw in body.split(chr(10))
        line = raw.trim()
        if line <> "" and left(line,1) <> "#" then return rpHdOnlineJoin(baseUrl,line)
    end for
    return ""
end function

function rpHdTaskCanDecode(variant as object) as boolean
    format = rpHdTaskDecodeFormat(variant)
    if format = invalid
        print "[RokuPlus decode-cap] validCodecDeclaration=false"
        return false
    end if
    device = CreateObject("roDeviceInfo")
    accepted = false
    for each codec in ["mpeg4 avc","h264"]
        response = device.canDecodeVideo({"codec":codec,"profile":format.profile,"level":format.capabilityLevel})
        supported = false
        if type(response) = "roAssociativeArray"
            if GetInterface(response.result,"ifBoolean") <> invalid then supported = response.result
        end if
        print "[RokuPlus decode-cap] codec="; codec; " profile="; format.profile; " level="; format.capabilityLevel; " supported="; supported
        if supported then accepted = true
    end for
    return accepted
end function

' CanDecodeVideo reports supported capability ceilings, not every source level.
' The JVC reports AVC high 4.1=true but 3.2/4.0=false with updated level=[4.1,4.2].
' Require the confirmed 4.1 ceiling only after validating an AVC <=4.1 source.
function rpHdTaskDecodeFormat(variant as dynamic) as dynamic
    if type(variant) <> "roAssociativeArray" then return invalid
    codecs = lcase(orbitText(variant.codecs,200))
    match = CreateObject("roRegex","(^|,)\s*avc1\.([0-9a-f]{6})(\s*,|$)","").match(codecs)
    aac = CreateObject("roRegex","(^|,)\s*mp4a\.40\.2(\s*,|$)","").isMatch(codecs)
    if match.count() < 3 or not aac or codecs.split(",").count() <> 2 then return invalid
    profileNumber = rpHdOnlineHex(left(match[2],2))
    levelNumber = rpHdOnlineHex(right(match[2],2))
    profile = ""
    if profileNumber = 66 then profile = "baseline"
    if profileNumber = 77 then profile = "main"
    if profileNumber = 100 then profile = "high"
    if profile = "" or levelNumber < 10 or levelNumber > 41 then return invalid
    validLevel = false
    for each level in [10,11,12,13,20,21,22,30,31,32,40,41]
        if levelNumber = level then validLevel = true
    end for
    if not validLevel then return invalid
    return {profile:profile,capabilityLevel:"4.1",sourceLevel:levelNumber}
end function

function rpHdTaskUserAgent() as string
    return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
end function

function rpHdTaskProviderReferer(provider as string) as string
    if provider = "lamovie" then return "https://lamovie.org/"
    if provider = "allcalidad" then return "https://allcalidad.re/"
    if provider = "cinehax" then return "https://cinehax.org/"
    return ""
end function

function rpHdTaskAllowedUrl(endpoint as string, role as string) as boolean
    if len(endpoint) > 4096 then return false
    if CreateObject("roRegex","[\x00-\x20\x7F\\]","").isMatch(endpoint) then return false
    if role = "api" then return CreateObject("roRegex","^https://(lamovie\.org/wp-api/v1/|allcalidad\.re/api/rest/|cinehax\.org/api/rest/v1/)[^#]*$","").isMatch(endpoint)
    if role = "tvmaze" then return CreateObject("roRegex","^https://api\.tvmaze\.com/(search/shows\?q=[^#]+|shows/[0-9]+/episodes)$","").isMatch(endpoint)
    if role = "player" then return CreateObject("roRegex","^https://videoapp\.mov/e/(movie/[0-9]+|tv/[0-9]+/[0-9]+/[0-9]+)$","").isMatch(endpoint)
    if role = "seriesmetro-season" then return rpHdTaskSeasonPost(endpoint) <> invalid
    if role = "seriesmetro-page"
        return CreateObject("roRegex","^https://www3\.seriesmetro\.net/(cartelera-(peliculas|series)/(page/[0-9]+/)?|(pelicula|serie|capitulo)/[a-z0-9-]+/|(page/[0-9]+/)?\?s=[^#]*|\?trembed=[0-9]+&trid=[0-9]+&trtype=[0-9]+)$","").isMatch(endpoint)
    end if
    if role = "cinecalidad-page"
        return CreateObject("roRegex","^https://www\.cinecalidad\.vg/(page/[0-9]+/|pelicula/[a-z0-9-]+/)?(\?s=[^#]*)?$","").isMatch(endpoint)
    end if
    if role = "embed"
        if CreateObject("roRegex","^https://fastream\.to/(embed-)?[a-zA-Z0-9_-]+(\.html)?$","").isMatch(endpoint) then return true
        return CreateObject("roRegex","^https://vimeos\.net/embed-[a-zA-Z0-9_-]+(\.html)?(\?[^#]*)?$","").isMatch(endpoint)
    end if
    if role = "media" or role = "sample" or role = "audio-sample" or role = "sample-tail" or role = "sample-full" then return rpHdOnlineCdn(endpoint) <> ""
    return false
end function

' A read-only episode listing uses one fixed WordPress action and numeric IDs.
' The browser-shaped query is never forwarded as an arbitrary POST payload.
function rpHdTaskSeasonPost(endpoint as string) as dynamic
    parts = CreateObject("roRegex","^https://www3\.seriesmetro\.net/wp-admin/admin-ajax\.php\?post=([0-9]{1,9})&season=([0-9]{1,3})$","").match(endpoint)
    if parts.count() < 3 then return invalid
    postId = orbitInteger(parts[1],999999999)
    season = orbitInteger(parts[2],999,-1)
    if postId < 1 or season < 0 then return invalid
    return {url:"https://www3.seriesmetro.net/wp-admin/admin-ajax.php",body:"action=action_select_season&post="+postId.toStr()+"&season="+season.toStr()}
end function

function rpHdTaskDownloadText(endpoint as string, role as string, referer as string) as object
    answer = {ok:false,cancelled:false,body:"",bytes:invalid,message:"No se pudo conectar con la fuente HD."}
    if not rpHdTaskAllowedUrl(endpoint,role) then return answer
    if m.top.cancelRequested
        answer.cancelled = true
        answer.message = "Consulta cancelada."
        return answer
    end if
    if rpHdTaskSliceExpired()
        answer.message = "La fuente HD tardó demasiado. Vuelve a intentar."
        return answer
    end if
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.enablePeerVerification(true)
    transfer.enableHostVerification(true)
    transfer.addHeader("User-Agent",rpHdTaskUserAgent())
    if role = "api" or role = "tvmaze"
        transfer.addHeader("Accept","application/json")
        if referer = "" and instr(1,endpoint,"https://cinehax.org/api/rest/v1/") = 1 then referer = "https://cinehax.org/"
    end if
    if referer <> "" then transfer.addHeader("Referer",referer)
    limit = 2097152
    if role = "sample" or role = "audio-sample"
        transfer.addHeader("Range","bytes=0-65535")
        limit = 131072
    else if role = "sample-tail"
        transfer.addHeader("Range","bytes=-65612")
        limit = 65612
    else if role = "sample-full"
        ' Diagnostic only: some provider first segments exceed 2 MiB.
        limit = 4194304
    end if
    transfer.enableEncodings(true)
    transfer.setUrl(endpoint)
    files = CreateObject("roFileSystem")
    filename = "tmp:/rokuplus-hd-"+CreateObject("roDeviceInfo").getRandomUUID()+".txt"
    requestFile = ""
    if role = "seriesmetro-season"
        post = rpHdTaskSeasonPost(endpoint)
        transfer.setUrl(post.url)
        transfer.addHeader("Content-Type","application/x-www-form-urlencoded")
        requestFile = filename+".request"
        if not WriteAsciiFile(requestFile,post.body)
            files.delete(requestFile)
            return answer
        end if
        started = transfer.asyncPostFromFileToFile(requestFile,filename)
    else
        started = transfer.asyncGetToFile(filename)
    end if
    if not started
        print "[RokuPlus http] role="; role; " host="; rpHdTaskSafeHost(endpoint); " started=false"
        files.delete(filename)
        if requestFile <> "" then files.delete(requestFile)
        return answer
    end if
    elapsed = CreateObject("roTimespan")
    elapsed.mark()
    finished = false
    code = 0
    responseHeaders = {}
    while not finished
        if m.top.cancelRequested
            answer.cancelled = true
            answer.message = "Consulta cancelada."
            exit while
        end if
        sliceExpired = rpHdTaskSliceExpired()
        elapsedMs = elapsed.totalMilliseconds()
        if sliceExpired
            answer.message = "La fuente HD tardó demasiado. Vuelve a intentar."
            exit while
        end if
        if elapsedMs >= 20000
            answer.message = "La fuente HD tardó demasiado. Vuelve a intentar."
            exit while
        end if
        if rpHdTaskFileSize(files.stat(filename)) > limit
            answer.message = "La respuesta HD supera el límite permitido."
            exit while
        end if
        event = wait(50,port)
        if type(event) = "roUrlEvent"
            if event.getSourceIdentity() = transfer.getIdentity() and event.getInt() = 1
                code = event.getResponseCode()
                responseHeaders = event.getResponseHeaders()
                finished = true
            end if
        end if
    end while
    if not finished then transfer.asyncCancel()
    answer.httpStatus = code
    answer.httpElapsedMs = elapsed.totalMilliseconds()
    answer.httpFinished = finished
    answer.httpContentType = rpHdTaskResponseHeader(responseHeaders,"content-type")
    answer.httpContentLength = rpHdTaskResponseHeader(responseHeaders,"content-length")
    answer.httpContentRange = rpHdTaskResponseHeader(responseHeaders,"content-range")
    answer.httpAcceptRanges = rpHdTaskResponseHeader(responseHeaders,"accept-ranges")
    answer.httpCacheControl = rpHdTaskResponseHeader(responseHeaders,"cache-control")
    answer.httpAge = rpHdTaskResponseHeader(responseHeaders,"age")
    answer.httpServer = rpHdTaskResponseHeader(responseHeaders,"server")
    answer.httpVia = rpHdTaskResponseHeader(responseHeaders,"via")
    successCode = code = 200
    if role = "sample" or role = "audio-sample" or role = "sample-tail" then successCode = code = 206
    if finished and successCode and not m.top.cancelRequested
        bytes = rpHdTaskFileSize(files.stat(filename))
        if bytes > 0 and bytes <= limit
            if role = "sample" or role = "audio-sample" or role = "sample-tail" or role = "sample-full"
                rangeOk = true
                if role = "sample" or role = "audio-sample" then rangeOk = rpHdTaskRangeResponse(responseHeaders,bytes)
                if role = "sample-tail" then rangeOk = rpHdTaskTailRangeResponse(responseHeaders,bytes)
                if rangeOk
                    binary = CreateObject("roByteArray")
                    if binary.readFile(filename)
                        answer.bytes = binary
                        answer.ok = binary.count() > 0 and binary.count() <= limit
                    end if
                end if
            else
                answer.body = ReadAsciiFile(filename)
                answer.ok = len(answer.body) > 0 and len(answer.body) <= limit
            end if
            if answer.ok then answer.message = ""
        end if
    end if
    bytesRead = rpHdTaskFileSize(files.stat(filename))
    print "[RokuPlus http] role="; role; " host="; rpHdTaskSafeHost(endpoint); " status="; code; " finished="; finished; " ms="; answer.httpElapsedMs
    print "[RokuPlus http] bytes="; bytesRead; " ok="; answer.ok; " type="; answer.httpContentType; " length="; answer.httpContentLength
    print "[RokuPlus http] bytes="; "cont"; " range="; answer.httpContentRange; " acceptRanges="; answer.httpAcceptRanges
    print "[RokuPlus http] cache="; answer.httpCacheControl; " age="; answer.httpAge; " server="; answer.httpServer; " via="; answer.httpVia
    files.delete(filename)
    if requestFile <> "" then files.delete(requestFile)
    return answer
end function

function rpHdTaskRangeResponse(headers as dynamic, bytes as integer) as boolean
    if type(headers) <> "roAssociativeArray" then return false
    value = ""
    for each name in headers
        if lcase(name) = "content-range" then value = orbitText(headers[name],120)
    end for
    range = CreateObject("roRegex","^bytes 0-([0-9]+)/([0-9]+|\*)$","i").match(value.trim())
    if range.count() < 3 then return false
    lastByte = orbitInteger(range[1],65535,-1)
    if lastByte < 0 or bytes <> lastByte+1 then return false
    return bytes > 0 and bytes <= 65536
end function

function rpHdTaskTailRangeResponse(headers as dynamic, bytes as integer) as boolean
    if type(headers) <> "roAssociativeArray" then return false
    value = ""
    for each name in headers
        if lcase(name) = "content-range" then value = orbitText(headers[name],120)
    end for
    range = CreateObject("roRegex","^bytes ([0-9]+)-([0-9]+)/([0-9]+)$","i").match(value.trim())
    if range.count() < 4 then return false
    firstByte = orbitInteger(range[1],2147483647,-1)
    lastByte = orbitInteger(range[2],2147483647,-1)
    totalBytes = orbitInteger(range[3],2147483647,-1)
    if firstByte < 0 or lastByte < firstByte or totalBytes <= lastByte then return false
    if bytes <> lastByte-firstByte+1 or bytes <> 65612 then return false
    if (firstByte mod 188) <> 0 or (totalBytes mod 188) <> 0 then return false
    return true
end function

function rpHdTaskFileSize(info as dynamic) as integer
    if type(info) <> "roAssociativeArray" then return -1
    if not info.doesExist("size") then return -1
    size = info.size
    numeric = GetInterface(size,"ifInt") <> invalid or GetInterface(size,"ifLongInt") <> invalid or GetInterface(size,"ifFloat") <> invalid or GetInterface(size,"ifDouble") <> invalid
    if not numeric then return -1
    if size < 0 then return -1
    if size > 4194304 then return 4194305
    return int(size)
end function
