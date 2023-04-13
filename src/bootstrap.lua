local entity = require("entity")
local world = require("world")
local system = require("system")
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

local timer = entity.component(function()
    return {0}
end)

---@param time number
function timer:add_time(time)
    self[1] = self[1] + time
end

local timer_system = system {
    select = {timer},
    handler = function(e, dt)
        local t = e[timer]
        t:add_time(dt)
        print("timer1: "..t[1])
    end
}
local _, dispose = timer_system:register(w, sched)

local timer_system2 = system {
    select = {timer},
    dependencies = {timer_system},

    handler = function(e, dt)
        local t = e[timer]
        t:add_time(dt)
        print("timer2: "..t[1])
    end
}
timer_system2:register(w, sched)

dispose()

w:add(entity {
    timer()
})

w:add(entity {
    timer()
})

sched:tick(0.5)
sched:tick(0.5)