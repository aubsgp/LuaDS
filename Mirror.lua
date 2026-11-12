-- Parent class used to create classes that reflect game structs.
-- Basic anatomy: you extend this class to create a class for all mirrors of a given struct, e.g. a Pokemon class, or a Billboard class.
-- The extension has a static "dictionary" of addresses and sizes corresponding to each variable of the given class. These variables might also be Mirror classes.
-- When you instantiate the class, you pass in the raw data of the ingame struct from RAM. That is used to generate a Data instance corresponding to the given game instance we're mirroring.
-- The static dict serves as the blueprint for how we access and modify the mirror's variables. 
-- Ideally, we should be able to auto-generate the dict from a copy/paste of the class's definition, maybe via a python script? I'll think about it.

local here = (...):match("(.-)[^%.]+$")
local Error = require(here .. "Error")
local Class = require(here .. "Class")
local Data = require(here .. "Data")

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

function Mirror:extend(dict)
    local NewClass = Class.extend(self)

    if not dict then
        Error("Attempted to create mirror class without associated address dictionary.")
    end

    local merged = {}
    if self.address_dict then
        for k, v in pairs(self.address_dict) do
            merged[k] = v
        end
    end
    for k, v in pairs(dict) do
        merged[k] = v
    end

    NewClass.address_dict = merged

    local size = 0
    for k, v in pairs(NewClass.address_dict) do
        size = math.max(size, v[1] + (type(v[2]) == "table" and v[2].SIZE or v[2]))
    end
    NewClass.SIZE = size

    function NewClass:__index(key)
        local var_data = NewClass.address_dict[key]
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
        local var_data = NewClass.address_dict[key]
        if var_data then
            if not self.data then
                Error("Attempted to newindex data field that is not yet instantiated.")
            end
            local address = var_data[1]
            local var_type = var_data[2]

            if type(var_type) == "table" then
                self.data:writebyterange(address, val.data:readbyterange(0, var_type.SIZE))
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
        for k, v in pairs(NewClass.address_dict) do
            local address = v[1]
            local var_type = v[2]

            if type(var_type) == "table" then
                self.object_dict[k] = var_type:new(self.data:slice(address, address + var_type.SIZE))
            end
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

    local reserved = {
        data = true,
        node = true,
        object_dict = true,
        address_dict = true,
        SIZE = true,
    }
    for k in pairs(dict) do
        assert(not reserved[k] and NewClass[k] == nil, "reserved field name: " .. k)
    end

    return NewClass
end

return Mirror