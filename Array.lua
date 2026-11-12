-- Allows defining of arbitrary array types. 
-- Idea: Array:extend(n, m) is a class corresponding to and array of n entries, where each entry is m bytes long.
-- Then, Array:extend(n, m):new() creates an array that is n * m bytes long, split in to m-byte entries.

local here = (...):match("(.-)[^%.]+$")
local Class = require(here .. "Class")
local Data = require(here .. "Data")
local Error = require(here .. "Error")

local Array = Class:extend()

function Array:extend(length, entry_size)
    local arr = Class.extend(self)
    arr.SIZE = length * entry_size
    arr.length = length
    arr.entry_size = entry_size

    function arr:init(data)
        if not data then
            local t = {}
            for i = 1, arr.SIZE do
                t[i] = 0
            end
            data = Data:new(t)
        end 
        if getmetatable(data) ~= Data then
            Error("Attempted to instantiate Array class without a data table.")
        end
        rawset(self, "data", data)
    end

    function arr:__index(key)
        if not key or (type(key) == "number" and (key >= length or key < 0 or key % 1 ~= 0)) then
            Error("Invalid index for Array: %s", tostring(key))
        end
        if type(key) == "number" then
            return self.data:read(key * entry_size, entry_size)
        else
            return arr[key]
        end
    end

    function arr:__newindex(key, val)
        if not key or (type(key) == "number" and (key >= length or key < 0 or key % 1 ~= 0)) then
            Error("Invalid index for Array: %s", tostring(key))
        end
        if not val or (type(key) == "number" and type(val) ~= "number") then
            Error("invalid entry for Array: %s", tostring(val))
        end
        if type(key) == "number" then
            self.data:write(key * entry_size, entry_size, val)
        else
            rawset(self, key, val)
        end
    end

    return arr
end

return Array
