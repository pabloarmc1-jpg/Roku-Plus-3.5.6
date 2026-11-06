' Public program references curated on 2026-11-03. No accounts or copied sessions.
function rpRealityItems() as object
    return [
        {
            id:"live:la-granja-vip-mx", title:"La Granja VIP · 24/7", kind:"live"
            provider:"tvazteca", countryCode:"mx", available:true
            subtitle:"TV Azteca · México", availabilityLabel:"Señal gratuita"
            sourcePage:"https://www.tvazteca.com/aztecauno/la-granja-vip-24-7/en-vivo/"
            url:"https://mdstrm.com/live-stream-playlist/69f3bde44a6aa2a6ccaf1b38.m3u8"
            mediaHeaders:{"User-Agent":"Mozilla/5.0"}
            streamFormat:"hls", live:true, seekSupport:"unknown", poster:"pkg:/images/ui/live-program-granja.png", background:""
            description:"Señal pública de TV Azteca. La disponibilidad puede cambiar según el país y la programación."
            year:"", runtime:0, language:"es", seasons:[]
        }
        {
            id:"reality:la-casa-de-los-famosos-mx", title:"La Casa de los Famosos México", kind:"program"
            provider:"vix", countryCode:"mx", available:false
            subtitle:"México · Temporada 2026", availabilityLabel:"Temporada finalizada"
            availabilityMessage:"La temporada 2026 terminó el 4 de octubre. No hay una transmisión gratuita disponible en Roku Plus. Consulta los contenidos oficiales en ViX."
            sourcePage:"https://www.lacasadelosfamososmexico.tv/quien-gano-la-casa-de-los-famosos-mexico-2026/"
            url:"", streamFormat:"", live:false, poster:"pkg:/images/ui/live-program-casa.png", background:""
            description:"Ficha informativa. La transmisión 24/7 y las galas dependen de la edición, la temporada y el servicio oficial."
            year:"2026", runtime:0, language:"es", seasons:[]
        }
    ]
end function

function rpLivePlayable(item as dynamic) as boolean
    if type(item) <> "roAssociativeArray" then return false
    if item.available = false then return false
    if item.kind <> "live" then return false
    if GetInterface(item.url,"ifString") = invalid then return false
    if orbitPublicMediaUrl(item.url) = "" then return false
    return item.streamFormat = "hls" or item.streamFormat = "mp4" or item.streamFormat = "ts"
end function
