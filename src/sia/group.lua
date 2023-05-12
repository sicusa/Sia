local unpack = unpack or table.unpack

---@class sia.group
---@field package _indices table<sia.entity, integer>
---@field [integer] sia.entity
---@overload fun(entities?: sia.entity[]): sia.group
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

---@param entity sia.entity
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

---@param entity sia.entity
---@return boolean
function group:remove(entity)
    local indices = self._indices
    local index = indices[entity]

    if index == nil then
        return false
    end

    local last_i = #self
    if last_i == index then
        self[last_i] = nil
        indices[entity] = nil
    else
        local last_entity = self[last_i]
        self[index] = last_entity
        self[last_i] = nil

        indices[entity] = nil
        indices[last_entity] = index
    end

    return true
end

---@param entity sia.entity
---@return boolean
function group:contains(entity)
    return self._indices[entity] ~= nil
end

---@param handler fun(entity: sia.entity, group?: sia.group, index?: integer)
function group:foreach(handler)
    for i = 1, #self do
        handler(self[i], self, i)
    end
end

---@param predicate fun(entity: sia.entity, group?: sia.group, index?: integer): any
---@return sia.entity[]
function group:filter(predicate)
    local res = {}
    for i = 1, #self do
        local e = self[i]
        if predicate(e) then
            res[#res+1] = e
        end
    end
    return res
end

---@return sia.entity[]
function group:to_array()
    return {unpack(self)}
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