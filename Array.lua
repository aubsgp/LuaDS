-- Allows defining of arbitrary array types. 
-- Idea: Array:extend(n, m) is a class corresponding to and array of n entries, where each entry is m bytes long.
-- Then, Array:extend(n, m):new() creates an array that is n * m bytes long, split in to m-byte entries.

local Class = require("LuaDS.Class")
local Data = require("LuaDS.Data")
local Error = require("LuaDS.Error")

local Array = Class:extend()

local function entry_size(entry)
    local ret = entry[1]
    if type(entry[1]) == "table" then
        if entry[1]:is_subclass_of(Array) then
            ret = entry[2] * entry_size(entry[3])
        else
            ret = entry[1].SIZE
        end
    end
    return ret
end

function Array:init(length, entry_type, data)
    self.length = length
    self.entry_type = entry_type
    self.entry_size = entry_size(entry_type)
    self.SIZE = self.length * self.entry_size

    if not data then
        local t = {}
        for i = 1, arr.SIZE do
            t[i] = 0
        end
        data = Data:(t)
    end

    if not data:is_instance_of(Data) then
        Error("Attempted to instantiate Array class without a data table.")
    end

    if type(self.entry_type) ~= "number" then
        if not self.entry_type.is_subclass_of then
            Error("Faulty data type for Array: neither number nor class.")
        end
        self.object_table = {}
        for i in 0, self.length - 1 do
            local obj_data = Data:slice(i * self.entry_size, (i + 1) * self.entry_size)
            if self.entry_type[1] and self.entry_type[1]:is_subclass_of(Array) then
                self.object_table[i] = self.entry_type[1]:new(self.entry_type[2], self.entry_type[3], obj_data)
            else
                self.object_table[i] = self.entry_type:new(obj_data)
            end
        end
    end

    rawset(self, "data", data)
end

function Array:__index(key)
    if not key or (type(key) == "number" and (key >= length or key < 0 or key % 1 ~= 0)) then
        Error("Invalid index for Array: %s", tostring(key))
    end

    if type(key) == "number" then
        if type(self.entry_type) == "number" then
            return self.data:read(key * self.entry_size, self.entry_size)
        else
            return self.object_table[key]
        end
    else
        return Array[key]
    end
end

function Array:__newindex(key, val)
    if not key or (type(key) == "number" and (key >= length or key < 0 or key % 1 ~= 0)) then
        Error("Invalid index for Array: %s", tostring(key))
    end
    if not val or (type(key) == "number" and type(val) ~= "number") then
        Error("invalid entry for Array: %s", tostring(val))
    end

    if type(key) == "number" then
        if type(self.entry_type) == "number" then
            self.data:write(key * self.entry_size, self.entry_size, val)
        else
            self.data:writebyterange(key * self.entry_size, self.entry_size, val.data:readbyterange(0, self.entry_size))
        end
    else
        rawset(self, key, val)
    end
end

function Array:to_JSON(indentation) -- JSON-formatted string listing each element. Minified by default.
    local newline = (indentation and "\n") or ""
    local indent = indentation and string.rep("    ", indentation) or ""
    local more_indented = indentation and indent .. "    " or ""
    indentation = indentation and indentation + 1

    local lines = {}
    if type(self.entry_type) == "number" then
        for i = 0, self.length - 1 do
            table.insert(lines, more_indented .. self[i])
        end
        
    else if self.object_table[0].to_JSON then
        for i = 0, self.length - 1 do
            table.insert(lines, self.object_table[i]:to_JSON(indentation))
        end
    end

    return indent .. "[" .. newline .. table.concat(lines, "," .. newline) .. newline .. indent .. "]"
end

return Array
