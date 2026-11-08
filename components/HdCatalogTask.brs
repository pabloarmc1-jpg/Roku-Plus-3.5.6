' Public HD source requests. No JavaScript evaluation, proxy or PC helper.
' Every operation has one 40-second deadline; response files are bounded/deleted.
sub init()
    m.top.functionName = "runHdCatalogRequest"
end sub

sub runHdCatalogRequest()
    m.hdElapsed = CreateObject("roTimespan")
    m.hdElapsed.mark()
    request = {
        operation:m.top.operation, kind:m.top.kind, provider:m.top.provider
        query:m.top.query, skip:m.top.skip, item:m.top.item, season:m.top.season
        requestId:m.top.requestId, attempt:m.top.attempt
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
    if provider = "cinehax" then return rpHdCinehaxTask(request,answer,fetcher,decoderAccept)
    if provider = "seriesmetro" then return rpHdSeriesmetroTask(request,answer,fetcher,decoderAccept)
    if provider = "cinecalidad" then return rpHdCinecalidadTask(request,answer,fetcher,decoderAccept)
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
            if not loaded.ok then return rpHdTaskFailure(answer,loaded)
            item.seasons = loaded.seasons
            item.seasonNumbers = loaded.seasonNumbers
        end if
        answer.item = item
        answer.ok = true
        answer.message = ""
        return answer
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
        return answer
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
                    ' Diagnostic build 3.5.84: test the lower 1164x480 rendition on the 720p Roku.
                    ' The 1280x528 / 60fps rendition passed TS inspection but failed at Roku demux startup.
                    ' Keep the lower variant isolated so this test identifies rendition compatibility.
                    diagnosticHeight = 480
                    diagnosticCandidates = {variants:[],encrypted:candidates.encrypted}
                    for each diagnosticChoice in candidates.variants
                        if diagnosticChoice.height = diagnosticHeight then diagnosticCandidates.variants.push(diagnosticChoice)
                    end for
                    choices = rpHdTaskStableVariants(diagnosticCandidates,decoderAccept)
                    print "[RokuPlus hls-test] targetHeight="; diagnosticHeight; " eligibleVariants="; choices.count()
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
                        if child.ok then rpHdTaskLogManifest(child.body,selected.url)
                        playable = child.ok and rpHdTaskMediaManifest(child.body,selected.url)
                        segmentUrl = ""
                        candidateStage = "child_fetch_failed"
                        if child.ok
                            candidateStage = "manifest_rejected"
                            if playable
                                candidateStage = "segment_not_ts"
                                segmentUrl = rpHdTaskFirstSegment(child.body,selected.url)
                                print "[RokuPlus DEBUG] firstSegment="; segmentUrl
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

                                        ' Diagnostic 3.5.33: compare the final TS packets of segment 1 with the first packets of segment 2.
                                        ' This remains read-only and does not alter playback selection.
                                        boundarySegments = rpHdTaskSegmentList(child.body,selected.url)
                                        if boundarySegments.count() > 1
                                            secondSample = fetcher(boundarySegments[1],"sample",mediaReferer)
                                            tailSample = fetcher(segmentUrl,"sample-tail",mediaReferer)
                                            if secondSample.cancelled then return rpHdTaskFailure(answer,secondSample)
                                            if tailSample.cancelled then return rpHdTaskFailure(answer,tailSample)
                                            if secondSample.ok and tailSample.ok
                                                firstProfile = rpHdOnlineTsStartupProfile(sample.bytes)
                                                secondProfile = rpHdOnlineTsStartupProfile(secondSample.bytes)
                                                print "[RokuPlus ts-boundary] first valid="; firstProfile.valid; " videoPid="; firstProfile.videoPid; " audioPid="
                                                print "[RokuPlus ts-boundary] first valid="; "cont"; firstProfile.audioPid
                                                print "[RokuPlus ts-boundary] second valid="; secondProfile.valid; " videoPid="; secondProfile.videoPid; " audioPid="
                                                print "[RokuPlus ts-boundary] second valid="; "cont"; secondProfile.audioPid
                                                print "[RokuPlus ts-idr] first firstVclType="; firstProfile.firstVclType
                                                print "[RokuPlus ts-idr] first idr="; firstProfile.idrPresent; " idrByte="; firstProfile.idrByte
                                                print "[RokuPlus ts-idr] first sps="; firstProfile.spsPresent; " pps="; firstProfile.ppsPresent; " spsProfile="
                                                print "[RokuPlus ts-idr] first sps="; "cont"; firstProfile.spsProfileIdc; " spsConstraints="; firstProfile.spsConstraints; " spsLevel="
                                                print "[RokuPlus ts-idr] first sps="; "cont"; firstProfile.spsLevelIdc
                                                print "[RokuPlus ts-sps] first valid="; firstProfile.spsWidth > 0; " width="; firstProfile.spsWidth; " height="; firstProfile.spsHeight; " chroma="; firstProfile.spsChroma
                                                print "[RokuPlus ts-sps] first bitDepthLuma="; firstProfile.spsBitDepthLuma; " bitDepthChroma="; firstProfile.spsBitDepthChroma; " maxRefs="; firstProfile.spsMaxRefs
                                                print "[RokuPlus ts-sps] first frameMbsOnly="; firstProfile.spsFrameMbsOnly; " fps="; firstProfile.spsFrameRate; " fixed="; firstProfile.spsFixedFrameRate; " vui="; firstProfile.spsVui
                                                print "[RokuPlus ts-sps-vui] timing="; firstProfile.spsTimingPresent; " numUnitsInTick="; firstProfile.spsNumUnitsInTick; " timeScale="; firstProfile.spsTimeScale
                                                print "[RokuPlus ts-sps-vui] nalHrd="; firstProfile.spsNalHrd; " vclHrd="; firstProfile.spsVclHrd; " lowDelay="; firstProfile.spsLowDelayHrd; " picStruct="; firstProfile.spsPicStruct
                                                print "[RokuPlus ts-sps-vui] restriction="; firstProfile.spsBitstreamRestriction; " maxReorder="; firstProfile.spsMaxReorder; " maxBuffer="; firstProfile.spsMaxBuffer
                                                print "[RokuPlus ts-pps] present="; firstProfile.ppsPresent; " valid="; firstProfile.ppsValid; " ppsId="; firstProfile.ppsId; " spsId="; firstProfile.ppsSpsId
                                                print "[RokuPlus ts-pps] entropy="; firstProfile.ppsEntropy; " bottomFieldPicOrder="; firstProfile.ppsBottomFieldPicOrder; " sliceGroups="; firstProfile.ppsSliceGroups
                                                print "[RokuPlus ts-pps] refL0="; firstProfile.ppsRefL0; " refL1="; firstProfile.ppsRefL1; " weightedPred="; firstProfile.ppsWeightedPred; " weightedBipred="; firstProfile.ppsWeightedBipred
                                                print "[RokuPlus ts-pps] deblocking="; firstProfile.ppsDeblocking; " constrainedIntra="; firstProfile.ppsConstrainedIntra; " redundantPicCount="; firstProfile.ppsRedundant
                                                print "[RokuPlus ts-idr] second firstVclType="; secondProfile.firstVclType
                                                print "[RokuPlus ts-idr] second idr="; secondProfile.idrPresent; " idrByte="; secondProfile.idrByte
                                                print "[RokuPlus ts-idr] second sps="; secondProfile.spsPresent; " pps="; secondProfile.ppsPresent
                                                if firstProfile.videoPid > 0 and firstProfile.audioPid > 0
                                                    firstTiming = rpHdOnlineTsTimingProfile(sample.bytes,firstProfile.videoPid,firstProfile.audioPid)
                                                    secondHeadTiming = rpHdOnlineTsTimingProfile(secondSample.bytes,firstProfile.videoPid,firstProfile.audioPid)
                                                    tailTiming = rpHdOnlineTsTimingProfile(tailSample.bytes,firstProfile.videoPid,firstProfile.audioPid)
                                                    headTiming = rpHdOnlineTsTimingProfile(secondSample.bytes,firstProfile.videoPid,firstProfile.audioPid)
                                                    print "[RokuPlus ts-audio] first bytes="; sample.bytes.count(); " videoPackets="; firstTiming.videoPackets; " audioPackets="
                                                    print "[RokuPlus ts-audio] first bytes="; "cont"; firstTiming.audioPackets; " videoPes="; firstTiming.videoPesStarts; " audioPes="
                                                    print "[RokuPlus ts-audio] first bytes="; "cont"; firstTiming.audioPesStarts; " videoPts="; firstTiming.videoPtsCount; " audioPts="
                                                    print "[RokuPlus ts-audio] first bytes="; "cont"; firstTiming.audioPtsCount
                                                    print "[RokuPlus ts-clock] first videoPts="; firstTiming.firstVideoPts; " last="; firstTiming.lastVideoPts; " videoDts="; firstTiming.firstVideoDts; " last="; firstTiming.lastVideoDts
                                                    print "[RokuPlus ts-clock] first audioPts="; firstTiming.firstAudioPts; " last="; firstTiming.lastAudioPts; " audioDts="; firstTiming.firstAudioDts; " last="; firstTiming.lastAudioDts
                                                    print "[RokuPlus ts-clock] first PCR="; firstTiming.firstPcr; " last="; firstTiming.lastPcr; " count="; firstTiming.pcrCount
                                                    print "[RokuPlus ts-audio] second bytes="; secondSample.bytes.count(); " videoPackets="; secondHeadTiming.videoPackets
                                                    print "[RokuPlus ts-audio] second bytes="; "cont"; " audioPackets="; secondHeadTiming.audioPackets; " videoPes="
                                                    print "[RokuPlus ts-audio] second bytes="; "cont"; secondHeadTiming.videoPesStarts; " audioPes="; secondHeadTiming.audioPesStarts
                                                    print "[RokuPlus ts-audio] second bytes="; "cont"; " videoPts="; secondHeadTiming.videoPtsCount; " audioPts="; secondHeadTiming.audioPtsCount
                                                    print "[RokuPlus ts-audio] tail bytes="; tailSample.bytes.count(); " videoPackets="; tailTiming.videoPackets; " audioPackets="
                                                    print "[RokuPlus ts-audio] tail bytes="; "cont"; tailTiming.audioPackets; " videoPes="; tailTiming.videoPesStarts; " audioPes="
                                                    print "[RokuPlus ts-audio] tail bytes="; "cont"; tailTiming.audioPesStarts; " videoPts="; tailTiming.videoPtsCount; " audioPts="
                                                    print "[RokuPlus ts-audio] tail bytes="; "cont"; tailTiming.audioPtsCount
                                                    firstAdts = rpHdOnlineTsAdtsSequenceProfile(sample.bytes,firstProfile.audioPid)
                                                    secondAdts = rpHdOnlineTsAdtsSequenceProfile(secondSample.bytes,firstProfile.audioPid)
                                                    tailAdts = rpHdOnlineTsAdtsSequenceProfile(tailSample.bytes,firstProfile.audioPid)
                                                    print "[RokuPlus ts-adts-seq] first valid="; firstAdts.valid; " tsPackets="; firstAdts.tsPackets; " pes="; firstAdts.pesStarts
                                                    print "[RokuPlus ts-adts-seq] first pesBytes="; firstAdts.pesPayloadBytes; " firstPes="; firstAdts.firstPesBytes; " maxPes="
                                                    print "[RokuPlus ts-adts-seq] first pesBytes="; "cont"; firstAdts.maxPesBytes; " ccErrors="; firstAdts.continuityErrors
                                                    print "[RokuPlus ts-adts-seq] first candidates="; firstAdts.adtsCandidates; " runs="; firstAdts.confirmedRuns; " frames="
                                                    print "[RokuPlus ts-adts-seq] first candidates="; "cont"; firstAdts.confirmedFrames; " truncated="; firstAdts.truncatedFrames
                                                    print "[RokuPlus ts-adts-seq] first profile="; firstAdts.profile; " rate="; firstAdts.rateIndex; " channels="; firstAdts.channels
                                                    print "[RokuPlus ts-adts-seq] first profile="; "cont"; " unframed="; firstAdts.unframedBytes
                                                    print "[RokuPlus ts-adts-seq] second valid="; secondAdts.valid; " tsPackets="; secondAdts.tsPackets; " pes="; secondAdts.pesStarts
                                                    print "[RokuPlus ts-adts-seq] second pesBytes="; secondAdts.pesPayloadBytes; " firstPes="; secondAdts.firstPesBytes; " maxPes="
                                                    print "[RokuPlus ts-adts-seq] second pesBytes="; "cont"; secondAdts.maxPesBytes; " ccErrors="; secondAdts.continuityErrors
                                                    print "[RokuPlus ts-adts-seq] second candidates="; secondAdts.adtsCandidates; " runs="; secondAdts.confirmedRuns; " frames="
                                                    print "[RokuPlus ts-adts-seq] second candidates="; "cont"; secondAdts.confirmedFrames; " truncated="; secondAdts.truncatedFrames
                                                    print "[RokuPlus ts-adts-seq] second profile="; secondAdts.profile; " rate="; secondAdts.rateIndex; " channels="; secondAdts.channels
                                                    print "[RokuPlus ts-adts-seq] second profile="; "cont"; " unframed="; secondAdts.unframedBytes
                                                    print "[RokuPlus ts-adts-seq] tail valid="; tailAdts.valid; " tsPackets="; tailAdts.tsPackets; " pes="; tailAdts.pesStarts
                                                    print "[RokuPlus ts-adts-seq] tail pesBytes="; tailAdts.pesPayloadBytes; " firstPes="; tailAdts.firstPesBytes; " maxPes="
                                                    print "[RokuPlus ts-adts-seq] tail pesBytes="; "cont"; tailAdts.maxPesBytes; " ccErrors="; tailAdts.continuityErrors
                                                    print "[RokuPlus ts-adts-seq] tail candidates="; tailAdts.adtsCandidates; " runs="; tailAdts.confirmedRuns; " frames="
                                                    print "[RokuPlus ts-adts-seq] tail candidates="; "cont"; tailAdts.confirmedFrames; " truncated="; tailAdts.truncatedFrames
                                                    print "[RokuPlus ts-adts-seq] tail profile="; tailAdts.profile; " rate="; tailAdts.rateIndex; " channels="; tailAdts.channels
                                                    print "[RokuPlus ts-adts-seq] tail profile="; "cont"; " unframed="; tailAdts.unframedBytes
                                                    ' Diagnostic 3.5.64: inspect the entire first TS segment, not only its 64KB prefix.
                                                    ' Read-only; native HLS playback continues to use the original provider playlist.
                                                    rpHdTaskBeginSlice(1)
                                                    fullFirst = fetcher(segmentUrl,"sample-full",mediaReferer)
                                                    if fullFirst.cancelled then return rpHdTaskFailure(answer,fullFirst)
                                                    if fullFirst.ok
                                                        fullAdts = rpHdOnlineTsAdtsSequenceProfile(fullFirst.bytes,firstProfile.audioPid)
                                                        fullTiming = rpHdOnlineTsTimingProfile(fullFirst.bytes,firstProfile.videoPid,firstProfile.audioPid)
                                                        print "[RokuPlus ts-timing-full] bytes="; fullFirst.bytes.count(); " videoPackets="; fullTiming.videoPackets; " audioPackets="
                                                        print "[RokuPlus ts-timing-full] bytes="; "cont"; fullTiming.audioPackets; " videoPes="; fullTiming.videoPesStarts; " audioPes="
                                                        print "[RokuPlus ts-timing-full] bytes="; "cont"; fullTiming.audioPesStarts
                                                        print "[RokuPlus ts-timing-full] videoPts="; fullTiming.videoPtsCount; " audioPts="; fullTiming.audioPtsCount; " videoDts="
                                                        print "[RokuPlus ts-timing-full] videoPts="; "cont"; fullTiming.videoDtsCount; " audioDts="; fullTiming.audioDtsCount; " pcr="
                                                        print "[RokuPlus ts-timing-full] videoPts="; "cont"; fullTiming.pcrCount; " discontinuities="; fullTiming.discontinuityFlags
                                                        print "[RokuPlus ts-timing-full] firstVideoPts="; fullTiming.firstVideoPts; " lastVideoPts="; fullTiming.lastVideoPts
                                                        print "[RokuPlus ts-timing-full] firstVideoPts="; "cont"; " firstAudioPts="; fullTiming.firstAudioPts; " lastAudioPts="
                                                        print "[RokuPlus ts-timing-full] firstVideoPts="; "cont"; fullTiming.lastAudioPts
                                                        print "[RokuPlus ts-timing-full] firstPcr="; fullTiming.firstPcr; " lastPcr="; fullTiming.lastPcr; " invalidPackets="
                                                        print "[RokuPlus ts-timing-full] firstPcr="; "cont"; fullTiming.invalidPackets; " transportErrors="; fullTiming.transportErrors
                                                        print "[RokuPlus ts-timing-full] firstPcr="; "cont"; " scrambled="; fullTiming.scrambledPackets; " videoCcErrors="
                                                        print "[RokuPlus ts-timing-full] firstPcr="; "cont"; fullTiming.videoContinuityErrors; " audioCcErrors="; fullTiming.audioContinuityErrors
                                                        print "[RokuPlus ts-adts-full] first bytes="; fullFirst.bytes.count(); " valid="; fullAdts.valid
                                                        print "[RokuPlus ts-adts-full] first tsPackets="; fullAdts.tsPackets; " pes="; fullAdts.pesStarts; " pesBytes="
                                                        print "[RokuPlus ts-adts-full] first tsPackets="; "cont"; fullAdts.pesPayloadBytes
                                                        print "[RokuPlus ts-adts-full] first candidates="; fullAdts.adtsCandidates; " runs="; fullAdts.confirmedRuns; " frames="
                                                        print "[RokuPlus ts-adts-full] first candidates="; "cont"; fullAdts.confirmedFrames; " truncated="; fullAdts.truncatedFrames
                                                        print "[RokuPlus ts-adts-full] first ccErrors="; fullAdts.continuityErrors; " firstPes="; fullAdts.firstPesBytes; " maxPes="
                                                        print "[RokuPlus ts-adts-full] first ccErrors="; "cont"; fullAdts.maxPesBytes
                                                        print "[RokuPlus ts-adts-full] first profile="; fullAdts.profile; " rate="; fullAdts.rateIndex; " channels="; fullAdts.channels
                                                        print "[RokuPlus ts-adts-full] first profile="; "cont"; " unframed="; fullAdts.unframedBytes
                                                    else
                                                        print "[RokuPlus ts-adts-full] first fetch=failed"
                                                    end if
                                                    print "[RokuPlus ts-boundary] tail PTS video first="; tailTiming.firstVideoPts; " last="; tailTiming.lastVideoPts; " audio first="
                                                    print "[RokuPlus ts-boundary] tail PTS video first="; "cont"; tailTiming.firstAudioPts; " last="; tailTiming.lastAudioPts
                                                    print "[RokuPlus ts-boundary] head PTS video first="; headTiming.firstVideoPts; " last="; headTiming.lastVideoPts; " audio first="
                                                    print "[RokuPlus ts-boundary] head PTS video first="; "cont"; headTiming.firstAudioPts; " last="; headTiming.lastAudioPts
                                                    print "[RokuPlus ts-boundary] tail PCR first="; tailTiming.firstPcr; " last="; tailTiming.lastPcr; " count="; tailTiming.pcrCount
                                                    print "[RokuPlus ts-boundary] head PCR first="; headTiming.firstPcr; " last="; headTiming.lastPcr; " count="; headTiming.pcrCount
                                                    print "[RokuPlus ts-boundary] tail packet-errors video="; tailTiming.videoContinuityErrors; " audio="
                                                    print "[RokuPlus ts-boundary] tail packet-errors video="; "cont"; tailTiming.audioContinuityErrors; " head packet-errors video="
                                                    print "[RokuPlus ts-boundary] tail packet-errors video="; "cont"; headTiming.videoContinuityErrors; " audio="
                                                    print "[RokuPlus ts-boundary] tail packet-errors video="; "cont"; headTiming.audioContinuityErrors
                                                end if
                                            else
                                                print "[RokuPlus ts-boundary] boundary_samples tailOk="; tailSample.ok; " headOk="; secondSample.ok; " tailMessage="
                                                print "[RokuPlus ts-boundary] boundary_samples tailOk="; "cont"; tailSample.message
                                            end if
                                        else
                                            print "[RokuPlus ts-boundary] second_segment=missing"
                                        end if
                                    end if
                                end if
                            end if
                        end if
                        print "[RokuPlus candidate] result="; candidateStage
                        if playable
                            relaySegments = rpHdTaskSegmentList(child.body,selected.url)
                            relayDurations = rpHdTaskSegmentDurations(child.body)
                            if relaySegments.count() > 1 and relayDurations.count() = relaySegments.count()
                                answer.segmentUrls = relaySegments
                                answer.segmentDurations = relayDurations
                                answer.tsRelayEnabled = true
                                print "[RokuPlus ts-relay] candidate_segments="; relaySegments.count(); " durations="; relayDurations.count()
                            else
                                answer.tsRelayEnabled = false
                                print "[RokuPlus ts-relay] disabled reason=segment_metadata_invalid segments="; relaySegments.count(); " durations="; relayDurations.count()
                            end if
                            ' Diagnostic 3.5.38: return the selected child HLS manifest as one native stream.
                            ' The TS playlist path was confirmed to create visible clip boundaries.
                            ' Isolate Roku HLS audio selection while preserving the validated variant.
                            playbackPlaylistKind = "native-child-hls-audio-isolation"
                            playbackStreamFormat = "hls"
                            if item.id = "hdo-lamovie-4453"
                                answer.url = "http://192.168.100.7:8000/4453-test.m3u8"
                            else if item.id = "hdo-lamovie-4519"
                                answer.url = "http://192.168.100.7:8000/4519-test.m3u8"
                            else
                                answer.url = selected.url
                            end if
                            answer.streamFormat = playbackStreamFormat
                            answer.mediaHeaders = {Referer:mediaReferer, "User-Agent":rpHdTaskUserAgent()}
                            answer.description = "Español · H.264 · "+selected.height.toStr()+"p"
                            answer.language = embed.language
                            answer.width = selected.width
                            answer.height = selected.height
                            answer.codecs = selected.codecs
                            answer.seekSupport = "native-hls"
                            audioMode = "embedded"
                            if selected.audioGroup <> "" then audioMode = "master-audio-group"
                            matchingAudioTracks = 0
                            for each audioTrack in master.audioTracks
                                if audioTrack.group = selected.audioGroup then matchingAudioTracks = matchingAudioTracks + 1
                            end for
                            print "[RokuPlus hls] selected group="; selected.audioGroup; " matchingAudioTracks="; matchingAudioTracks; " masterAudioTracks="
                            print "[RokuPlus hls] selected group="; "cont"; master.audioTracks.count()
                            print "[RokuPlus resolve] provider="; provider; " format="; playbackStreamFormat; " playlist="; playbackPlaylistKind; " embedHost="
                            print "[RokuPlus resolve] provider="; "cont"; rpHdTaskSafeHost(embed.url); " masterHost="; rpHdTaskSafeHost(masterUrl); " testedVideoHost="
                            print "[RokuPlus resolve] provider="; "cont"; rpHdTaskSafeHost(selected.url); " height="; selected.height; " audioMode="; audioMode
                            print "[RokuPlus resolve] provider="; "cont"; " validation=avc-aac-ts"
                            print "[RokuPlus ts-test] diagnostic="; playbackPlaylistKind; " format="; playbackStreamFormat; " targetHost="; rpHdTaskSafeHost(answer.url)
                            answer.attemptUsed = embedIndex+variantIndex*count
                            answer.ok = true
                            answer.message = ""
                            m.hdProviderDeadline = 0
                            return answer
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

' skip encodes source-page rounds in steps of twenty, not displayed-card count.
' JSON providers request twenty records; SSR pages may contain more cards.
' Round-robin output preserves duplicate titles belonging to different sources.
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
            response = rpHdTaskCatalogPage(source,answer.kind,page,query,fetcher)
            m.hdProviderDeadline = 0
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
    seen = {}
    if rows > 200 then rows = 200
    for row = 0 to rows-1
        for each entries in pages
            if row < entries.count()
                item = entries[row]
                if not seen.doesExist(item.id)
                    answer.items.push(item)
                    seen[item.id] = true
                end if
            end if
        end for
    end for
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
        budget = (40000-now) \ remaining
        if budget < 0 then budget = 0
        m.hdProviderDeadline = now+budget
    end if
end sub

function rpHdTaskSliceExpired() as boolean
    if m.hdElapsed = invalid then return false
    now = m.hdElapsed.totalMilliseconds()
    if now >= 40000 then return true
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
' Only accept a variant when that linked group declares Spanish as its default.
function rpHdTaskSpanishAudio(master as object, variant as object) as boolean
    if variant.audioGroup = "" then return true
    for each track in master.audioTracks
        if track.group = variant.audioGroup
            if track.default
                language = lcase(track.language)
                name = lcase(track.name)
                if language <> "" then return language = "es" or language = "spa" or left(language,3) = "es-"
                return instr(1,name,"español") > 0 or instr(1,name,"spanish") > 0 or instr(1,name,"latino") > 0 or instr(1,name,"castellano") > 0
            end if
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

function rpHdTaskSegmentDurations(body as string) as object
    durations = []
    pendingDuration = invalid
    for each raw in body.split(chr(10))
        line = raw.trim()
        if left(line,8) = "#EXTINF:"
            value = mid(line,9).split(",")[0].trim()
            parsed = value.toFloat()
            if parsed <= 0 or pendingDuration <> invalid then return []
            pendingDuration = parsed
        else if line <> "" and left(line,1) <> "#"
            if pendingDuration = invalid then return []
            durations.push(pendingDuration)
            pendingDuration = invalid
            if durations.count() > 2000 then return []
        end if
    end for
    if pendingDuration <> invalid then return []
    return durations
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
    if role = "media" or role = "sample" or role = "sample-tail" or role = "sample-full" then return rpHdOnlineCdn(endpoint) <> ""
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
    if role = "api"
        transfer.addHeader("Accept","application/json")
        if referer = "" and instr(1,endpoint,"https://cinehax.org/api/rest/v1/") = 1 then referer = "https://cinehax.org/"
    end if
    if referer <> "" then transfer.addHeader("Referer",referer)
    limit = 2097152
    if role = "sample"
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
    if role = "sample" or role = "sample-tail" then successCode = code = 206
    if finished and successCode and not m.top.cancelRequested
        bytes = rpHdTaskFileSize(files.stat(filename))
        if bytes > 0 and bytes <= limit
            if role = "sample" or role = "sample-tail" or role = "sample-full"
                rangeOk = true
                if role = "sample" then rangeOk = rpHdTaskRangeResponse(responseHeaders,bytes)
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
