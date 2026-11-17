local Class = require("LuaDS.Class")

local OrderedTable = Class:extend()

function OrderedTable:__newindex(key, value) -- removal not yet supported
    if type(value) == "function" then
        rawset(self, key, value)
    else
        local kv_pairs = rawget(self, "keyval_pairs")
        local kti = rawget(self, "key_to_index")
        local index = kti[key]
        if not index then
            index = #kv_pairs + 1
        end
        kv_pairs[index] = {key = key, value = value}
        kti[key] = index
    end
end

function OrderedTable:__index(key)
    local member = OrderedTable[key]
    if member then
        return member
    end

    local index = rawget(self, "key_to_index")[key]
    if not index then
        return nil
    end

    local keyval_pair = rawget(self, "keyval_pairs")[index]
    return keyval_pair.value
end

function OrderedTable:pairs()
    local kv_pairs = rawget(self, "keyval_pairs")
    local i = 0

    return function()
        i = i + 1
        local pair = kv_pairs[i]
        if pair then
            return pair.key, pair.value
        end
    end
end

-- for when you ONLY care about the actual values of the table, and don't want any function collision.
function OrderedTable:get(key)
    local index = rawget(self, "key_to_index")[key]
    return index and rawget(self, "keyval_pairs")[index].value
end

function OrderedTable:len()
    return #rawget(self, "key_to_index")
end

function OrderedTable:init(...)
    rawset(self, "keyval_pairs", {})
    rawset(self, "key_to_index", {})

    local args = {...}
    for i = 1, select("#", ...), 2 do
        self[args[i]] = args[i+1]
    end
end

return OrderedTable