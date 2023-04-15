---Container of `entity.component`
---@class entity
---@operator call(entity.component[]): entity
local entity = {}

entity.__index = entity
setmetatable(entity, {
    __call = function(_, components)
        local instance = setmetatable({}, entity)
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
---@field package _initializer fun(...): table
---@operator call(fun(...): table): entity.component
local component = {}
entity.component = component

component.__index = component
setmetatable(component, {
    __call = function(_, initializer)
        local instance = setmetatable({}, component)
        instance.__index = instance
        instance._initializer = initializer
        return instance;
    end
})

---@class entity.component.command
---@field component entity.component
---@operator call(...): any
local command = {
    __call = function(self, component, ...)
        self[1](component, ...)
    end
}

---@param command_name string
---@param handler fun(component: entity.component, ...) | nil
function component:on(command_name, handler)
    self[command_name] = setmetatable({handler, component = self}, command)
end

function component:__call(...)
    return setmetatable(self._initializer(...), self)
end

return entity