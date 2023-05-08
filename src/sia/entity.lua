---@class entity
---@operator call(entity.component[]): entity
local entity = {}

entity.__index = entity
setmetatable(entity, {
    __call = function(_, components)
        local instance = setmetatable({}, entity)
        for i = 1, #components do
            local comp = components[i]
            local meta = comp.__sia_component_meta
            if meta ~= nil then
                instance[meta.key] = comp

                local iter_subcomps = meta.iter_subcomponents
                if iter_subcomps then
                    for subcomp_key, subcomp in iter_subcomps(comp) do
                        instance[subcomp_key] = subcomp
                    end
                end
            else
                instance[getmetatable(comp)] = comp
            end
        end
        return instance
    end
})

function entity:add_state(component)
    self[getmetatable(component)] = component
end

---@class entity.component
---@field package _initializer fun(...): table
---@field [string] any
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
---@field component_key entity.component
---@operator call(...): entity.component.command
local command = {
    __call = function(self, component_key, ...)
        self[1](component_key, ...)
    end
}
entity.command = command

setmetatable(command, {
    __call = function(_, component_key, handler)
        return setmetatable({handler, component_key = component_key}, command)
    end
})

---@param command_name string
---@param handler fun(component: entity.component, ...) | nil
---@return entity.component
function component:on(command_name, handler)
    self[command_name] = command(self, handler)
    return self
end

function component:__call(...)
    return setmetatable(self._initializer(...), self)
end

return entity