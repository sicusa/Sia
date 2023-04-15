local group = require("group")
local dispatcher = require("dispatcher")

---Group that filter entity into subgroups
---@class world: group
---@field package _groups world.group[]
---@field dispatcher dispatcher
---@operator call(entity[]?): world
local world = {}

---@class world.group: group
---@field world world
---@field index integer
---@field predicate? fun(entity: entity): any

world.__index = world
setmetatable(world, {
    __index = group,
    __call = function(_, entities)
        local instance = setmetatable(group(entities), world)
        instance._groups = {}
        instance.dispatcher = dispatcher()
        return instance
    end
})

---@param predicate? fun(entity: entity): any
---@return world.group
function world:create_group(predicate)
    local g = group() --[[@as world.group]]
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

---@param group world.group
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

---@param entity? entity
function world:refresh(entity)
    local groups = self._groups

    if entity == nil then
        for i = 1, #groups do
            local g = groups[i]
            local pred = g.predicate

            if pred == nil then
                for j = 1, #self do
                    g:add(self[i])
                end
            else
                for j = 1, #self do
                    local e = self[i]
                    if pred(e) then
                        g:add(e)
                    else
                        g:remove(e)
                    end
                end
            end
        end
    else
        for i = 1, #groups do
            local g = groups[i]
            local pred = g.predicate

            if pred == nil or pred(entity) then
                g:add(entity)
            else
                g:remove(entity)
            end
        end
    end
end

---@param entity entity
---@param command entity.component.command
function world:modify(entity, command, ...)
    self.dispatcher:send(command, entity, ...)
    command(entity[command.component], ...)
end

return world