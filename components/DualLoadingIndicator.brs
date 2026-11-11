sub init()
    m.label = m.top.findNode("loadingLabel")
    m.top.observeField("message", "messageChanged")
    messageChanged()
end sub

sub messageChanged()
    m.label.text = m.top.message
end sub
