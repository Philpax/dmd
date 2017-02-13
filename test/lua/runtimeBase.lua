function __rtDeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[__rtDeepCopy(orig_key)] = __rtDeepCopy(orig_value)
        end
        setmetatable(copy, __rtDeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
