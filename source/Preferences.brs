' Original Roku Plus preferences: catalog profile, HD source and appearance.
' Never persist decoder identifiers, accounts, URLs or PC/playback state.

function rpNormalizePreferences(raw as dynamic, recommended = "hd" as dynamic) as object
    mode = "hd"
    if GetInterface(recommended, "ifString") <> invalid
        if recommended = "hevc" then mode = "hevc"
    end if
    result = {configured: false, mode: mode, countryCode: "mx"}
    if type(raw) <> "roAssociativeArray" then return result
    if GetInterface(raw.version, "ifInt") = invalid then return result
    if raw.version <> 1 then return result
    if GetInterface(raw.mode, "ifString") = invalid then return result
    if raw.mode <> "hd" and raw.mode <> "hevc" then return result
    country = orbitCountryCode(raw.countryCode)
    if country = "" then return result
    result.configured = true
    result.mode = raw.mode
    result.countryCode = country
    return result
end function

function rpNormalizeTheme(value as dynamic) as string
    if GetInterface(value,"ifString") <> invalid
        if value = "classic" then return "classic"
    end if
    return "glass"
end function

function rpLoadTheme() as string
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return "glass"
    return rpNormalizeTheme(section.read("themeV1"))
end function

function rpSaveTheme(value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    if value <> "glass" and value <> "classic" then return false
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    return rpStoreTheme(section,value)
end function

function rpStoreTheme(section as object, value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    if value <> "glass" and value <> "classic" then return false
    previous = section.read("themeV1")
    if section.write("themeV1",value) <> true then return false
    if section.flush() = true then return true
    if previous = "" then section.delete("themeV1") else section.write("themeV1",previous)
    section.flush()
    return false
end function

' Separate backward-compatible preference. Never stores a provider URL or token.
function rpNormalizeHdProvider(value as dynamic) as string
    if GetInterface(value,"ifString") <> invalid
        if value = "all" or value = "lamovie" or value = "allcalidad" or value = "cinehax" or value = "seriesmetro" or value = "cinecalidad" or value = "open" then return value
    end if
    return "all"
end function

function rpLoadHdProvider() as string
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return "all"
    return rpNormalizeHdProvider(section.read("hdSourceV1"))
end function

function rpSaveHdProvider(value as dynamic) as boolean
    provider = rpNormalizeHdProvider(value)
    if provider <> value then return false
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    return rpStoreHdProvider(section,provider)
end function

function rpStoreHdProvider(section as object, provider as dynamic) as boolean
    if rpNormalizeHdProvider(provider) <> provider then return false
    previous = section.read("hdSourceV1")
    if section.write("hdSourceV1",provider) <> true then return false
    if section.flush() = true then return true
    if previous = "" then section.delete("hdSourceV1") else section.write("hdSourceV1",previous)
    section.flush()
    return false
end function

function rpPreferencesFromText(text as dynamic, recommended = "hd" as dynamic) as object
    fallback = rpNormalizePreferences(invalid, recommended)
    if GetInterface(text, "ifString") = invalid then return fallback
    if len(text) = 0 or len(text) > 512 then return fallback
    text = text.trim()
    if left(text, 1) <> "{" or right(text, 1) <> "}" then return fallback
    return rpNormalizePreferences(ParseJson(text), recommended)
end function

function rpLoadPreferences(recommended = "hd" as dynamic) as object
    section = CreateObject("roRegistrySection", "RokuPlusPreferences")
    if GetInterface(section, "ifRegistrySection") = invalid then return rpNormalizePreferences(invalid, recommended)
    return rpPreferencesFromText(section.read("profileV1"), recommended)
end function

function rpSavePreferences(mode as dynamic, countryCode as dynamic) as boolean
    settings = rpNormalizePreferences({version: 1, mode: mode, countryCode: countryCode})
    if not settings.configured then return false
    section = CreateObject("roRegistrySection", "RokuPlusPreferences")
    if GetInterface(section, "ifRegistrySection") = invalid then return false
    return rpStorePreferences(section, settings.mode, settings.countryCode)
end function

' This small I/O boundary is separately testable with a registry-method stub.
function rpStorePreferences(section as object, mode as dynamic, countryCode as dynamic) as boolean
    settings = rpNormalizePreferences({version: 1, mode: mode, countryCode: countryCode})
    if not settings.configured then return false
    previous = rpPreferencesFromText(section.read("profileV1"))
    payload = FormatJson({version: 1, mode: settings.mode, countryCode: settings.countryCode})
    if GetInterface(payload, "ifString") = invalid then return false
    if section.write("profileV1", payload) <> true then return false
    if section.flush() = true then return true
    ' A failed commit must never be reported as configured. Restore the prior
    ' buffered choice, or remove an uncommitted first-run choice, then fail.
    if previous.configured
        restored = FormatJson({version: 1, mode: previous.mode, countryCode: previous.countryCode})
        section.write("profileV1", restored)
    else
        section.delete("profileV1")
    end if
    section.flush()
    return false
end function


' Active household profile. Four isolated local watch-state namespaces.
function rpNormalizeProfileId(value as dynamic) as string
    if GetInterface(value,"ifString") <> invalid
        if value = "p2" or value = "p3" or value = "p4" then return value
    end if
    return "p1"
end function

function rpLoadProfileId() as string
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return "p1"
    return rpNormalizeProfileId(section.read("activeProfileV1"))
end function

function rpSaveProfileId(value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    if value <> "p1" and value <> "p2" and value <> "p3" and value <> "p4" then return false
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    previous = section.read("activeProfileV1")
    if section.write("activeProfileV1",value) <> true then return false
    if section.flush() = true then return true
    if previous = "" then section.delete("activeProfileV1") else section.write("activeProfileV1",previous)
    section.flush()
    return false
end function

function rpProfileName(profileId as string) as string
    safe = rpNormalizeProfileId(profileId)
    section = CreateObject("roRegistrySection","RokuPlusProfileMeta")
    if GetInterface(section,"ifRegistrySection") <> invalid
        saved = section.read("name_"+safe)
        if GetInterface(saved,"ifString") <> invalid and saved.trim() <> "" then return left(saved.trim(),24)
    end if
    if safe = "p2" then return "Perfil 2"
    if safe = "p3" then return "Perfil 3"
    if safe = "p4" then return "Perfil 4"
    return "Perfil principal"
end function

function rpProfileAvatar(profileId as string) as integer
    safe = rpNormalizeProfileId(profileId)
    section = CreateObject("roRegistrySection","RokuPlusProfileMeta")
    if GetInterface(section,"ifRegistrySection") = invalid then return 0
    value = section.read("avatar_"+safe)
    if GetInterface(value,"ifString") <> invalid
        parsed = Val(value)
        if parsed >= 0 and parsed <= 5 then return parsed
    else if GetInterface(value,"ifInt") <> invalid
        if value >= 0 and value <= 5 then return value
    end if
    return 0
end function

function rpSaveProfileName(profileId as string, value as string) as boolean
    safe = rpNormalizeProfileId(profileId)
    clean = left(value.trim(),24)
    if clean = "" then return false
    section = CreateObject("roRegistrySection","RokuPlusProfileMeta")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    if section.write("name_"+safe,clean) <> true then return false
    return section.flush() = true
end function

function rpSaveProfileAvatar(profileId as string, value as integer) as boolean
    safe = rpNormalizeProfileId(profileId)
    if value < 0 or value > 5 then return false
    section = CreateObject("roRegistrySection","RokuPlusProfileMeta")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    if section.write("avatar_"+safe,value.toStr()) <> true then return false
    return section.flush() = true
end function


' LAN compatibility helper. Only an HTTP origin is stored; no paths or credentials.
function rpNormalizeCompatBase(value as dynamic) as string
    if GetInterface(value,"ifString") = invalid then return "http://192.168.1.17:8099"
    candidate = value.trim()
    if candidate = "" then return ""
    if len(candidate) > 120 then return "http://192.168.1.17:8099"
    match = CreateObject("roRegex", "^http://[A-Za-z0-9.-]+:[0-9]{1,5}$", "").isMatch(candidate)
    if not match then return "http://192.168.1.17:8099"
    colon = instr(8, candidate, ":")
    if colon < 0 then return "http://192.168.1.17:8099"
    portText = mid(candidate, colon + 1)
    port = val(portText)
    if port < 1 or port > 65535 then return "http://192.168.1.17:8099"
    return candidate
end function

function rpLoadCompatBase() as string
    section = CreateObject("roRegistrySection", "RokuPlusPreferences")
    if GetInterface(section, "ifRegistrySection") = invalid then return "http://192.168.1.17:8099"
    raw = section.read("compatBaseV1")
    if raw = "" then return "http://192.168.1.17:8099"
    return rpNormalizeCompatBase(raw)
end function

function rpSaveCompatBase(value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    if value.trim() = "" then return false
    candidate = rpNormalizeCompatBase(value)
    if candidate <> value.trim() then return false
    section = CreateObject("roRegistrySection", "RokuPlusPreferences")
    if GetInterface(section, "ifRegistrySection") = invalid then return false
    previous = section.read("compatBaseV1")
    if section.write("compatBaseV1", candidate) <> true then return false
    if section.flush() = true then return true
    if previous = "" then section.delete("compatBaseV1") else section.write("compatBaseV1", previous)
    section.flush()
    return false
end function
