local Class = {}
Class.__index = Class

function Class:extend()
    local NewClass = {}
    NewClass.__super = self

    -- First, copy over all metamethods directly. 
    -- These will not get recursively searched for, so they need to be in the class itself, for all instances to have access.
    for k, v in pairs(self) do
        if type(k) == "string" and k:find("^__") and type(v) == "function" then 
            NewClass[k] = v
        end
    end

    -- "When an instance of NewClass is missing something, check NewClass for it."
    NewClass.__index = NewClass
    
    -- "When NewClass itself is missing something, check the class we just extended for it."
    -- This is the line that lets NewClass inherit functions down the chain of metatables.
    return setmetatable(NewClass, {__index = self})
end

function Class:new(...)
    local instance = setmetatable({}, self)
    if instance.init and instance:init(...) == false then
        return nil
    end
    return instance
end

function Class:is_subclass_of(ancestor)
    local class = self

    while class do
        if class == ancestor then
            return true
        end
        class = rawget(class, "__super")
    end

    return false
end

function Class:is_instance_of(ancestor)
    local class = getmetatable(self)
    return class ~= nil and Class.is_subclass_of(class, ancestor)
end

return Class