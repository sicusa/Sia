local entity = require("sia.entity")
local world = require("sia.world")
local system = require("sia.system")
local scheduler = require("sia.scheduler")

---@class ecosystem: world
---@field delta_time number
---@field time number
---@field scheduler scheduler
local ecosystem = world()
ecosystem.delta_time = 0
ecosystem.time = 0
ecosystem.scheduler = scheduler()

function ecosystem:update(delta_time)
    self.delta_time = delta_time
    self.time = self.time + delta_time
    self.scheduler:tick()
end

--- auxiliary

local table2d = {}

table2d.put = function(t, k1, k2, value)
    local r = t[k1]
    if r == nil then
        r = {}
        t[k1] = r
    end
    r[k2] = value
end

table2d.get = function(t, k1, k2)
    local r = t[k1]
    if r == nil then
        return nil
    end
    return r[k2]
end

-- components

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

local constraint = entity.component(function(props)
    return {
        source = assert(props.source),
        target = assert(props.target),
        position = props.position,
        rotation = props.rotation
    }
end)
:on("set_position", function(self, value)
    if value == nil then
        self.position = nil
    else
        self.position = {value[1], value[2]}
    end
end)
:on("set_rotation", function(self, value)
    self.rotation = value
end)

local timer = entity.component(function(initial_value)
    return {
        value = initial_value or 0
    }
end)
:on("set_value", function(self, value)
    self.value = value
end)

local map = entity.component(function()
    return {}
end)
:on("set_object", function(self, pos, object)
    table2d.put(self, pos[1], pos[2], object)
end)

function map:get(pos)
    return table2d.get(self, pos[1], pos[2])
end

local in_map = entity.component(function(map)
    return {
        entity = map
    }
end)
:on("set_map", function(self, map)
    self.entity = map
end)

---@class creature.action_rule
---@field type string
---@field cooldown number
---@field predicate fun(entity: entity, world?: world): boolean
---@field execute fun(entity: entity, world?: world, sched?: scheduler)

local creature = entity.component(function(props)
    return {
        dead = false,
        species = assert(props.species),
        sex = assert(props.sex),
        mass = assert(props.mass),
        health = props.health or 1,
        repletion = props.repletion or 1,
        hunger_rate = assert(props.hunger_rate),
        action_rules = props.action_rules or {}
    }
end)
:on("kill", function(self)
    self.dead = true
    self.repletion = 0
end)
:on("set_health", function(self, value)
    self.health = value
end)
:on("set_repletion", function(self, value)
    self.repletion = value
end)

-- transform systems

local constraint_state = entity.component(function(props)
    return {
        listener = props.listener
    }
end)

local constraint_initialize_system = system {
    select = {constraint},
    trigger = {"add"},

    execute = function(world, sched, e)
        local c = e[constraint]
        local source = c.source
        local target = c.target

        local listener = function(command, entity, value)
            if not world:contains(e) then
                return
            end
            if command == "remove" then
                world:remove(c)
                return
            end

            if command == transform.set_position then
                local offset = c.position
                if offset ~= nil then
                    world:modify(target, transform.set_position,
                        {value[1] + offset[1], value[2] + offset[2]})
                end
            elseif command == transform.set_rotation then
                local offset = c.rotation
                if offset ~= nil then
                    world:modify(target, transform.set_rotation, value + offset)
                end
            end
        end

        local src_trans = source[transform]
        if src_trans ~= nil then
            if c.position then
                local pos = src_trans.position
                world:modify(target, transform.set_position,
                    {pos[1] + c.position[1], pos[2] + c.position[2]})
            elseif c.rotation then
                world:modify(target, transform.set_rotation,
                    src_trans.rotation + c.rotation)
            end
        end

        e:add_state(constraint_state {
            listener = listener
        })
        world.dispatcher:listen_on(source, listener)
    end
}

local constraint_uninitialize_system = system {
    select = {constraint},
    trigger = {"remove"},

    execute = function(world, sched, e)
        local c = e[constraint]
        local s = e[constraint_state]
        if s ~= nil then
            world.dispatcher:unlisten_on(c.source, s.listener)
        end
    end
}

local transform_systems = system {
    children = {
        constraint_initialize_system,
        constraint_uninitialize_system
    }
}

-- map systems

local in_map_state = entity.component(function(props)
    return {
        prev_pos = props.prev_pos
    }
end)

local in_map_object_initialize_system = system {
    select = {in_map, transform},
    trigger = {"add"},
    
    execute = function(world, sched, e)
        local m = e[in_map].entity
        local m_comp = m[map]

        local t = e[transform]
        local p = t.position

        if table2d.get(m_comp, p[1], p[2]) ~= nil then
            print("error: map position has been occupied by another object")
            return
        end

        world:modify(m, map.set_object, p, e)
        e:add_state(in_map_state {
            prev_pos = p
        })
    end
}

local map_object_move_system = system {
    select = {in_map, transform},
    trigger = {transform.set_position},
    depend = {in_map_object_initialize_system},

    execute = function(world, sched, e)
        local m = e[in_map].entity
        local m_comp = m[map]

        local s = e[in_map_state]
        local t = e[transform]
        local p = t.position

        if table2d.get(m_comp, p[1], p[2]) ~= nil then
            world:modify(e, transform.set_position, s.prev_pos)
            return
        end
        if table2d.get(m_comp, s.prev_pos[1], s.prev_pos[2]) == e then
            world:modify(m, map.set_object, s.prev_pos, nil)
        end
        world:modify(m, map.set_object, p, e)
        s.prev_pos = p
    end
}

local map_systems = system {
    depend = {transform_systems},
    children = {
        in_map_object_initialize_system,
        map_object_move_system
    }
}

-- time systems

local timer_accumulate_system = system {
    select = {timer},
    execute = function(world, sched, e)
        local timer = e[timer]
        timer.value = timer.value + world.delta_time
    end
}

local time_systems = system {
    children = {
        timer_accumulate_system
    }
}

-- creature systems

local creature_state = entity.component(function(props)
    return {
        active_actions = {}
    }
end)

local creature_state_initialize_system = system {
    select = {creature},
    trigger = {"add"},

    execute = function(world, sched, e)
        e:add_state(creature_state())
    end
}

local creature_repletion_decline_system = system {
    select = {creature},

    execute = function(world, sched, e)
        local c = e[creature]
        if c.dead then return end
        world:modify(e, creature.set_repletion,
            c.repletion - c.hunger_rate * world.delta_time)
    end
}

local creature_repleation_check_system = system {
    select = {creature},
    trigger = {creature.set_repletion},
    
    execute = function(world, sched, e)
        local c = e[creature]
        if c.dead then return end
        if c.repletion <= 0 then
            world:modify(e, creature.kill)
        end
    end
}

local creature_health_check_system = system {
    select = {creature},
    trigger = {creature.set_health},

    execute = function(world, sched, e)
        local c = e[creature]
        if c.dead then return end
        if c.health <= 0 then
            world:modify(e, creature.kill)
        end
    end
}

local creature_action_trigger_system = system {
    select = {creature},

    execute = function(world, sched, e)
        local c = e[creature]
        local actions = e[creature_state].active_actions
        local rules = c.action_rules

        for i = 1, #rules do
            local r = rules[i]
            if actions[r.type] == nil and r.predicate(e, world) then
                actions[r.type] = r.execute
            end
        end
    end
}

local creature_active_actions_execute_system = system {
    select = {creature},
    
    execute = function(world, sched, e)
        local actions = e[creature_state].active_actions
        for type, execute in pairs(actions) do
            if execute(e, world, sched) then
                actions[type] = nil
            end
        end
    end
}

local creature_systems = system {
    depend = {
        transform_systems,
        map_systems,
        time_systems
    },
    children = {
        creature_state_initialize_system,
        creature_repletion_decline_system,
        creature_repleation_check_system,
        creature_health_check_system,
        creature_action_trigger_system,
        creature_active_actions_execute_system
    }
}

-- register systems to ecosystem world

local sched = ecosystem.scheduler
transform_systems:register(ecosystem, sched)
map_systems:register(ecosystem, sched)
time_systems:register(ecosystem, sched)
creature_systems:register(ecosystem, sched)

-- test ecosystem

print("== constraint ==")

local e1 = entity {
    transform {
        position = {1, 1}
    }
}

local e2 = entity {
    transform {
        position = {0, 0}
    }
}

local c = entity {
    constraint {
        source = e1,
        target = e2,
        position = {5, 5}
    }
}

ecosystem:add(e1)
ecosystem:add(e2)
ecosystem:add(c)

ecosystem:modify(e1, transform.set_position, {1, 1})
ecosystem:update(0.1)
print("result: ", unpack(e2[transform].position))

ecosystem:modify(e1, transform.set_position, {1, 3})
ecosystem:update(0.1)
print("result: ", unpack(e2[transform].position))

ecosystem:remove(c)

ecosystem:modify(e1, transform.set_position, {3, 3})
ecosystem:update(0.1)
print("result: ", unpack(e2[transform].position))

print()
print("== creature repletion & health ==")

local e1 = entity {
    creature {
        species = "test_species",
        sex = "test_sex",
        mass = 1,
        hunger_rate = 4
    }
}

local e2 = entity {
    creature {
        species = "test_species",
        sex = "test_sex",
        mass = 1,
        hunger_rate = 0.1
    }
}

ecosystem:add(e1)
ecosystem:add(e2)
print("repletion: ", e1[creature].repletion)

ecosystem:update(0.1)
ecosystem:update(0.1)
ecosystem:update(0.1)
print("e1 repletion: ", e1[creature].repletion)
print("e1 dead: ", e1[creature].dead)

print("e2 repletion: ", e2[creature].repletion)
print("e2 dead: ", e2[creature].dead)

ecosystem:modify(e2, creature.set_health, 0)
ecosystem:update(0.1)
print("e2 repletion: ", e2[creature].repletion)
print("e2 dead: ", e2[creature].dead)

print()
print("== creature action ==")

local e1 = entity {
    creature {
        species = "test_species",
        sex = "test_sex",
        mass = 1,
        hunger_rate = 2,
        action_rules = {
            {
                type = "eat",
                predicate = function(e, world)
                    local c = e[creature]
                    return c.repletion < 0.5
                end,
                execute = function(e, world, sched)
                    local repletion = e[creature].repletion
                    if repletion >= 0.9 then
                        print("Stop eating.")
                        return true
                    end
                    print("Eating food.")
                    world:modify(e, creature.set_repletion, repletion + 5 * world.delta_time)
                end
            }
        }
    }
}

ecosystem:add(e1)

ecosystem:update(0.1)
print("e1 repletion: ", e1[creature].repletion)
ecosystem:update(0.1)
print("e1 repletion: ", e1[creature].repletion)
ecosystem:update(0.1)
print("e1 repletion: ", e1[creature].repletion)
ecosystem:update(0.1)
print("e1 repletion: ", e1[creature].repletion)
ecosystem:update(0.1)
print("e1 repletion: ", e1[creature].repletion)
ecosystem:update(0.1)
print("e1 repletion: ", e1[creature].repletion)

ecosystem:remove(e1)

print()
print("== test map ==")

local m = entity {
    map()
}

local e1 = entity {
    in_map(m),
    transform {
        position = {1, 3}
    }
}
local e2 = entity {
    in_map(m),
    transform {
        position = {3, 3}
    }
}

ecosystem:add(m)
ecosystem:add(e1)
ecosystem:add(e2)

ecosystem:update(0.1)
print(table2d.get(m[map], 1, 3) == e1)

ecosystem:modify(e1, transform.set_position, {2, 4})
ecosystem:update(0.1)
print(table2d.get(m[map], 1, 3) == nil)
print(table2d.get(m[map], 2, 4) == e1)

ecosystem:modify(e1, transform.set_position, {3, 3})
ecosystem:update(0.1)
print(table2d.get(m[map], 2, 4) == e1)
print(table2d.get(m[map], 3, 3) == e2)