---Container of `entity.component`
---@class entity
---@operator call(entity.component[]): entity
local entity = {}

entity.__index = entity
setmetatable(entity, {
    __call = function(self, components)
        local instance = setmetatable({}, self)
        for i = 1, #components do
            local comp = components[i]
            local mt = getmetatable(comp)
            if type(mt) ~= "table" then
                error("entity component must have metatable #"..i)
            end
            instance[mt] = comp
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
        instance.__index = instance
        instance._initializer = initializer
        return instance;
    end
})

function component:__call(...)
    return setmetatable(self._initializer(...), self)
end

return entity