local entity = require("entity")
local world = require("world")
local scheduler = require("scheduler")

local transform = entity.component(function(props)
    return {
        position = props.position,
        rotation = props.rotation,
        scale = props.scale
    }
end)

---@alias vector3 number[3]

---@param position vector3
function transform:set_position(position)
    self.position = position
end

---@param rotation vector3
function transform:set_rotation(rotation)
    self.rotation = rotation
end

---@param scale vector3
function transform:set_scale(scale)
    self.scale = scale
end

local updator = entity.component(function(handler)
    return {handler}
end)

local e = entity {
    transform {
        position = {1, 2, 3},
        rotation = {4, 5, 6},
        scale = {1, 1, 1}
    },
    updator(function()
        print("hello world")
    end)
}

local w = world { e }
w:add(entity {
    updator(function()
        print("?")
    end)
})

local all = w:create_group()
print(#all)

local transforms = w:create_group(function(e)
    return e[transform] and e[updator]
end)
print(#transforms)

w:remove(e)
print(#all)
print(#transforms)

local sched = scheduler()
local t1 = sched:create_task(function()
    print("task 1")
end)

local t2 = sched:create_task(function()
    print("task 2")
    return true
end, {t1})

local t3 = sched:create_task(function()
    print("task 3")
    return true
end, {t1, t2})

local t4 = sched:create_task(function()
    print("task 4")
    return true
end, {t3})

local t5 = sched:create_task(function()
    print("task 5")
    sched:remove_task(t1)
    return true
end, {t2, t4})

sched:tick()
print(sched:get_task_count())