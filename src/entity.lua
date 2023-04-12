---Container of `entity.component`
---@class entity
---@field [table] entity.component
---@operator call(entity.component[]): entity
local entity = {}

---@param component table
---@return table
local function get_component_meta(component, i)
    local mt = getmetatable(component)
    if type(mt) == "table" then
        return mt
    else
        error("entity component must have metatable #"..i)
    end
end

entity.__index = entity
setmetatable(entity, {
    __call = function(self, components)
        local instance = setmetatable({}, self)
        for i, component in ipairs(components) do
            instance[get_component_meta(component, i)] = component
        end
        return instance
    end
})

---Pure data stored in `entity`
---@class entity.component
---@field private _initializer fun(...): table
---@operator call(fun(...): table): entity.component
local component = {}
entity.component = component

component.__index = component
setmetatable(component, {
    __call = function(self, initializer)
        local instance = setmetatable({}, self)
        instance._initializer = initializer
        return instance;
    end
})

function component:__call(...)
    return setmetatable(self._initializer(...), self)
end

return entity