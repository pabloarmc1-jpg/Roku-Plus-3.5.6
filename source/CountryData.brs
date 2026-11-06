' Fixed public playlist destinations for the country/region picker. Input is
' matched to this table; it is never inserted into a URL or arbitrary path.
function orbitCountries() as object
    definitions = [
        {code: "mx", name: "México"}
        {code: "ar", name: "Argentina"}
        {code: "bo", name: "Bolivia"}
        {code: "br", name: "Brasil"}
        {code: "cl", name: "Chile"}
        {code: "co", name: "Colombia"}
        {code: "cr", name: "Costa Rica"}
        {code: "cu", name: "Cuba"}
        {code: "ec", name: "Ecuador"}
        {code: "sv", name: "El Salvador"}
        {code: "gt", name: "Guatemala"}
        {code: "ht", name: "Haití"}
        {code: "hn", name: "Honduras"}
        {code: "ni", name: "Nicaragua"}
        {code: "pa", name: "Panamá"}
        {code: "py", name: "Paraguay"}
        {code: "pe", name: "Perú"}
        {code: "pr", name: "Puerto Rico"}
        {code: "do", name: "República Dominicana"}
        {code: "uy", name: "Uruguay"}
        {code: "ve", name: "Venezuela"}
    ]
    choices = []
    for each row in definitions
        choices.push({code: row.code, iso2: row.code, name: row.name, playlist: "https://iptv-org.github.io/iptv/countries/" + row.code + ".m3u"})
    end for
    return choices
end function

function orbitCountryLookup(value as dynamic) as dynamic
    if GetInterface(value, "ifString") = invalid then return invalid
    if len(value) <> 2 then return invalid
    code = lcase(value)
    for each choice in orbitCountries()
        if choice.code = code then return choice
    end for
    return invalid
end function

function orbitCountryCode(value as dynamic) as string
    choice = orbitCountryLookup(value)
    if choice = invalid then return ""
    return choice.code
end function

function orbitDefaultCountry() as object
    return orbitCountryLookup("mx")
end function

function orbitCountryPlaylist(value as dynamic) as string
    choice = orbitCountryLookup(value)
    if choice = invalid then return ""
    return choice.playlist
end function

function orbitCountryEndpoint(operation as dynamic, value as dynamic) as string
    if GetInterface(operation, "ifString") = invalid then return ""
    if operation = "mexico" then return orbitCountryPlaylist("mx")
    if operation = "country" then return orbitCountryPlaylist(value)
    return ""
end function
