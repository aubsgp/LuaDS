local Class = {}
Class.__index = Class

function Class:extend()
    local NewClass = {}

    -- First, copy over all metamethods.
    for k, v in pairs(self) do
        if type(k) == "string" and k:find("^__") then 
            NewClass[k] = v
        end
    end

    NewClass.__index = NewClass
    
    return setmetatable(NewClass, {__index = self})
end

function Class:new(...)
    local instance = setmetatable({}, self)
    if instance.init and instance:init(...) == false then
        return nil
    end
    return instance
end

return Class