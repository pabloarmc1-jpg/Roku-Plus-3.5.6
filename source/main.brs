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
    memoryMonitor = CreateObject("roAppMemoryMonitor")
    deviceInfo = invalid
    memoryAlertsEnabled = false
    if memoryMonitor <> invalid
        memoryMonitor.setMessagePort(messages)
        memoryAlertsEnabled = memoryMonitor.EnableMemoryWarningEvent(true)
    end if
    if memoryAlertsEnabled
        print "[RokuPlus memory] monitor=app-thresholds enabled=true"
        print "[RokuPlus memory] usagePercent="; memoryMonitor.GetMemoryLimitPercent()
    else
        deviceInfo = CreateObject("roDeviceInfo")
        if deviceInfo <> invalid
            deviceInfo.setMessagePort(messages)
            fallbackEnabled = deviceInfo.enableLowGeneralMemoryEvent(true)
            print "[RokuPlus memory] monitor=general-level enabled="; fallbackEnabled
            print "[RokuPlus memory] generalLevel="; deviceInfo.GetGeneralMemoryLevel()
        else
            print "[RokuPlus memory] monitor=unavailable"
        end if
    end if

    display.createScene("PlusScene")
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
        end if
    end while
end sub

