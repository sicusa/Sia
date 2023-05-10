local entity = require("sia.entity")
local world = require("sia.world")
local system = require("sia.system")
local scheduler = require("sia.scheduler")

---@class mygame: sia.world
---@field delta_time number
---@field time number
---@field scheduler sia.scheduler
local mygame = world()
mygame.delta_time = 0
mygame.time = 0
mygame.scheduler = scheduler()

function mygame:update(delta_time)
    self.delta_time = delta_time
    self.time = self.time + delta_time
    self.scheduler:tick()
end

local transform = entity.component(function(props)
    return {
        position = props.position or {0, 0},
        rotation = props.rotation or 0
    }
end)
:on("set_position", function(self, value)
    self.position = {value[1], value[2]}
end)
:on("set_rotation", function(self, value)
    self.rotation = value
end)
:on("set_scale", function(self, value)
    self.scale = {value[1], value[2]}
end)

local health = entity.component(function(value)
    return {
        value = value or 100,
        debuff = 0
    }
end)
:on("damage", function(self, damage)
    self.value = self.value - damage
end)
:on("set_debuff", function(self, value)
    self.debuff = value
end)

local location_damge_system = system {
    select = {transform, health},
    trigger = {"add", transform.set_position},
    execute = function(world, sched, e)
        local p = e[transform].position
        -- test damage
        if p[1] == 1 and p[2] == 1 then
            world:modify(e, health.damage, 10)
            print("Damge -> HP "..e[health].value)
        elseif p[1] == 1 and p[2] == 2 then
            world:modify(e, health.set_debuff, 100)
            print("Debuff!")
        end
    end
}

local health_update_system = system {
    select = {health},
    execute = function(world, sched, e)
        local debuff = e[health].debuff
        if debuff ~= 0 then
            world:modify(e, health.damage, debuff * world.delta_time)
            print("Damge -> HP "..e[health].value)
        end
    end
}

local death_system = system {
    select = {health},
    depend = {health_update_system},
    execute = function(world, sched, e)
        if e[health].value <= 0 then
            world:remove(e)
            print("Dead!")
        end
    end
}

local health_systems = system {
    name = "sia.example.mygame.health",
    authors = {"Phlamcenth Sicusa"},
    description = "Health systems",
    version = {0, 0, 1},
    children = {
        health_update_system,
        death_system
    }
}

local gameplay_systems = system {
    name = "sia.example.mygame.gameplay",
    authors = {"Phlamcenth Sicusa"},
    description = "Gameplay systems",
    version = {0, 0, 1},
    depend = {health_systems},
    children = {
        location_damge_system
    }
}

local health_systems_task, dispose_health_systems =
    health_systems:register(mygame, mygame.scheduler)
local gameplay_systems_task, dispose_gameplay_systems =
    gameplay_systems:register(mygame, mygame.scheduler)

local player = entity {
    transform {
        position = {1, 1}
    },
    health(200)
}
mygame:add(player)
mygame:update(0.5)

mygame:modify(player, transform.set_position, {1, 2})
mygame:update(0.5)

mygame.scheduler:create_task(function()
    print("Callback invoked after gameplay and health systems")
    return true -- remove task
end, {health_systems_task, gameplay_systems_task})

mygame:modify(player, transform.set_position, {1, 3})
mygame:update(0.5)
mygame:update(0.5)
mygame:update(0.5)
mygame:update(0.5) -- player dead

dispose_health_systems()
dispose_gameplay_systems()