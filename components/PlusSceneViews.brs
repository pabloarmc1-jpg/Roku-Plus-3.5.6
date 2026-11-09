' Original Liquid Glass-inspired Roku Plus chrome. All coordinates use FHD units.
' The glass is a static translucent treatment; it does not blur video at runtime.
function panel(x as float, y as float, w as float, h as float, color as string) as object
    node = m.canvas.createChild("Rectangle")
    node.translation = [x,y]
    node.width = w
    node.height = h
    node.color = color
    return node
end function

function words(text as string, x as float, y as float, w as float, h as float, size as integer, color = "0xF5F5F7FF" as string) as object
    node = m.canvas.createChild("Label")
    node.translation = [x,y]
    node.width = w
    node.height = h
    node.color = color
    node.text = text
    font = node.font
    font.size = size
    node.font = font
    return node
end function

function art(uri as string, x as float, y as float, w as float, h as float, mode = "scaleToFill" as string) as object
    poster = m.canvas.createChild("Poster")
    poster.translation = [x,y]
    poster.width = w
    poster.height = h
    poster.loadWidth = int(w)
    poster.loadHeight = int(h)
    poster.loadDisplayMode = mode
    poster.uri = themeAsset(uri)
    m.images.push(poster)
    return poster
end function

function themeAsset(uri as string) as string
    if m.theme <> "classic" then return uri
    prefix = "pkg:/images/ui/"
    if left(uri,len(prefix)) <> prefix then return uri
    if type(m.uiClassicAssetMap) <> "roAssociativeArray"
        m.uiClassicAssetMap = {}
        for each stem in ["app-background","rail-glass","button-white","button-dark","nav-active","nav-focus","setup-card","pill","glass-row","glass-reality","glass-section","glass-chip","glass-tile","glass-badge","glass-notice","live-preview-frame","live-preview-mask","live-channel-row","live-channel-selected","live-logo-badge","live-empty"]
            m.uiClassicAssetMap[stem+".png"] = stem+"-classic.png"
        end for
    end if
    name = mid(uri,len(prefix)+1)
    if m.uiClassicAssetMap.doesExist(name) then return prefix+m.uiClassicAssetMap[name]
    return uri
end function

function glassSurface(name as string, x as float, y as float, w as float, h as float) as object
    return art("pkg:/images/ui/"+name+".png",x,y,w,h)
end function

sub thumbnail(uri as string, x as float, y as float, w as float, h as float, shape = "landscape" as string)
    base = "0x1B221EFF"
    if m.theme = "classic" then base = "0x101D2DFF"
    panel(x,y,w,h,base)
    if uri <> ""
        if shape = "poster" then art(uri,x,y,w,h,"scaleToFit") else art(uri,x,y,w,h)
    end if
    ' Keep artwork clean and edge-to-edge; focus is shown by the navigation outline.
end sub

sub eraseScreen()
    ' Disconnect before clearing URIs: a cached or failed request from the old
    ' render must never change a badge belonging to the new channel page.
    if type(m.liveLogoFallbacks) = "roArray"
        for each entry in m.liveLogoFallbacks
            entry.poster.unobserveField("loadStatus")
        end for
    end if
    m.liveLogoFallbacks = []
    for each image in m.images
        image.uri = ""
    end for
    m.images = []
    m.focusItems = []
    m.canvas.removeChildrenIndex(m.canvas.getChildCount(),0)
    m.canvas.visible = true
    panel(0,0,1920,1080,"0x080808FF")
end sub

sub focusTarget(zone as string, index as integer, x as integer, y as integer, w as integer, h as integer, shape = "wide" as string)
    uri = "pkg:/images/ui/focus-button.png"
    if shape = "card" then uri = "pkg:/images/ui/focus-card.png"
    if shape = "landscape" then uri = "pkg:/images/ui/focus-landscape.png"
    if shape = "setup" then uri = "pkg:/images/ui/setup-focus.png"
    if shape = "catalog" then uri = "pkg:/images/ui/focus-catalog.png"
    if shape = "live" then uri = "pkg:/images/ui/focus-live.png"
    if shape = "reality" then uri = "pkg:/images/ui/focus-reality.png"
    if shape = "live-channel" then uri = "pkg:/images/ui/live-row-focus.png"
    if shape = "live-search" then uri = "pkg:/images/ui/focus-row.png"
    if shape = "appearance" then uri = "pkg:/images/ui/focus-appearance.png"
    if shape = "wide" and w > 1000 then uri = "pkg:/images/ui/focus-row.png"
    edge = art(uri,x,y,w,h)
    edge.visible = false
    m.focusItems.push({zone:zone,index:index,edge:edge})
end sub

sub selectable(zone as string, index as integer, text as string, x as integer, y as integer, w as integer, h as integer, primary = false as boolean)
    surface = "0x2F2F2FFF"
    ink = "0xFFFFFFFF"
    if primary
        surface = "0xFFFFFFFF"
        ink = "0x080808FF"
    end if
    panel(x,y,w,h,surface)
    label = words(text,x+12,y+15,w-24,h-18,26,ink)
    label.horizAlign = "center"
    focusTarget(zone,index,x-4,y-4,w+8,h+8)
end sub

sub brand(x as integer, y as integer)
    art("pkg:/images/ui/logo.png",x,y,52,52)
    words("ROKU PLUS",x+66,y+6,260,48,31,"0xE50914FF")
end sub

function countryName() as string
    country = orbitCountryLookup(m.countryCode)
    if country = invalid then return "México"
    return country.name
end function

function modeName() as string
    if m.catalogMode = "hevc" then return "Televisor 4K"
    return "HD / Full HD"
end function

sub topBar()
    ' Netflix-inspired horizontal navigation; live TV keeps a compact rail so its preview remains unobstructed.
    barHeight = 118
    logoX = 52 : logoY = 30 : logoSize = 46
    brandX = 106 : brandY = 31 : brandSize = 29
    labelY = 43 : labelSize = 22 : focusY = 27 : focusH = 64 : underlineY = 83
    navX = 260
    if m.view = "live"
        barHeight = 52
        logoX = 18 : logoY = 8 : logoSize = 34
        brandX = 60 : brandY = 8 : brandSize = 21
        labelY = 7 : labelSize = 17 : focusY = 1 : focusH = 44 : underlineY = 44
        navX = 220
    end if
    panel(0,0,1920,barHeight,"0x080808F2")
    art("pkg:/images/ui/logo.png",logoX,logoY,logoSize,logoSize)
    words("ROKU",brandX,brandY,112,44,brandSize,"0xE50914FF")
    labels = ["Inicio","Películas","Series","TV en vivo","Buscar","Mi lista","Historial","Ajustes","Perfiles"]
    active = 0
    if m.view = "browse" or m.view = "detail" or m.view = "episodes"
        active = 1
        if m.kind = "series" then active = 2
    else if m.view = "live"
        active = 3
    else if m.view = "library"
        active = 6
        if m.libraryMode = "list" then active = 5
    else if m.view = "settings" or m.view = "credits" or m.view = "hd-source" or m.view = "appearance"
        active = 7
    else if m.view = "profiles"
        active = 8
    end if
    widths = [100,135,105,135,100,105,115,100,100]
    x = navX
    for i = 0 to 8
        w = widths[i]
        if active = i
            panel(x-10,underlineY,w+20,4,"0xE50914FF")
            words(labels[i],x,labelY,w,38,labelSize,"0xFFFFFFFF")
        else
            words(labels[i],x,labelY,w,38,labelSize-1,"0xD0D0D0FF")
        end if
        if m.zone = "nav" and m.nav = i
            panel(x-13,focusY,w+26,focusH,"0xFFFFFF20")
            focusTarget("nav",i,x-14,focusY-4,w+28,focusH+8,"wide")
        end if
        x = x+w+18
    end for
    profileY = 43
    if m.view = "live" then profileY = 7
    words(rpProfileName(m.profileId),1580,profileY,275,38,20,"0xD0D0D0FF").horizAlign = "right"
end sub

sub drawScreen()
    if m.view = "player" then return
    eraseScreen()
    if m.view = "setup-tv"
        setupTvScreen()
    else if m.view = "setup-country"
        setupCountryScreen()
    else
        if m.view = "home" then homeScreen()
        if m.view = "library" then libraryScreen()
        if m.view = "browse" then browseScreen()
        if m.view = "detail" then detailScreen()
        if m.view = "episodes" then episodeScreen()
        if m.view = "live" then liveScreen()
        if m.view = "settings" then settingsScreen()
        if m.view = "profiles" then profilesScreen()
        if m.view = "appearance" then appearanceScreen()
        if m.view = "credits" then creditsScreen()
        if m.view = "hd-source" then hdSourceScreen()
        if m.busy or m.note <> ""
            panel(72,970,1770,86,"0x181818F5")
            text = m.note
            if m.busy then text = "Consultando el catálogo…"
            if m.busy and type(m.pending) = "roAssociativeArray"
                if m.pending.operation = "country" then text = "Cargando canales de " + countryName() + "…"
                if m.pending.operation = "compatible" then text = "Preparando la reproducción con tu computadora…"
            end if
            words(text,96,990,1715,55,23,"0xFFFFFFFF").wrap = true
        end if
    end if
    paintFocus()
end sub

sub setupTvScreen()
    brand(85,65)
    setupHeading = "CONFIGURACIÓN INICIAL · 1 DE 2"
    if m.setupFromSettings then setupHeading = "CONFIGURACIÓN · 1 DE 2"
    words(setupHeading,87,177,1700,46,23,"0x9B9BA5FF")
    words("Selecciona tu televisor",82,244,1750,92,62)
    words("Elige la biblioteca que utilizarás. Podrás cambiarla después en Configuración.",87,350,1710,80,29,"0xB8B8C2FF").wrap = true
    names = ["HD / Full HD","4K"]
    tags = ["HD","4K"]
    descriptions = ["Películas y series con selección de fuentes H.264 compatibles.","El catálogo ampliado de películas y series que ya conoces."]
    for i = 0 to 1
        x = 84 + i * 912
        panel(x,466,838,300,"0x181818FF")
        art("pkg:/images/ui/tv.png",x+34,496,72,72)
        words(tags[i],x+132,492,620,77,60)
        words(names[i],x+38,588,760,54,34)
        words(descriptions[i],x+38,654,760,91,25,"0xAFAFB9FF").wrap = true
        recommended = (i = 0 and m.capabilities.recommendedCatalog = "hd") or (i = 1 and m.capabilities.recommendedCatalog = "hevc")
        if recommended then words("Recomendado para esta Roku",x+38,785,790,44,24,"0xE5E5EAFF")
        focusTarget("setup",i,x-6,460,850,312,"setup")
    end for
    words("La opción 4K describe el equipo. La calidad disponible depende de cada video.",87,881,1730,59,24,"0x888893FF").wrap = true
    words("← / →: elegir     OK: continuar",87,1004,1730,42,24,"0xB9B9C2FF")
end sub

sub setupCountryScreen()
    brand(85,65)
    setupHeading = "CONFIGURACIÓN INICIAL · 2 DE 2"
    if m.setupFromSettings then setupHeading = "CONFIGURACIÓN · 2 DE 2"
    if m.setupCountryOnly then setupHeading = "TU PAÍS O REGIÓN"
    words(setupHeading,87,177,1700,46,23,"0x9B9BA5FF")
    words("¿En qué país estás?",82,250,660,173,60).wrap = true
    words("Mostraremos los canales de tu país o región. Puedes cambiarlo cuando quieras.",87,470,620,193,31,"0xB8B8C2FF").wrap = true
    art("pkg:/images/ui/world.png",87,708,98,98)
    countries = orbitCountries()
    first = (m.setupCountry \ 7) * 7
    for i = 0 to 6
        n = first + i
        if n < countries.count()
            y = 268+i*91
            panel(793,y,1035,79,"0x181818FF")
            words(ucase(countries[n].code),824,y+21,106,42,25,"0xA2A2ADFF")
            words(countries[n].name,950,y+19,839,47,31)
            focusTarget("country",n,786,y-5,1048,89)
        end if
    end for
    words((m.setupCountry+1).toStr()+" de "+countries.count().toStr(),800,936,1000,39,22,"0x9595A1FF")
    words("↑ / ↓: elegir     OK: guardar y entrar     Atrás: volver",87,1004,1730,42,24,"0xB9B9C2FF")
end sub

sub homeScreen()
    ' Full-width cinematic hero followed by Netflix-inspired horizontal content rails.
    panel(0,0,1920,1080,"0x080808FF")
    if m.features.count() > 0
        heroIndex = m.heroFeature
        if heroIndex < 0 or heroIndex >= m.features.count() then heroIndex = 0
        item = m.features[heroIndex]
        heroUri = item.background
        if heroUri = "" then heroUri = item.poster
        if heroUri <> "" then art(heroUri,0,0,1920,500)
        art("pkg:/images/ui/hero-shade.png",0,0,1920,560)
        featureCount = m.features.count()
        featureLabel = "DESTACADO  ·  "+(heroIndex+1).toStr()+" / "+featureCount.toStr()
        words(featureLabel,76,160,900,36,21,"0xE50914FF")
        words(item.title,72,205,1080,112,58,"0xFFFFFFFF").wrap = true
        facts = item.year
        if m.catalogMode = "hd"
            if usesOnlineHd() then facts += " · "+hdProviderName(item.provider) else facts += " · Corto"
        end if
        if facts <> "" then words(facts,78,326,850,36,23,"0xE5E5E5FF")
        selectable("hero",0,"▶  Reproducir",76,382,270,62,true)
        selectable("hero",1,"ⓘ  Más información",365,382,320,62)
        words("⏮ / ⏭  Cambiar destacado",1180,405,650,32,18,"0xD0D0D0FF").horizAlign = "right"
    else
        words("Tu próxima historia",76,208,1400,82,56)
        text = "Actualizando las películas y series populares…"
        if not m.homeLoading then text = "Abre Películas o Series para explorar el catálogo."
        words(text,80,316,1470,76,28,"0xB8B8B8FF").wrap = true
        selectable("hero",0,"Actualizar",76,382,270,62,true)
    end if

    ' First rail: featured titles. Large posters use a consistent 2:3 treatment.
    heading = "Populares en Roku Plus"
    if m.catalogMode = "hd"
        heading = "Cortos en HD"
        if usesOnlineHd() then heading = "Películas para explorar"
    end if
    words(heading,76,510,1500,42,30,"0xFFFFFFFF")
    for i = 0 to 3
        if i < m.features.count()
            item = m.features[i]
            x = 76+i*450
            uri = item.poster
            if uri = "" then uri = item.background
            panel(x-8,560,420,220,"0x171717FF")
            if uri <> "" then art(uri,x,568,122,184,"scaleToFit")
            words(item.title,x+138,580,270,70,23,"0xFFFFFFFF").wrap = true
            facts = item.year
            if item.kind = "series" then facts += " · Serie"
            words(facts,x+140,656,260,34,18,"0xB3B3B3FF")
            words("Ver detalles  ›",x+140,710,260,34,18,"0xE50914FF")
            focusTarget("covers",i,x-14,552,436,236,"card")
        end if
    end for

    ' Second rail: resume playback, or discover series when there is no progress yet.
    if m.continueItems.count() > 0
        words("Continuar viendo",76,806,1500,42,30,"0xFFFFFFFF")
        for i = 0 to 2
            if i < m.continueItems.count()
                item = m.continueItems[i]
                x = 76+i*590
                panel(x-8,856,530,142,"0x171717FF")
                uri = item.background
                if uri = "" then uri = item.poster
                if uri <> "" then art(uri,x,864,180,116,"scaleToFill")
                words(item.title,x+198,870,315,48,23,"0xFFFFFFFF").wrap = true
                progressText = "Reanudar reproducción"
                resumeDuration = 0
                resumePosition = 0
                if item.doesExist("duration") then resumeDuration = rpWatchNumber(item.duration)
                if item.doesExist("position") then resumePosition = rpWatchNumber(item.position)
                if resumeDuration > 0
                    ratio = resumePosition / resumeDuration
                    if ratio < 0 then ratio = 0
                    if ratio > 1 then ratio = 1
                    progressText = timeText(resumePosition)+" de "+timeText(resumeDuration)
                    panel(x+198,944,310,5,"0x777777FF")
                    panel(x+198,944,310*ratio,5,"0xE50914FF")
                end if
                words(progressText,x+198,960,315,27,17,"0xB3B3B3FF")
                focusTarget("continue",i,x-14,848,546,158,"card")
            end if
        end for
    else if m.homeSeries.count() > 0
        words("Series para descubrir",76,806,1500,42,30,"0xFFFFFFFF")
        for i = 0 to 2
            if i < m.homeSeries.count()
                item = m.homeSeries[i]
                x = 76+i*590
                uri = item.poster
                if uri = "" then uri = item.background
                panel(x-8,856,530,142,"0x171717FF")
                if uri <> "" then art(uri,x,864,180,116,"scaleToFill")
                words(item.title,x+198,880,315,54,24,"0xFFFFFFFF").wrap = true
                words("Explorar episodios  ›",x+198,948,315,30,18,"0xE50914FF")
                focusTarget("home-series",i,x-14,848,546,158,"card")
            end if
        end for
    end if
    topBar()
end sub

sub libraryScreen()
    topBar()
    heading = "Historial de reproducción"
    if m.libraryMode = "list" then heading = "Mi lista"
    words(heading,72,142,1500,76,46,"0xFFFFFFFF")
    words("Perfil: "+rpProfileName(m.profileId)+" · Tu actividad se guarda en esta Roku.",76,218,1450,40,22,"0xB3B3B3FF")
    if m.libraryItems.count() = 0
        empty = "Todavía no hay títulos en tu historial."
        if m.libraryMode = "list" then empty = "Añade películas o series con INFO desde su ficha."
        words(empty,350,380,1400,100,31,"0xB8CEE1FF").wrap = true
        return
    end if
    first = (m.libraryCursor \ 6)*6
    for i = 0 to 5
        n = first+i
        if n < m.libraryItems.count()
            item = m.libraryItems[n]
            y = 290+i*112
            panel(72,y,1770,94,"0x181818FF")
            uri = item.poster
            if uri = "" then uri = item.background
            if uri <> "" then thumbnail(uri,84,y+7,138,80)
            words(item.title,244,y+12,930,42,26,"0xFFFFFFFF").wrap = true
            state = "En historial"
            if item.watched then state = "✓ Vista"
            if item.listed then state += " · ♥ Mi lista"
            words(state,1450,y+25,350,36,20,"0xE50914FF").horizAlign = "right"
            focusTarget("library",n,66,y-4,1782,102,"live")
        end if
    end for
    words("↑ / ↓: seleccionar     OK: abrir ficha     OPTIONS: eliminar del perfil",76,1010,1480,34,20,"0x808080FF")
end sub

sub browseScreen()
    topBar()
    title = "Películas populares"
    if m.kind = "series" then title = "Series populares"
    if m.catalogMode = "hd"
        if usesOnlineHd()
            title = "Películas · "+hdProviderName()
            if m.kind = "series" then title = "Series · "+hdProviderName()
        else
            title = "Cortos y cine abierto"
            if m.kind = "series" then title = "Documentales en español"
        end if
    end if
    if m.query <> "" then title = "Resultados: " + m.query
    words(title,72,135,1500,72,46,"0xFFFFFFFF").wrap = true
    hint = "Explora el catálogo y selecciona un título para ver sus detalles."
    if usesOnlineHd() and m.hdProvider = "all" then hint = "Opciones de varias fuentes. Si una falla, prueba la misma película en otra."
    words(hint,76,208,1185,42,22,"0xB3B3B3FF").wrap = true
    searchHint = "Buscar con OK en Buscar"
    if m.genreFilter <> "Todos" then searchHint = "Género: " + m.genreFilter
    words(searchHint,1260,210,577,38,19,"0xE5E5E5FF").horizAlign = "right"
    words("OPTIONS: filtrar por género",76,245,720,28,17,"0x888888FF")

    ' Netflix-like poster wall: five columns by two rows. The remote scrolls
    ' through ten-card windows while retaining the provider's twenty-item page.
    first = (m.cursor \ 10)*10
    for i = 0 to 9
        n = first+i
        if n < m.titles.count()
            item = m.titles[n]
            col = i mod 5
            row = i \ 5
            x = 72+col*360
            y = 270+row*360
            uri = item.poster
            if uri = "" then uri = item.background
            panel(x,y,330,344,"0x151515FF")
            if uri <> "" then thumbnail(uri,x+56,y+7,218,276,"poster")
            words(item.title,x+8,y+288,314,42,21,"0xFFFFFFFF").wrap = true
            saved = rpWatchGet(m.watchState,item.id)
            status = ""
            if saved <> invalid
                if saved.watched then status = "✓ VISTA"
                if saved.listed
                    if status <> "" then status += "  ·  "
                    status += "♥ MI LISTA"
                end if
                if saved.position > 15 and saved.duration > 0 and saved.position < saved.duration*0.92
                    ratio = saved.position / saved.duration
                    if ratio < 0 then ratio = 0
                    if ratio > 1 then ratio = 1
                    panel(x+12,y+337,306,4,"0x777777FF")
                    panel(x+12,y+337,306*ratio,4,"0xE50914FF")
                end if
            end if
            if status <> "" then words(status,x+8,y+326,314,22,14,"0xE50914FF")
            focusTarget("grid",n,x-5,y-5,340,354,"catalog")
        end if
    end for
    last = first+10
    if last > m.titles.count() then last = m.titles.count()
    if last > first
        caption = "Títulos "+(m.offset+first+1).toStr()+"–"+(m.offset+last).toStr()
        if usesOnlineHd() and (m.hdProvider = "all" or m.hdProvider = "seriesmetro" or m.hdProvider = "cinecalidad") then caption = "Opciones "+(first+1).toStr()+"–"+last.toStr()+" · Página "+((m.offset\20)+1).toStr()
        words(caption,76,1015,1000,34,19,"0x808080FF")
    end if
    if m.titles.count() = 0 and not m.busy
        empty = "No se encontraron títulos."
        if m.genreFilter <> "Todos" then empty = "No hay títulos de " + m.genreFilter + " en esta página. Pulsa OPTIONS para cambiar el filtro."
        if m.more then empty = "Sin opciones en esta página. Pulsa ↓ para consultar la siguiente."
        words(empty,92,420,1410,104,32,"0xB6B6B6FF").wrap = true
    end if
    hint = "↓ Más títulos"
    if first+10 >= m.titles.count() and not m.more then hint = "Fin del catálogo"
    words(hint,1330,1015,500,34,19,"0xB3B3B3FF").horizAlign = "right"
end sub

sub detailSelectable(index as integer, text as string, x as integer, y as integer, w as integer, h as integer, primary = false as boolean)
    surface = "0x30343BFF"
    ink = "0xFFFFFFFF"
    if primary
        surface = "0xFFFFFFFF"
        ink = "0x101114FF"
    end if
    panel(x,y,w,h,surface)
    label = words(text,x+14,y+17,w-28,h-20,28,ink)
    label.horizAlign = "center"
    focusTarget("action",index,x-5,y-5,w+10,h+10)
end sub

sub detailScreen()
    topBar()
    if m.detail = invalid then return
    item = m.detail
    backdrop = orbitText(item.background,2048)
    if backdrop <> "" then art(backdrop,0,112,1920,968)
    panel(0,112,1920,968,"0x080808E8")
    uri = orbitText(item.poster,2048)
    if uri = "" then uri = backdrop
    thumbnail(uri,92,245,390,570,"poster")

    heading = "PELÍCULA"
    if item.kind = "series" then heading = "SERIE"
    if item.kind = "episode" then heading = "EPISODIO"
    if m.catalogMode = "hd" then heading = "BIBLIOTECA HD"
    if usesOnlineHd() then heading = "BIBLIOTECA HD · "+hdProviderName(item.provider)
    words(heading,540,222,1160,36,20,"0xE50914FF")
    words(orbitText(item.title,240),536,270,1190,122,52,"0xFFFFFFFF").wrap = true

    facts = ""
    if item.doesExist("year") and GetInterface(item.year,"ifString") <> invalid
        if item.year <> "" then facts = item.year
    end if
    ' Provider metadata may omit runtime or send it in a non-numeric form.
    ' Normalize it before comparison so incomplete catalog entries cannot
    ' crash the SceneGraph render thread.
    detailRuntime = 0
    if item.doesExist("runtime") then detailRuntime = rpWatchNumber(item.runtime)
    if detailRuntime > 0
        if facts <> "" then facts += "   ·   "
        facts += timeText(detailRuntime)
    end if
    if facts <> "" then words(facts,542,405,1045,38,24,"0xE0E3E8FF")

    genre = ""
    if item.doesExist("genre") and GetInterface(item.genre,"ifString") <> invalid then genre = item.genre
    if item.doesExist("genres") and type(item.genres) = "roArray"
        for each genreItem in item.genres
            if GetInterface(genreItem,"ifString") <> invalid
                if genre <> "" then genre += " · "
                genre += genreItem
                if len(genre) > 70 then exit for
            end if
        end for
    end if
    if genre <> "" then words(genre,542,445,1110,36,22,"0xC5CBD4FF")

    saved = rpWatchGet(m.watchState,item.id)
    statusText = ""
    if saved <> invalid
        if saved.watched then statusText = "✓ YA VISTA"
        if saved.listed
            if statusText <> "" then statusText += "     ·     "
            statusText += "♥ MI LISTA"
        end if
        if saved.position > 15 and saved.duration > 0 and saved.position < saved.duration*0.92
            if statusText <> "" then statusText += "     ·     "
            statusText += "Continuar desde "+timeText(saved.position)
        end if
    end if
    statusY = 485
    if genre = "" then statusY = 455
    if statusText <> "" then words(statusText,542,statusY,1100,32,19,"0xE50914FF")

    summaryY = statusY+48
    ' Provider descriptions are optional and may arrive as Invalid or another type.
    summary = orbitText(item.description,701)
    if summary = "" then summary = "Consulta la disponibilidad de este título."
    summaryText = left(summary,700)
    if len(summary) > 700 then summaryText += "…"
    words(summaryText,542,summaryY,1110,126,26,"0xF0F1F4FF").wrap = true

    if saved <> invalid and saved.duration > 0 and saved.position > 15 and saved.position < saved.duration*0.92
        panel(542,summaryY+132,1050,8,"0x555555FF")
        progressWidth = int(1050*saved.position/saved.duration)
        if progressWidth < 1 then progressWidth = 1
        if progressWidth > 1050 then progressWidth = 1050
        panel(542,summaryY+132,progressWidth,8,"0xE50914FF")
        words("PROGRESO · "+timeText(saved.position)+" / "+timeText(saved.duration),542,summaryY+148,1050,30,18,"0xC5CBD4FF")
    end if

    actionY = 724
    if summaryY > 500 then actionY = 752
    title = "▶  Reproducir"
    if item.kind = "series" then title = "Ver episodios"
    detailSelectable(0,title,542,actionY,500,72,true)
    if detailActionCount() = 3
        detailSelectable(1,"Reproducción con PC",542,actionY+78,500,66)
        detailSelectable(2,"Volver",542,actionY+150,500,66)
    else
        detailSelectable(1,"Volver",542,actionY+88,500,66)
    end if
    sourceName = orbitText(item.source,120)
    if sourceName <> "" then words("Fuente: "+sourceName,98,850,390,100,19,"0xB3B3B3FF").wrap = true
    words("*  Marcar como vista     INFO  Añadir / quitar de Mi lista",542,974,1190,34,20,"0xC5CBD4FF")
end sub

' Display a series year only when another loaded series has the same
' normalized title but a different year. This affects presentation only.
function rpSeasonTitleBase(title as dynamic) as string
    value = orbitText(title,240).trim()
    value = CreateObject("roRegex","\\s*\\((19|20)[0-9]{2}\\)\\s*$","").replace(value,"").trim()
    value = lcase(value)
    value = value.replace("á","a").replace("é","e").replace("í","i").replace("ó","o").replace("ú","u").replace("ñ","n")
    return CreateObject("roRegex","\\s+","").replace(value,"")
end function

function rpSeasonTitleYear(item as dynamic) as string
    if type(item) <> "roAssociativeArray" then return ""
    title = orbitText(item.title,240).trim()
    yearPattern = CreateObject("roRegex","\\((19|20)[0-9]{2}\\)\\s*$","")
    if yearPattern.isMatch(title) then return mid(title,len(title)-4,4)
    return orbitText(item.year,16).trim()
end function

function rpSeasonTitleHasDifferentYear(items as dynamic, baseTitle as string, currentYear as string, currentId as string) as boolean
    if type(items) <> "roArray" or baseTitle = "" or currentYear = "" then return false
    for each other in items
        if type(other) = "roAssociativeArray"
            otherId = orbitText(other.id,200)
            if currentId = "" or otherId <> currentId
                otherBase = rpSeasonTitleBase(other.title)
                otherYear = rpSeasonTitleYear(other)
                if otherBase = baseTitle and otherYear <> "" and otherYear <> currentYear then return true
            end if
        end if
    end for
    return false
end function

function rpSeasonDisplayTitle(series as dynamic) as string
    if type(series) <> "roAssociativeArray" then return ""
    title = orbitText(series.title,240).trim()
    baseTitle = rpSeasonTitleBase(title)
    year = rpSeasonTitleYear(series)
    currentId = orbitText(series.id,200)
    differentYearExists = rpSeasonTitleHasDifferentYear(m.pageTitles,baseTitle,year,currentId)
    if not differentYearExists then differentYearExists = rpSeasonTitleHasDifferentYear(m.homeSeries,baseTitle,year,currentId)
    if not differentYearExists then differentYearExists = rpSeasonTitleHasDifferentYear(m.features,baseTitle,year,currentId)
    if differentYearExists and year <> "" then return titleWithoutYear(baseTitle,year)
    return baseTitle
end function

function titleWithoutYear(baseTitle as string, year as string) as string
    ' Restore readable spacing from the original title while omitting its year.
    ' The caller supplies the original title through the current series object.
    original = orbitText(m.series.title,240).trim()
    original = CreateObject("roRegex","\\s*\\((19|20)[0-9]{2}\\)\\s*$","").replace(original,"").trim()
    if original <> "" then return original + " (" + year + ")"
    return baseTitle + " (" + year + ")"
end function

sub episodeScreen()
    topBar()
    if m.series = invalid or m.series.seasons.count() = 0 then return

    ' Cinematic series backdrop with a dark overlay for readable text.
    backdrop = orbitText(m.series.background,2048)
    if backdrop = "" then backdrop = orbitText(m.series.poster,2048)
    if backdrop <> "" then art(backdrop,0,112,1920,968)
    panel(0,112,1920,968,"0x080808B8")

    displaySeriesTitle = rpSeasonDisplayTitle(m.series)
    words(displaySeriesTitle,76,142,1500,66,43,"0xFFFFFFFF").wrap = true
    words("TEMPORADAS",80,218,420,30,18,"0xA3A3A3FF")

    ' Compact horizontal season selector.
    firstSeason = (m.season \ 6)*6
    for i = 0 to 5
        n = firstSeason+i
        if n < m.series.seasons.count()
            season = m.series.seasons[n]
            x = 76+i*294
            seasonName = "Temporada "+season.number.toStr()
            if season.number = 0 then seasonName = "Especiales"
            if n = m.season
                words(seasonName,x,260,278,48,24,"0xFFFFFFFF")
                panel(x,310,278,4,"0xE50914FF")
            else
                words(seasonName,x,260,278,48,23,"0xB3B3B3FF")
            end if
            focusTarget("seasons",n,x-8,250,292,70,"wide")
        end if
    end for

    season = m.series.seasons[m.season]
    words("EPISODIOS",80,356,500,30,18,"0xA3A3A3FF")
    if season.episodes.count() = 0
        message = "Cargando episodios…"
        if not m.busy then message = "No se encontraron episodios para esta temporada."
        words(message,100,500,1600,70,30,"0xB3B3B3FF")
        words("← / →  Cambiar temporada     ↓  Episodios     Atrás  Volver",80,1018,1700,34,19,"0x808080FF")
        return
    end if

    ' Horizontal episode carousel: four large previews per screen.
    firstEpisode = (m.episode \ 4)*4
    for i = 0 to 3
        n = firstEpisode+i
        if n < season.episodes.count()
            item = season.episodes[n]
            x = 76+i*446
            y = 414
            ' Episode artwork is independent: prefer the episode thumbnail/poster.
            imageUri = orbitText(item.poster,2048)
            if imageUri = "" then imageUri = orbitText(item.background,2048)
            thumbnail(imageUri,x,y,416,234,"landscape")

            watched = rpWatchGet(m.watchState,item.id)
            if watched <> invalid
                if watched.watched = true then words("VISTO",x+278,y+10,126,24,15,"0xE50914FF").horizAlign = "right"
            end if

            ' Show the episode's actual title, not a generic season/episode label.
            episodeTitle = orbitText(item.title,150)
            if episodeTitle = "" then episodeTitle = "Episodio "+item.episode.toStr()
            words(episodeTitle,x+2,y+252,412,88,25,"0xFFFFFFFF").wrap = true
            if n = m.episode then panel(x,y+346,416,4,"0xE50914FF")
            focusTarget("episodes",n,x-7,y-7,430,366,"landscape")
        end if
    end for

    ' The series synopsis stays below the episode carousel.
    synopsis = orbitText(m.series.description,520)
    if synopsis <> ""
        words("SINOPSIS",80,830,400,25,16,"0xA3A3A3FF")
        words(synopsis,80,862,1750,76,19,"0xD0D0D0FF").wrap = true
    end if

    lastEpisode = firstEpisode+4
    if lastEpisode > season.episodes.count() then lastEpisode = season.episodes.count()
    words("Episodios "+(firstEpisode+1).toStr()+"–"+lastEpisode.toStr()+" de "+season.episodes.count().toStr(),80,1000,800,32,18,"0x808080FF")
    words("← / →  Elegir episodio     OK  Ver episodio     ↑  Temporadas",950,1000,870,32,18,"0x808080FF").horizAlign = "right"
end sub

sub liveChannelBadge(item as object, x as integer, y as integer)
    glassSurface("live-logo-badge",x,y,106,77)
    initials = "TV"
    if GetInterface(item.title,"ifString") <> invalid
        parts = item.title.trim().split(" ")
        if parts.count() > 1
            initials = ucase(left(parts[0],1)+left(parts[1],1))
        else if parts.count() = 1
            initials = ucase(left(parts[0],2))
        end if
    end if
    badge = words(initials,x+4,y+18,98,45,28,"0x303633FF")
    badge.horizAlign = "center"
    uri = ""
    if GetInterface(item.poster,"ifString") <> invalid then uri = item.poster
    if uri <> ""
        poster = art("",x+7,y+7,92,63,"scaleToFit")
        poster.visible = false
        m.liveLogoFallbacks.push({poster:poster,fallback:badge})
        ' Cached images may become ready as soon as URI is set.
        poster.observeField("loadStatus","liveLogoLoadStatusChanged")
        poster.uri = uri
    end if
end sub

sub liveLogoLoadStatusChanged(event as object)
    if type(m.liveLogoFallbacks) <> "roArray" then return
    poster = event.getRoSGNode()
    for each entry in m.liveLogoFallbacks
        if entry.poster.isSameNode(poster)
            ready = event.getData() = "ready"
            entry.poster.visible = ready
            entry.fallback.visible = not ready
            return
        end if
    end for
end sub

function liveChannelStatus(item as object) as string
    if item.available = false
        if GetInterface(item.availabilityLabel,"ifString") <> invalid then return item.availabilityLabel
        return "Sin señal disponible"
    end if
    return "En vivo"
end function

sub liveScreen()
    topBar()
    query = ""
    if GetInterface(m.liveQuery,"ifString") <> invalid then query = m.liveQuery
    searching = query <> ""
    searchEmpty = searching and m.channels.count() = 0 and not m.busy
    words("TV en vivo",303,62,470,86,50)
    selectable("live-filters",0,"Todos",801,83,194,66,m.liveFilter=0)
    selectable("live-filters",1,countryName(),1011,83,309,66,m.liveFilter=1)
    selectable("live-filters",2,"LATAM",1336,83,209,66,m.liveFilter=2)
    selectable("live-filters",3,"Favoritos",1561,83,321,66,m.liveFilter=3)
    searchWidth = 1008
    searchText = "Buscar canales…"
    if searching
        searchWidth = 792
        displayQuery = query
        if len(displayQuery) > 42 then displayQuery = left(displayQuery,41)+"…"
        searchText = "Buscar: "+displayQuery
    end if
    panel(303,150,searchWidth,46,"0x181818FF")
    art("pkg:/images/ui/search.png",322,160,26,26)
    words(searchText,365,160,searchWidth-80,29,22,"0xE8EEE3FF")
    focusTarget("live-search",0,299,146,searchWidth+8,54,"live-search")
    if searching
        art("pkg:/images/ui/button-dark.png",1111,150,200,46)
        words("Borrar",1121,160,180,29,22,"0xE8EEE3FF").horizAlign = "center"
        focusTarget("live-search",1,1107,146,208,54)
    end if
    listHeading = "CANALES"
    if searching then listHeading = "RESULTADOS"
    words(listHeading,1352,169,220,31,20,"0xC7CFC9FF")

    ' The real decoder occupies exactly [294,206,1016,572] above the canvas.
    ' The rim remains outside that rectangle, including on square-video devices.
    panel(285,197,1034,590,"0x202020FF")
    panel(294,206,1016,572,"0x141A19FF")
    art("pkg:/images/ui/live-preview-base.png",294,206,1016,572)
    art("pkg:/images/ui/live.png",754,414,96,96)
    placeholder = "Elige un canal para comenzar"
    if type(m.livePreviewItem) = "roAssociativeArray"
        placeholder = "Preparando la señal…"
        if GetInterface(m.livePreviewStatus,"ifString") <> invalid
            if m.livePreviewStatus <> "" then placeholder = m.livePreviewStatus
        end if
    end if
    if searchEmpty then placeholder = "No se encontraron canales"
    words(placeholder,390,534,824,78,28,"0xC6CEC7FF").horizAlign = "center"
    art("pkg:/images/ui/live-preview-mask.png",294,206,1016,572)

    current = invalid
    if m.channels.count() > 0 and type(m.livePreviewItem) = "roAssociativeArray" then current = m.livePreviewItem
    if current = invalid and m.liveCursor >= 0 and m.liveCursor < m.channels.count() then current = m.channels[m.liveCursor]
    if type(current) = "roAssociativeArray"
        words(current.title,303,806,626,102,39).wrap = true
        subtitle = "Canal en vivo"
        if GetInterface(current.subtitle,"ifString") <> invalid
            if current.subtitle <> "" then subtitle = current.subtitle
        end if
        words(subtitle,307,915,622,38,24,"0xD6DCD5FF")
        status = liveChannelStatus(current)
        if type(m.livePreviewItem) = "roAssociativeArray" and current.available <> false
            if GetInterface(m.livePreviewStatus,"ifString") <> invalid
                if m.livePreviewStatus <> "" then status = m.livePreviewStatus
            end if
        end if
        words(status,307,960,622,38,22,"0xB4C3B9FF")
        selectable("live-actions",0,"Pantalla completa",952,811,358,66)
        favoriteText = "Añadir a favoritos"
        if rpLiveIsFavorite(current,m.liveFavorites) then favoriteText = "Quitar de favoritos"
        selectable("live-actions",1,favoriteText,952,892,358,66)
    else
        emptyTitle = "Tu televisión, a tu manera"
        empty = "Selecciona un filtro para explorar sus canales."
        if m.liveFilter = 3 then empty = "Guarda tus canales con * para encontrarlos aquí."
        if searchEmpty
            emptyTitle = "Sin resultados"
            empty = "No hay canales que coincidan. Cambia o borra tu búsqueda."
        end if
        words(emptyTitle,303,813,1005,75,37)
        words(empty,307,906,1000,85,25,"0xC6CEC7FF").wrap = true
    end if

    first = (m.liveCursor \ 6)*6
    last = first+6
    if last > m.channels.count() then last = m.channels.count()
    if last > 0 then words((first+1).toStr()+"–"+last.toStr()+" de "+m.channels.count().toStr(),1585,169,287,31,20,"0xC7CFC9FF").horizAlign = "right"
    if last = 0 and searching then words("0 resultados",1585,169,287,31,20,"0xC7CFC9FF").horizAlign = "right"
    for i = 0 to 5
        n = first+i
        if n < m.channels.count()
            item = m.channels[n]
            y = 206+i*119
            surface = "live-channel-row"
            if n = m.liveCursor then surface = "live-channel-selected"
            glassSurface(surface,1342,y,540,111)
            liveChannelBadge(item,1359,y+17)
            ink = "0xF6F7F2FF"
            if item.available = false then ink = "0xBCC5BDFF"
            words(item.title,1483,y+12,343,64,25,ink).wrap = true
            status = liveChannelStatus(item)
            dot = "live-status-on"
            if item.available = false then dot = "live-status-off"
            art("pkg:/images/ui/"+dot+".png",1483,y+79,12,12)
            words(status,1504,y+79,328,27,19,"0xCCD5CCFF")
            star = "live-star-outline"
            if rpLiveIsFavorite(item,m.liveFavorites) then star = "live-star-filled"
            art("pkg:/images/ui/"+star+".png",1842,y+16,25,25)
            focusTarget("live",n,1336,y-6,552,123,"live-channel")
        end if
    end for
    if m.channels.count() > 6
        glassSurface("live-scroll-track",1892,213,8,694)
        pages = int((m.channels.count()+5)/6)
        thumb = int(694/pages)
        if thumb < 38 then thumb = 38
        page = first/6
        sy = 213+int((694-thumb)*page/(pages-1))
        glassSurface("live-scroll-thumb",1892,sy,8,thumb)
    end if
    if m.channels.count() = 0
        empty = "No hay canales disponibles."
        if m.busy then empty = "Cargando canales…"
        if m.liveFilter = 3 then empty = "Tus favoritos aparecerán aquí."
        if searchEmpty then empty = "No hay canales que coincidan. Cambia o borra tu búsqueda."
        panel(1342,206,540,235,"0x181818FF")
        words(empty,1380,278,464,109,29,"0xDCE1D9FF").wrap = true
    end if
    words(rpLivePopularityNote(),1351,944,525,66,18,"0xACB9AAFF").wrap = true
    words("↑ ↓  Cambiar canal     OK  Pantalla completa     *  Favorito",305,1025,1035,36,21,"0xDCE1D9FF")
    words("Atrás  Volver",1560,1025,316,36,21,"0xDCE1D9FF").horizAlign = "right"
end sub

sub settingsScreen()
    topBar()
    words("Configuración",72,142,1500,76,46,"0xFFFFFFFF")
    words("Puedes corregir tus elecciones cuando quieras.",76,218,1480,55,25,"0xB3B3B3FF")
    appearance = "Vidrio"
    if m.theme = "classic" then appearance = "Clásico"
    labels = ["Tu televisor","País o región","Catálogo HD","Créditos de cortos y documentales","Apariencia","Perfiles","Servidor de compatibilidad (PC)","Resolución detectada"]
    helperValue = m.compatBase
    if helperValue = "" then helperValue = "No configurado"
    displayValue = "No disponible"
    if type(m.capabilities.display) = "roAssociativeArray"
        display = m.capabilities.display
        if display.outputWidth > 0 and display.outputHeight > 0
            displayValue = display.outputWidth.toStr()+" × "+display.outputHeight.toStr()
        end if
        if display.videoMode <> "" then displayValue = displayValue+" · "+display.videoMode
        if display.uiName <> "" then displayValue = displayValue+" · interfaz "+display.uiName
    end if
    values = [modeName(),countryName(),hdProviderName(),"Ver fuentes y licencias",appearance,rpProfileName(m.profileId),helperValue,displayValue]
    for i = 0 to 7
        y = 270+i*84
        panel(72,y,1770,76,"0x181818FF")
        words(labels[i],104,y+10,1150,38,27,"0xFFFFFFFF")
        words(values[i],106,y+48,1450,25,19,"0xB3B3B3FF")
        focusTarget("settings",i,66,y-5,1782,86)
    end for
    words("La interfaz usa diseño FHD con escalado automático de Roku; la salida se detecta en este dispositivo.",323,990,1480,36,19,"0xB1BEB3FF")
end sub

sub profilesScreen()
    topBar()
    words("¿Quién está viendo?",72,142,1500,76,46,"0xFFFFFFFF")
    words("Cada perfil conserva su propio historial, Mi lista y progreso de reproducción en esta Roku.",76,218,1480,55,24,"0xB3B3B3FF").wrap = true
    ids = ["p1","p2","p3","p4"]
    names = []
    descriptions = ["Perfil principal de este dispositivo","Historial y favoritos independientes","Historial y favoritos independientes","Historial y favoritos independientes"]
    for each profileId in ids
        names.push(rpProfileName(profileId))
    end for
    for i = 0 to 3
        x = 72+(i mod 2)*900
        y = 320+(i \ 2)*260
        panel(x,y,850,214,"0x181818FF")
        avatarColors = ["0xE50914FF","0x2457A6FF","0x16845BFF","0x7B3FA1FF","0xB36A19FF","0x287E91FF"]
        avatarIndex = rpProfileAvatar(ids[i])
        panel(x+32,y+35,82,82,avatarColors[avatarIndex])
        avatar = words("P"+(i+1).toStr(),x+32,y+51,82,48,30,"0xFFFFFFFF")
        avatar.horizAlign = "center"
        words(names[i],x+132,y+36,540,55,35,"0xFFFFFFFF")
        words(descriptions[i],x+34,y+126,660,48,23,"0xB7C7BEFF").wrap = true
        ids = ["p1","p2","p3","p4"]
        if m.profileId = ids[i] then words("ACTIVO",x+565,y+36,130,35,19,"0xE50914FF").horizAlign = "right"
        focusTarget("profiles",i,x-6,y-6,862,226,"setup")
    end for
    words("Flechas: elegir · OK: activar · OPTIONS: cambiar nombre · PLAY/PAUSE: cambiar imagen · Atrás: volver",76,945,1740,54,20,"0x808080FF")
end sub

sub appearanceScreen()
    topBar()
    words("Apariencia",72,142,1500,76,46,"0xFFFFFFFF")
    words("Elige cómo quieres ver Roku Plus.",76,218,1480,55,25,"0xB3B3B3FF")
    names = ["Netflix","Clásico"]
    descriptions = ["Interfaz oscura con navegación horizontal, pósters y acentos rojos.","Presentación alternativa heredada de Roku Plus."]
    for i = 0 to 1
        x = 72+i*900
        panel(x,326,850,456,"0x181818FF")
        preview = "appearance-glass-preview"
        if i = 1 then preview = "appearance-classic-preview"
        art("pkg:/images/ui/"+preview+".png",x+26,354,798,235)
        words(names[i],x+30,615,640,60,39)
        words(descriptions[i],x+32,695,672,67,25,"0xD1DACFFF").wrap = true
        current = (i = 0 and m.theme <> "classic") or (i = 1 and m.theme = "classic")
        if current then words("Actual",x+555,627,145,36,22,"0xF4EDC8FF").horizAlign = "right"
        focusTarget("appearance",i,x-6,320,862,468,"appearance")
    end for
    words("← / →  Elegir     OK  Aplicar     Atrás  Volver",76,945,1480,54,22,"0x808080FF")
end sub

sub hdSourceScreen()
    topBar()
    words("Catálogo HD",72,142,1500,76,46,"0xFFFFFFFF")
    words("Elige la biblioteca que se utilizará en el modo HD / Full HD.",76,218,1480,55,25,"0xB3B3B3FF").wrap = true
    choices = hdProviderChoices()
    first = 0
    if m.hdSourceCursor >= 6 then first = m.hdSourceCursor-5
    for i = 0 to 5
        n = first+i
        if n < choices.count()
        name = hdProviderName(choices[n])
        description = "Películas y series · alternativas en español"
        if choices[n] = "all" then description = "Una búsqueda, varias opciones de la misma película o serie"
        if choices[n] = "lamovie" then description = "Películas y series · prioridad español latino"
        if choices[n] = "allcalidad" then description = "Películas y series · latino y dual"
        if choices[n] = "seriesmetro" then description = "Películas y series · servidores alternativos Fastream"
        if choices[n] = "cinecalidad" then description = "Películas en español latino · sin sección de series"
        if choices[n] = "open" then description = "Biblioteca pequeña de Blender y NASA"
        y = 300+i*106
        panel(72,y,1770,98,"0x181818FF")
        words(name,104,y+10,1350,41,28,"0xFFFFFFFF")
        words(description,106,y+56,1350,32,21,"0xB3B3B3FF")
        focusTarget("hd-source",n,66,y-5,1782,108)
        end if
    end for
    words("Las fuentes y los títulos disponibles pueden cambiar. Se comprueba el formato antes de reproducir.",76,957,1480,85,21,"0x808080FF").wrap = true
end sub

sub creditsScreen()
    topBar()
    words("Créditos de la biblioteca HD",72,142,1500,76,44,"0xFFFFFFFF")
    words(m.creditsPages[m.creditsPage],76,245,1760,710,24,"0xE5E5E5FF").wrap = true
    words("Página "+(m.creditsPage+1).toStr()+" / "+m.creditsPages.count().toStr()+" · ↑/↓: cambiar · Atrás: volver",76,1002,1500,40,20,"0x808080FF")
end sub

sub paintFocus()
    for each entry in m.focusItems
        chosen = false
        if entry.zone = m.zone
            if m.zone = "nav" then chosen = entry.index = m.nav
            if m.zone = "hero" then chosen = entry.index = m.hero
            if m.zone = "covers" then chosen = entry.index = m.cover
            if m.zone = "continue" then chosen = entry.index = m.cover
            if m.zone = "home-series" then chosen = entry.index = m.seriesCover
            if m.zone = "library" then chosen = entry.index = m.libraryCursor
            if m.zone = "profiles" then chosen = entry.index = m.profileCursor
            if m.zone = "grid" then chosen = entry.index = m.cursor
            if m.zone = "action" then chosen = entry.index = m.action
            if m.zone = "episodes" then chosen = entry.index = m.episode
            if m.zone = "seasons" then chosen = entry.index = m.season
            if m.zone = "live" then chosen = entry.index = m.liveCursor
            if m.zone = "live-filters" then chosen = entry.index = m.liveFilterCursor
            if m.zone = "live-search" then chosen = entry.index = m.liveSearchCursor
            if m.zone = "live-actions" then chosen = entry.index = m.liveAction
            if m.zone = "settings" then chosen = entry.index = m.settingsCursor
            if m.zone = "appearance" then chosen = entry.index = m.themeCursor
            if m.zone = "hd-source" then chosen = entry.index = m.hdSourceCursor
            if m.zone = "setup" then chosen = entry.index = m.setupTv
            if m.zone = "country" then chosen = entry.index = m.setupCountry
        end if
        entry.edge.visible = chosen
    end for
end sub
