-- Parent class used to create classes that reflect game structs.
-- Basic anatomy: you extend this class to create a class for all mirrors of a given struct, e.g. a Pokemon class, or a Billboard class.
-- The extension has a static "dictionary" of addresses and sizes corresponding to each variable of the given class. These variables might also be Mirror classes.
-- When you instantiate the class, you pass in the raw data of the ingame struct from RAM. That is used to generate a Data instance corresponding to the given game instance we're mirroring.
-- The static dict serves as the blueprint for how we access and modify the mirror's variables. 
-- Ideally, we should be able to auto-generate the dict from a copy/paste of the class's definition, maybe via a python script? I'll think about it.

local Error = require("LuaDS.Error")
local Class = require("LuaDS.Class")
local OrderedTable = require("LuaDS.OrderedTable")
local Array = require("LuaDS.Array")
local Data = require("LuaDS.Data")

local Mirror = Class:extend()

function Mirror:write_to_memory(addr)
    if not addr then
        if not self.node then
            Error("Attempt to write to memory without an address.")
        end

        addr = self.node:get_address()
        if not addr then
            return false
        end
    end

    self.data:write_to_memory(addr)
    return true
end

-- JSON-formatted string containing all accessible fields of the class. Minified by default.
function Mirror:to_JSON(indentation)
    local newline = (indentation and "\n") or ""
    local space = (indentation and " ") or ""
    local indent = indentation and string.rep("    ", indentation) or ""
    local more_indented = indentation and indent .. "    " or ""
    indentation = indentation and indentation + 1

    local printed = {}

    local lines = {}
    for k, v in self.address_dict:pairs() do
        local start_offset = v[1]
        local end_offset = (type(v[2]) == "number" and v[2]) or entry_size(v[2])
        local printed = true
        for i = start_offset, end_offset do
            if not printed[i] then
                printed = false
            end
        end
        
        if not printed then
            local line = more_indented .. "\"" .. k .. "\":" .. space
            local v = self[k]
            if type(v) == "table" then
                if v.to_JSON then
                    line = line .. newline .. v:to_JSON(indentation)
                else
                    line = nil
                end
            elseif type(v) == "number" then
                line = line .. self[k]
            else -- Don't know how we'd reach this, but might as well.
                line = nil
            end

            if line then
                for i = start_offset, end_offset do
                    printed[i] = true
                end
                table.insert(lines, line)
            end
        end
    end
    return indent .. "{" .. newline .. table.concat(lines, "," .. newline) .. newline .. indent .. "}"
end

local function entry_size(entry_type)
    local ret = entry_type
    if type(entry_type) == "table" then
        if entry_type[1] and entry_type:is_subclass_of(Array) then
            ret = entry_type[2] * entry_type[3]
        else
            ret = entry_type.SIZE
        end
    end
    return ret
end

function Mirror:extend(ordered_dict)
    local NewClass = Class.extend(self)

    if not ordered_dict or not ordered_dict:is_instance_of(OrderedTable) then
        Error("Attempted to create mirror class without associated ordered address dictionary.")
    end

    local merged = OrderedTable:new()
    if self.address_dict then
        for k, v in self.address_dict:pairs() do
            merged[k] = v
        end
    end
    for k, v in ordered_dict:pairs() do
        merged[k] = v
    end
    NewClass.address_dict = merged

    local size = 0
    for _, v in NewClass.address_dict:pairs() do
        size = math.max(size, v[1] + entry_size(v[2]])
    end
    NewClass.SIZE = size

    function NewClass:__index(key)
        local var_data = NewClass.address_dict:get(key)
        if var_data then
            if not self.data then
                Error("Attempted to index data field that is not yet instantiated.")
            end
            local address = var_data[1]
            local var_type = var_data[2]

            if type(var_type) == "table" then
                return self.object_dict[key]
            elseif type(var_type) == "number" then
                if var_type == 0 then
                    return self.data:readbits(address, var_data[3], var_data[3] + var_data[4])
                else
                    return self.data:read(address, var_type)
                end
            end
        else
            return NewClass[key]
        end
    end

    function NewClass:__newindex(key, val)
        local var_data = NewClass.address_dict:get(key)
        if var_data then
            if not self.data then
                Error("Attempted to newindex data field that is not yet instantiated.")
            end
            local address = var_data[1]
            local var_type = var_data[2]

            if type(var_type) == "table" then
                self.data:writebyterange(address, val.data:readbyterange(0, self["key"].SIZE))
            elseif type(var_type) == "number" then
                if var_type == 0 then -- Target specific bits. Which bits is determined by var_data[3] and var_data[4].
                    self.data:writebits(address, var_data[3], var_data[3] + var_data[4], val)
                else
                    self.data:write(address, var_type, val)
                end
            end
        else
            rawset(self, key, val)
        end
    end

    function NewClass:init(data)
        if not data or getmetatable(data) ~= Data then
            Error("Attempted to instantiate mirror class without a data table.")
        end
        self.data = data
        self.object_dict = {}
        for k, v in NewClass.address_dict:pairs() do
            local address = v[1]
            local var_type = v[2]

            if type(var_type) == "table" then
                local obj_data = self.data:slice(address, address + var_type.SIZE)
                if if var_type[1] and var_type[1]:is_subclass_of(Array) then
                    self.object_dict[k] = var_type:new(var_type[2], var_type[3], obj_data)
                else
                    self.object_dict[k] = var_type:new(obj_data)
                end
            end
        end
    end

    function NewClass:offset_of(var) -- for readability.
        return self.address_dict:get(var)[1]
    end

    function NewClass:update(addr)
        if not addr then 
            if not self.node then
                Error("Cannot update without an address.")
            end

            addr = self.node:get_address()
            if not addr then
                return false
            end
        end

        -- Copy the data rather than copying the reference to preserve links to sub-data of class fields.
        local new_raw = memory.readbyterange(addr, self.SIZE)
        if new_raw then
            self.data:writebyterange(0, new_raw)
        end
    end

    function NewClass:from_node(mem_node)
        local addr = mem_node:get_address()
        if not addr then
            return false
        end
        local instance = NewClass:new(Data:new(memory.readbyterange(addr, self.SIZE)))
        instance.node = mem_node
        return instance
    end

    function NewClass:from_addr(addr)
        local instance = NewClass:new(Data:new(memory.readbyterange(addr, self.SIZE)))
        return instance
    end

    local reserved = {
        data = true,
        node = true,
        object_dict = true,
        address_dict = true,
        SIZE = true,
    }
    for k, _ in ordered_dict:pairs() do
        assert(not reserved[k] and NewClass[k] == nil, "reserved field name: " .. k)
    end

    return NewClass
end

return Mirror