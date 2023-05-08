local entity = require("sia.entity")
local world = require("sia.world")
local system = require("sia.system")
local scheduler = require("sia.scheduler")
local ffic = require("sia.ffic")

local ffi = require("ffi")

---@class ffi_world: world
---@field delta_time number
---@field time number
---@field scheduler scheduler
local ffi_world = world()
ffi_world.delta_time = 0
ffi_world.time = 0
ffi_world.scheduler = scheduler()

function ffi_world:update(delta_time)
    self.delta_time = delta_time
    self.time = self.time + delta_time
    self.scheduler:tick()
end

ffi.cdef[[
    struct position {
        float x, y;
    };
    struct speed {
        float x, y;
    };
]]

---@class position : ffi.ctype*
---@field set fun(x: number, y: number)
local position = ffic.struct("position", {
    set = function(self, x, y)
        self.x = x
        self.y = y
    end
})

---@class speed : ffi.ctype*
---@field set fun(x: number, y: number)
local speed = ffic.struct("speed", {
    set = function(self, x, y)
        self.x = x
        self.y = y
    end
})

local motion_system = system {
    select = {position, speed},
    execute = function(world, sched, e)
        local p = e[position]
        local s = e[speed]
        local dt = world.delta_time
        world:modify(e, position.set, p.x + s.x * dt, p.y + s.y * dt)
    end
}

local position_listen_system = system {
    select = {position},
    trigger = {position.set},
    execute = function(world, sched, e)
        local p = e[position]
        print("position changed: ", p.x, p.y)
    end
}

local sched = ffi_world.scheduler
motion_system:register(ffi_world, sched)
position_listen_system:register(ffi_world, sched)

local e = entity {
    position(1, 2),
    speed(2, 2)
}
ffi_world:add(e)

local e2_polymer = ffic.polymer(position, speed)
local e2 = entity {
    e2_polymer {
        position(1, 2),
        speed(2, 2)
    }
}
ffi_world:add(e2)

ffi_world:update(0.1)
ffi_world:update(0.1)
ffi_world:update(0.1)
ffi_world:update(0.1)
ffi_world:update(0.1)