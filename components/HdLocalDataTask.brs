' Load packaged local HD data away from the SceneGraph Render thread.
sub init()
    m.top.functionName = "loadHdLocalData"
end sub

sub loadHdLocalData()
    library = rpHdLibrary()
    m.top.result = {
        library: library
    }
end sub
