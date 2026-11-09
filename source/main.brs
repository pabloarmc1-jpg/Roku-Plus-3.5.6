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
    display.createScene("PlusScene")
    display.show()
    while true
        event = wait(0, messages)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        end if
    end while
end sub

