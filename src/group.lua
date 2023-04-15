local entity = require("entity")

---Container of `entity`
---@class group
---@field package _indices table<entity, integer>
---@field [integer] entity
---@operator call(entity[]?): group
local group = {}

group.__index = group
setmetatable(group, {
    __call = function(_, entities)
        local instance = setmetatable({}, group)

        local indices = {}
        instance._indices = indices

        if entities ~= nil then
            for i, e in ipairs(entities) do
                instance[i] = e
                indices[e] = i
            end
        end

        return instance
    end
})

---@param entity entity
---@return boolean
function group:add(entity)
    local indices = self._indices
    local index = indices[entity]

    if index then
        return false
    end

    index = #self + 1
    self[index] = entity
    indices[entity] = index

    return true
end

---@param entity entity
---@return boolean
function group:remove(entity)
    local indices = self._indices
    local index = indices[entity]

    if index == nil then
        return false
    end

    local last_entity = self[#self]
    self[index] = last_entity
    self[#self] = nil

    indices[entity] = nil
    indices[last_entity] = index

    return true
end

---@param entity entity
---@return boolean
function group:has(entity)
    return self._indices[entity] ~= nil
end

---@param handler fun(entity: entity, group?: group, index?: integer)
function group:foreach(handler)
    for i = 1, #self do
        handler(self[i], self, i)
    end
end

function group:clear()
    local indices = self._indices
    for i = 1, #self do
        local e = self[i]
        self[i] = nil
        indices[e] = nil
    end
end

return group