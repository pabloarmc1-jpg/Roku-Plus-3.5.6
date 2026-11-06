' Original Roku Plus decoder profile. Output/display size is descriptive only;
' it never decides codec support. Query again when playback capabilities change.

function rpDeviceProfile(device = invalid as dynamic) as object
    if device = invalid then device = CreateObject("roDeviceInfo")
    samples = {}
    display = {}
    if GetInterface(device, "ifDeviceInfo") = invalid then return rpDeviceProfileFromSamples(samples, display)
    for each probe in rpDeviceProbePlan()
        ' Quoted lower-case keys also work on Roku OS versions before 14.1.
        format = {"codec": probe.codec, "profile": probe.profile, "level": probe.level}
        samples[probe.key] = device.canDecodeVideo(format)
    end for
    display.videoMode = device.getVideoMode()
    display.uiResolution = device.getUIResolution()
    display.displaySize = device.getDisplaySize()
    return rpDeviceProfileFromSamples(samples, display)
end function

function rpDeviceProbePlan() as object
    return [
        {key: "avc_main_41", codec: "mpeg4 avc", profile: "main", level: "4.1"},
        {key: "avc_high_41", codec: "mpeg4 avc", profile: "high", level: "4.1"},
        {key: "h264_main_41", codec: "h264", profile: "main", level: "4.1"},
        {key: "h264_high_41", codec: "h264", profile: "high", level: "4.1"},
        {key: "hevc_main_41", codec: "hevc", profile: "main", level: "4.1"},
        {key: "hevc_main_50", codec: "hevc", profile: "main", level: "5.0"},
        {key: "hevc_main_51", codec: "hevc", profile: "main", level: "5.1"},
        {key: "hevc_main10_41", codec: "hevc", profile: "main 10", level: "4.1"},
        {key: "hevc_main10_50", codec: "hevc", profile: "main 10", level: "5.0"},
        {key: "hevc_main10_51", codec: "hevc", profile: "main 10", level: "5.1"}
    ]
end function

function rpDeviceDecodeResult(answer as dynamic) as object
    decoded = {known: false, supported: false}
    if type(answer) <> "roAssociativeArray" then return decoded
    if not answer.doesExist("result") then return decoded
    if GetInterface(answer.result, "ifBoolean") = invalid then return decoded
    decoded.known = true
    decoded.supported = answer.result = true
    return decoded
end function

function rpDeviceProfileFromSamples(samples as dynamic, display = invalid as dynamic) as object
    result = {
        schema: 1, canDecodeH264: false, canDecodeHevc: false
        h264Known: false, hevcKnown: false, recommendedCatalog: "hd"
        hevcMain: {level41: false, level50: false, level51: false}
        hevcMain10: {level41: false, level50: false, level51: false}
        hevcMainKnown: {level41: false, level50: false, level51: false}
        hevcMain10Known: {level41: false, level50: false, level51: false}
        probes: {}, display: rpDeviceDisplaySummary(display)
    }
    if type(samples) <> "roAssociativeArray" then samples = {}
    avcKnownCount = 0
    hevcKnownCount = 0
    for each probe in rpDeviceProbePlan()
        answer = invalid
        if samples.doesExist(probe.key) then answer = samples[probe.key]
        decoded = rpDeviceDecodeResult(answer)
        result.probes[probe.key] = {
            codec: probe.codec, profile: probe.profile, level: probe.level
            known: decoded.known, supported: decoded.supported
        }
        if probe.codec = "hevc"
            if decoded.known then hevcKnownCount++
            if decoded.supported then result.canDecodeHevc = true
            levelKey = "level" + probe.level.replace(".", "")
            if probe.profile = "main"
                result.hevcMain[levelKey] = decoded.supported
                result.hevcMainKnown[levelKey] = decoded.known
            else
                result.hevcMain10[levelKey] = decoded.supported
                result.hevcMain10Known[levelKey] = decoded.known
            end if
        else
            if decoded.known then avcKnownCount++
            if decoded.supported then result.canDecodeH264 = true
        end if
    end for
    ' A positive exact query is known. A negative family conclusion requires
    ' every planned query to have supplied an actual boolean response.
    result.h264Known = result.canDecodeH264 or avcKnownCount = 4
    result.hevcKnown = result.canDecodeHevc or hevcKnownCount = 6
    if result.canDecodeHevc then result.recommendedCatalog = "hevc"
    return result
end function

function rpDeviceDisplaySummary(raw as dynamic) as object
    display = {videoMode: "", uiName: "", uiWidth: 0, uiHeight: 0, outputWidth: 0, outputHeight: 0}
    if type(raw) <> "roAssociativeArray" then return display
    if GetInterface(raw.videoMode, "ifString") <> invalid then display.videoMode = left(raw.videoMode, 32)
    if type(raw.displaySize) = "roAssociativeArray"
        size = raw.displaySize
        for each field in ["w", "h"]
            number = size[field]
            if GetInterface(number, "ifInt") <> invalid and number > 0 and number <= 16384
                if field = "w" then display.outputWidth = number else display.outputHeight = number
            end if
        end for
    end if
    if type(raw.uiResolution) = "roAssociativeArray"
        ui = raw.uiResolution
        if GetInterface(ui.name, "ifString") <> invalid then display.uiName = left(ui.name, 16)
        for each field in ["width", "height"]
            number = ui[field]
            if GetInterface(number, "ifInt") <> invalid
                if number >= 0 and number <= 16384
                    if field = "width" then display.uiWidth = number else display.uiHeight = number
                end if
            end if
        end for
    end if
    return display
end function
