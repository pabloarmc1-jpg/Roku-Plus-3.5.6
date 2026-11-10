' Load packaged local HD data away from the SceneGraph Render thread.
sub init()
    m.top.functionName = "loadHdLocalData"
end sub

sub loadHdLocalData()
    library = rpHdLibrary()
    creditsText = ReadAsciiFile("pkg:/CREDITS-HD.txt")
    m.top.result = {
        library: library
        creditsText: creditsText
    }
end sub
