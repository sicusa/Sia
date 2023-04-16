local entity = require("entity")
local world = require("world")
local system = require("system")
local scheduler = require("scheduler")

---@class mygame: world
---@field delta_time number
---@field time number
---@field scheduler scheduler
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
        rotation = props.rotation or 0,
        scale = props.scale or {1, 1}
    }
end)

transform:on("set_position", function(self, value)
    local p = self.position
    p[1] = value[1]
    p[2] = value[2]
end)

transform:on("set_rotation", function(self, value)
    self.rotation = value
end)

transform:on("set_scale", function(self, value)
    local s = self.scale
    s[1] = value[1]
    s[2] = value[2]
end)

local health = entity.component(function(value)
    return {
        value = value or 100,
        debuff = 0
    }
end)

health:on("damage", function(self, damage)
    self.value = self.value - damage
end)

health:on("set_debuff", function(self, value)
    self.debuff = value
end)

local location_damge_system = system {
    select = {transform, health},
    trigger = {transform.set_position},
    execute = function(world, sched, e)
        local p = e[transform].position
        -- test damage
        if p[1] == 1 and p[2] == 1 then
            world:modify(e, health.damage, 10)
            print("一次性伤害：HP "..e[health].value)
        elseif p[1] == 1 and p[2] == 2 then
            world:modify(e, health.set_debuff, 100)
            print("激活持续性伤害！")
        end
    end
}

local health_update_system = system {
    select = {health},
    execute = function(world, sched, e)
        local debuff = e[health].debuff
        if debuff ~= 0 then
            world:modify(e, health.damage, debuff * world.delta_time)
            print("持续性伤害：HP "..e[health].value)
        end
    end
}

local death_system = system {
    select = {health},
    depend = {health_update_system},
    execute = function(world, sched, e)
        if e[health].value <= 0 then
            world:remove(e)
            print("死亡！")
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

local _, dispose_health_systems = health_systems:register(mygame, mygame.scheduler)
local _, dispose_gameplay_systems = gameplay_systems:register(mygame, mygame.scheduler)

local e = entity {
    transform {
        position = {1, 0}
    },
    health(200)
}
mygame:add(e)

mygame:modify(e, transform.set_position, {1, 1})
mygame:update(0.5)

mygame:modify(e, transform.set_position, {1, 2})
mygame:update(0.5)

mygame:modify(e, transform.set_position, {1, 3})
mygame:update(0.5)
mygame:update(0.5)
mygame:update(0.5)
mygame:update(0.5)

dispose_health_systems()
dispose_gameplay_systems()