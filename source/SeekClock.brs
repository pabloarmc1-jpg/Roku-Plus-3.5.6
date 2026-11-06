' RokuPlus transport arithmetic. These values are native media clock readings,
' not catalogue runtimes and not inferred byte offsets.
function plusClockValue(value as dynamic) as dynamic
    t = type(value)
    numeric = t = "Integer" or t = "LongInteger" or t = "Float" or t = "Double" or t = "roInt" or t = "roLongInteger" or t = "roFloat" or t = "roDouble"
    if not numeric then return invalid
    if value <> value then return invalid
    if value < 0 or value > 172800 then return invalid
    return value
end function

function plusShiftDestination(current as dynamic, nativeDuration as dynamic, backwards as boolean) as dynamic
    p = plusClockValue(current)
    if p = invalid then return invalid
    delta = 10.0
    if backwards then delta = -10.0
    result = p + delta
    if result < 0 then result = 0.0
    if result > 172800 then result = 172800.0
    d = plusClockValue(nativeDuration)
    if d <> invalid
        ' Ignore a stale duration shorter than the current native position.
        if d > 0 and p <= d
            lastPoint = d - 0.25
            if lastPoint < 0 then lastPoint = 0.0
            if result > lastPoint then result = lastPoint
            if not backwards and result < p then result = p
        end if
    end if
    return result
end function

function plusClockText(value as dynamic) as string
    p = plusClockValue(value)
    if p = invalid then return "--:--"
    whole = int(p)
    hh = whole \ 3600
    mm = (whole mod 3600) \ 60
    ss = whole mod 60
    minuteText = mm.toStr()
    secondText = ss.toStr()
    if ss < 10 then secondText = "0" + secondText
    if hh = 0 then return minuteText + ":" + secondText
    if mm < 10 then minuteText = "0" + minuteText
    return hh.toStr() + ":" + minuteText + ":" + secondText
end function
