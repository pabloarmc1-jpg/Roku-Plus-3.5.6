sub Main(args as dynamic)
    exitReason = "not-provided"
    if type(args) = "roAssociativeArray"
        if args.doesExist("lastExitOrTerminationReason")
            exitReason = args.lastExitOrTerminationReason
        end if
    end if
    print "[RokuPlus startup] lastExitOrTerminationReason="; exitReason

    display = CreateObject("roSGScreen")
    messages = CreateObject("roMessagePort")
    display.setMessagePort(messages)

    ' Observe app memory pressure without changing playback or UI behavior.
    deviceInfo = CreateObject("roDeviceInfo")
    osVersionInfo = deviceInfo.GetOSVersion()
    osMajor = 0
    osMinor = 0
    if type(osVersionInfo) = "roAssociativeArray"
        osMajor = val(osVersionInfo.major)
        osMinor = val(osVersionInfo.minor)
    end if
    print "[RokuPlus system] Roku OS="; osMajor; "."; osMinor

    ' Read Roku's native record for the previous app termination.
    ' This is diagnostic only: it does not change playback or app behavior.
    if osMajor >= 13
        appManager = CreateObject("roAppManager")
        if appManager <> invalid
            lastExitInfo = appManager.GetLastExitInfo()
            if lastExitInfo <> invalid and type(lastExitInfo) = "roAssociativeArray"
                ' GetLastExitInfo returns an associative array; read its keys
                ' as fields rather than calling a Lookup method.
                print "[RokuPlus exit-diagnostic] timestamp="; lastExitInfo.timestamp
                print "[RokuPlus exit-diagnostic] exit_code="; lastExitInfo.exit_code
                print "[RokuPlus exit-diagnostic] app_state="; lastExitInfo.app_state
                print "[RokuPlus exit-diagnostic] media_player_state="; lastExitInfo.media_player_state
                if lastExitInfo.mem_limit <> invalid
                    print "[RokuPlus exit-diagnostic] mem_limit_mb="; lastExitInfo.mem_limit
                else
                    print "[RokuPlus exit-diagnostic] mem_limit_mb=not-reported"
                end if
            else
                print "[RokuPlus exit-diagnostic] no-record-available"
            end if
        else
            print "[RokuPlus exit-diagnostic] app-manager-unavailable"
        end if
    else
        print "[RokuPlus exit-diagnostic] requires-roku-os-13-or-newer"
    end if

    memoryMonitor = invalid
    memoryAlertsEnabled = false
    ' EnableMemoryWarningEvent/GetMemoryLimitPercent require Roku OS 15.2+.
    if osMajor > 15 or (osMajor = 15 and osMinor >= 2)
        memoryMonitor = CreateObject("roAppMemoryMonitor")
        if memoryMonitor <> invalid
            memoryMonitor.setMessagePort(messages)
            memoryAlertsEnabled = memoryMonitor.EnableMemoryWarningEvent(true)
        end if
    end if
    if memoryAlertsEnabled
        print "[RokuPlus memory] monitor=app-thresholds enabled=true"
        print "[RokuPlus memory] usagePercent="; memoryMonitor.GetMemoryLimitPercent()
    else
        deviceInfo.setMessagePort(messages)
        fallbackEnabled = deviceInfo.enableLowGeneralMemoryEvent(true)
        print "[RokuPlus memory] monitor=general-level enabled="; fallbackEnabled
        print "[RokuPlus memory] generalLevel="; deviceInfo.GetGeneralMemoryLevel()
    end if

    scene = display.createScene("PlusScene")
    if type(args) = "roAssociativeArray"
        scene.launchArgs = args
    else
        scene.launchArgs = {}
    end if
    input = CreateObject("roInput")
    input.setMessagePort(messages)
    display.show()
    while true
        event = wait(0, messages)
        eventType = type(event)
        if eventType = "roSGScreenEvent"
            if event.isScreenClosed() then return
        else if eventType = "roAppMemoryNotificationEvent"
            memoryInfo = event.getInfo()
            if type(memoryInfo) = "roAssociativeArray"
                print "[RokuPlus memory] appWarning usagePercent="; memoryInfo.lookup("MemoryUsagePercent")
            else
                print "[RokuPlus memory] appWarning infoUnavailable"
            end if
        else if eventType = "roDeviceInfoEvent"
            memoryInfo = event.getInfo()
            if type(memoryInfo) = "roAssociativeArray"
                memoryLevel = memoryInfo.lookup("generalMemoryLevel")
                print "[RokuPlus memory] generalWarning level="; memoryLevel
            end if
        else if eventType = "roInputEvent"
            info = event.getInfo()
            scene.inputArgs = info
        end if
    end while
end sub

