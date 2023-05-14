local group = require("sia.group")
local dispatcher = require("sia.dispatcher")

---@class sia.world: sia.group
---@field package _groups sia.world.group[]
---@field dispatcher sia.dispatcher
---@overload fun(dispatcher?: sia.dispatcher): sia.world
local world = {}

---@class sia.world.group: sia.group
---@field world sia.world
---@field index integer
---@field predicate? fun(entity: sia.entity): any

world.__index = world
setmetatable(world, {
    __index = group,
    __call = function(_, custom_dispatcher)
        local instance = setmetatable(group(), world)
        instance.dispatcher = custom_dispatcher or dispatcher()
        instance._groups = {}
        return instance
    end
})

---@param predicate? fun(entity: sia.entity): any
---@return sia.world.group
function world:create_group(predicate)
    local g = group() --[[@as sia.world.group]]
    g.world = self
    g.predicate = predicate

    local groups = self._groups
    local index = #groups + 1

    groups[index] = g
    g.index = index

    if predicate == nil then
        for i = 1, #self do
            g:add(self[i])
        end
    else
        for i = 1, #self do
            local e = self[i]
            if predicate(e) then
                g:add(e)
            end
        end
    end

    return g
end

---@param group sia.world.group
---@return boolean
function world:remove_group(group)
    if group.world ~= self then
        return false
    end

    local groups = self._groups
    local index = group.index

    if groups[index] ~= group then
        return false
    end

    local last_group = groups[#groups]
    last_group.index = index

    groups[#groups] = nil
    groups[index] = last_group

    return true
end

function world:add(entity)
    if not group.add(self, entity) then
        return false
    end

    local groups = self._groups

    for i = 1, #groups do
        local g = groups[i]
        local pred = g.predicate

        if pred == nil or pred(entity) then
            g:add(entity)
        end
    end

    self.dispatcher:send("add", entity, self)
    return true
end

function world:remove(entity)
    if not group.remove(self, entity) then
        return false
    end

    local groups = self._groups
    for i = 1, #groups do
        groups[i]:remove(entity)
    end

    self.dispatcher:send("remove", entity, self)
    self.dispatcher:clear_listeners_on(entity)
    return true
end

function world:clear()
    if #self == 0 then
        return
    end

    local disp = self.dispatcher
    for i = 1, #self do
        disp:send('remove', self[i], self)
    end

    group.clear(self)

    local groups = self._groups
    for i = 1, #groups do
        groups[i]:clear()
    end
end

---@param entity? sia.entity
function world:refresh(entity)
    local groups = self._groups

    if entity ~= nil then
        for i = 1, #groups do
            local g = groups[i]
            local pred = g.predicate

            if pred == nil or pred(entity) then
                g:add(entity)
            else
                g:remove(entity)
            end
        end
        return
    end

    for i = 1, #groups do
        local g = groups[i]
        local pred = g.predicate

        if pred == nil then
            for j = 1, #self do
                g:add(self[j])
            end
        else
            for j = 1, #self do
                local e = self[j]
                if pred(e) then
                    g:add(e)
                else
                    g:remove(e)
                end
            end
        end
    end
end

---@param entity sia.entity
---@param command sia.command
---@return boolean
function world:modify(entity, command, ...)
    local comp = entity[command.component_key]
    if comp == nil then
        return false
    end
    command(comp, ...)
    self.dispatcher:send(command, entity, ...)
    return true
end

return world