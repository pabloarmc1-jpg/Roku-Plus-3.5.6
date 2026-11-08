sub init()
    m.top.functionName = "runLocalHlsProbe"
end sub

sub runLocalHlsProbe()
    m.top.status = "running"
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.setMessagePort(port)
    transfer.setUrl(m.top.url)
    if not transfer.asyncGetToString()
        m.top.responseCode = -998
        m.top.failureReason = "async_get_not_started"
        m.top.status = "complete"
        print "[RokuPlus local-hls-probe] request_start_failed"
        return
    end if
    event = wait(6000, port)
    if type(event) = "roUrlEvent"
        if event.getInt() = 1
            m.top.responseCode = event.getResponseCode()
            body = event.getString()
            if GetInterface(body, "ifString") <> invalid then m.top.bodyLength = len(body)
            m.top.failureReason = event.getFailureReason()
            m.top.status = "complete"
            print "[RokuPlus local-hls-probe] completed code="; m.top.responseCode; " bytes="; m.top.bodyLength; " target="; event.getTargetIpAddress()
            return
        end if
    end if
    m.top.responseCode = -997
    m.top.failureReason = "probe_timeout_or_invalid_event"
    m.top.status = "timeout"
    print "[RokuPlus local-hls-probe] timeout_or_invalid_event"
end sub
