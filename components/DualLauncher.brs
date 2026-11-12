' Selector y anfitrión de Playlet. La escena raíz del canal sigue siendo PlusScene.
sub init()
    m.top.focusable = true
    m.menu = m.top.findNode("menu")
    m.playletContainer = m.top.findNode("playletContainer")
    m.countdownLabel = m.top.findNode("countdown")
    m.errorLabel = m.top.findNode("error")
    m.loadingIndicator = m.top.findNode("PlayletLoadingIndicator")
    m.global.addFields({ loadingIndicator: m.loadingIndicator })
    m.playletCard = m.top.findNode("playletCard")
    m.plusCard = m.top.findNode("plusCard")
    m.timer = m.top.findNode("countdownTimer")
    m.timer.observeField("fire", "countdownTick")
    m.selection = 0
    if savedChoice() = "rokuplus" then m.selection = 1
    m.remaining = 10
    m.launching = false
    m.lib = invalid
    m.playletNode = invalid
    m.scene = m.top.getScene()
    m.plusExperience = m.scene.findNode("PlusExperience")
    updateSelection()
    m.timer.control = "start"
    m.top.setFocus(true)
end sub

function savedChoice() as string
    section = CreateObject("roRegistrySection", "RokuPlusLauncher")
    value = section.Read("lastApp")
    if value = "playlet" then return value
    return "rokuplus"
end function

sub saveChoice(value as string)
    section = CreateObject("roRegistrySection", "RokuPlusLauncher")
    section.Write("lastApp", value)
    section.Flush()
end sub

sub updateSelection()
    if m.selection = 0
        m.playletCard.color = "0xE62117FF"
        m.plusCard.color = "0x242B38FF"
    else
        m.playletCard.color = "0x242B38FF"
        m.plusCard.color = "0xE62117FF"
    end if
end sub

sub countdownTick()
    if m.launching then return
    m.remaining = m.remaining - 1
    if m.remaining <= 0
        m.timer.control = "stop"
        launchSelected()
    else
        m.countdownLabel.text = "Abriendo tu última aplicación en " + m.remaining.toStr() + " segundos..."
    end if
end sub

sub ShowMenu()
    m.top.focusable = true
    m.launching = false
    m.remaining = 10
    m.selection = 0
    if savedChoice() = "playlet" then m.selection = 0 else m.selection = 1
    m.errorLabel.text = ""
    m.menu.visible = true
    m.playletContainer.visible = false
    m.countdownLabel.text = "Abriendo tu última aplicación en 10 segundos..."
    updateSelection()
    m.timer.control = "start"
    m.top.setFocus(true)
end sub

sub launchSelected()
    if m.launching then return
    m.launching = true
    m.timer.control = "stop"
    ' Release selector focus so the selected experience receives remote keys.
    m.top.focusable = false
    m.top.setFocus(false)
    if m.selection = 1
        saveChoice("rokuplus")
        m.top.launchRequest = "rokuplus"
        m.menu.visible = false
        m.playletContainer.visible = false
        m.plusExperience.visible = true
        m.scene.callFunc("ActivatePlusExperience")
        return
    end if

    saveChoice("playlet")
    m.top.launchRequest = "playlet"
    m.menu.visible = false
    ' Stop Roku Plus timers and background catalog work before Playlet loads.
    m.scene.callFunc("DeactivatePlusExperience")
    m.plusExperience.visible = false
    m.playletContainer.visible = true
    if m.playletNode <> invalid
        m.playletNode.setFocus(true)
        return
    end if
    if m.lib <> invalid and m.lib.loadStatus = "ready"
        createPlayletScene()
        return
    end if
    m.errorLabel.text = "Cargando Playlet..."
    m.loadingIndicator.message = "Cargando Playlet..."
    m.loadingIndicator.visible = true
    m.lib = m.scene.createChild("ComponentLibrary")
    m.lib.observeField("loadStatus", "playletLibraryStatus")
    m.lib.uri = "https://github.com/iBicha/playlet/releases/download/v0.48.10/playlet-lib.zip"
end sub

sub createPlayletScene()
    m.scene.playletLibLoadedUrl = { type: "github-zip", link: "https://github.com/iBicha/playlet/releases/download/v0.48.10/playlet-lib.zip" }
    ' Playlet's standalone bootstrap normally creates this optional startup log file.
    ' When embedded as a ComponentLibrary, that bootstrap is skipped; create an empty file
    ' before Logger starts so its ReadAsciiFile call does not report a missing-file error.
    WriteAsciiFile("cachefs:/playlet_startup_logs.txt", "")
    container = m.top.findNode("MainSceneContainer")
    m.playletNode = container.createChild("PlayletLib:MainScene")
    ' Playlet is authored for Roku HD (1280x720), while this channel uses FHD (1920x1080).
    ' Scale only Playlet so its full interface fills the FHD scene; Roku Plus remains unchanged.
    m.playletNode.scaleRotateCenter = [0, 0]
    m.playletNode.scale = [1.5, 1.5]
    m.scene.playletReady = true
    m.errorLabel.text = ""
    m.loadingIndicator.visible = false
    m.playletNode.setFocus(true)
end sub

sub playletLibraryStatus(event as object)
    if m.lib = invalid then return
    status = m.lib.loadStatus
    if status = "ready"
        createPlayletScene()
    else if status = "failed"
        m.loadingIndicator.visible = false
        m.errorLabel.text = "Playlet no pudo cargarse. Pulsa OK para volver al selector o elige Roku Plus."
        m.menu.visible = true
        m.playletContainer.visible = false
        m.plusExperience.visible = false
        m.launching = false
        saveChoice("rokuplus")
        m.selection = 1
        updateSelection()
        if m.lib <> invalid
            m.lib.unobserveField("loadStatus")
            m.scene.removeChild(m.lib)
            m.lib = invalid
        end if
        m.top.setFocus(true)
    end if
end sub

sub HandlePlayletExit()
    ' Return from Playlet to the app selector without closing the channel.
    m.scene.playletReady = false
    if m.playletNode <> invalid
        m.playletNode.setFocus(false)
        m.top.findNode("MainSceneContainer").removeChild(m.playletNode)
        m.playletNode = invalid
    end if
    m.playletContainer.visible = false
    m.loadingIndicator.visible = false
    m.plusExperience.visible = false
    m.scene.callFunc("DeactivatePlusExperience")
    ShowMenu()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return true
    if m.launching and m.playletContainer.visible then return false
    if key = "up" or key = "down"
        m.timer.control = "stop"
        m.remaining = 0
        if m.selection = 0 then m.selection = 1 else m.selection = 0
        updateSelection()
        return true
    end if
    if key = "OK"
        m.timer.control = "stop"
        launchSelected()
        return true
    end if
    if key = "options" or key = "*"
        if m.selection = 0
            saveChoice("playlet")
            m.countdownLabel.text = "Playlet quedó como aplicación predeterminada."
        else
            saveChoice("rokuplus")
            m.countdownLabel.text = "Roku Plus quedó como aplicación predeterminada."
        end if
        m.timer.control = "stop"
        return true
    end if
    ' Cualquier tecla cancela el arranque automático, sin impedir la navegación.
    m.timer.control = "stop"
    m.remaining = 0
    m.countdownLabel.text = "Inicio automático cancelado. Selecciona una aplicación."
    return true
end function
