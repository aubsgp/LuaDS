local function Error(...)
    error(debug.traceback(string.format(...), 2))
end

return Error