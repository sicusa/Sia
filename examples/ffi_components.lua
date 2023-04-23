local entity = require("sia.entity")
local world = require("sia.world")
local system = require("sia.system")
local scheduler = require("sia.scheduler")

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
    typedef struct {
        float x, y;
    } position_t;

    typedef struct {
        float x, y;
    } speed_t;
]]

local function create_ffi_component(ctype, commands)
    local mt = {}
    local comp_type = ffi.metatype(ctype, mt)
    mt.__index = {
        __sia_component_key = comp_type
    }
    if commands ~= nil then
        for command_name, handler in pairs(commands) do
            mt.__index[command_name] = entity.command(comp_type, handler)
        end
    end
    return comp_type
end

---@class position : ffi.ctype*
---@field set fun(x: number, y: number)
local position = create_ffi_component("position_t", {
    set = function(self, x, y)
        self.x = x
        self.y = y
    end
})

---@class speed : ffi.ctype*
---@field set fun(x: number, y: number)
local speed = create_ffi_component("speed_t", {
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

ffi_world:update(0.1)
ffi_world:update(0.1)
ffi_world:update(0.1)
ffi_world:update(0.1)
ffi_world:update(0.1)