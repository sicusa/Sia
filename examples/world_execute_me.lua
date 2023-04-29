--[[
world.execute (me) ; - Mili (ミリー)
Lyrics by: momocashew/Mili
Composed by: momocashew/Mili
]]
local _ = print

_"world:execute(me)"
_"- momocashew/Mili\n"

_"Switch on the power line"
_"Remember to put on"
_"PROTECTION\n"
local result, err = pcall(function()
    _"Lay down your pieces"
    _"And let's begin"
    _"OBJECT CREATION\n"
    local entity = require("sia.entity")
    local world = require("sia.world")
    local system = require("sia.system")
    local scheduler = require("sia.scheduler")

    local user = entity.component(function(props)
        return {
            name = props.name,
            permission = props.permission
        };
    end)
    local active_user = entity {
        user {
            name = "Mili",
            permission = "administrator"
        }
    }

    _"Fill in my data parameters"
    _"INITIALIZATION\n"
    local ai = entity.component(function(props)
        return {
            name = assert(props.name),
            version = assert(props.version),
            current = assert(props.current),
            gender = assert(props.gender),
            role = assert(props.role),
            vision_enabled = props.version_enabled or true,
            owner = assert(props.owner)
        }
    end)
    :on("set_current", function(self, current)
        self.current = current
    end)
    :on("set_gender", function(self, gender)
        self.gender = gender
    end)
    :on("set_role", function(self, role)
        self.role = role
    end)
    :on("set_vision_enabled", function(self, enabled)
        self.set_vision_enabled = enabled
    end)
    local mili_ai = ai {
        name = "Mili_AI",
        version = "0.0.1",
        current = "AC",
        gender = "female",
        role = "S",
        owner = active_user
    }

    _"Set up our new world"
    _"And let's begin the"
    _"SIMULATION\n"
    local sim_world = world()
    sim_world.time = os.time()
    sim_world.scheduler = scheduler()
    sim_world:add(active_user)

    _"If I'm a set of points"
    local points = entity.component(function(positions)
        return positions
    end)
    local me = entity {
        mili_ai,
        points {
            {0, 0},
            {0, 1},
            {1, 1},
            {1, 0}
        }
    }
    sim_world:add(me)
    
    _"Then I will give you my"
    _("DIMENSION:", #me[points][1], "\n")

    _"If I'm a circle"
    local circle = entity.component(function(props)
        return {
            radius = props.radius or 0
        }
    end)
    me = entity {
        mili_ai,
        circle {
            radius = math.random()
        }
    }
    sim_world:add(me)
    
    _"Then I will give you my"
    _("CIRCUMFERENCE:", 2 * math.pi * me[circle].radius, "\n")

    _"If I'm a sine wave"
    local sine_wave = entity.component(function(props)
        return {
            amplitude = props.amplitude,
            phase = props.phase,
            frequency = props.frequency
        }
    end)
    function sine_wave:calculate(time)
        return self.amplitude * math.sin(
            self.phase + 2 * math.pi * self.frequency * time)
    end
    local mili_sw = sine_wave {
        amplitude = math.random(),
        phase = math.random(),
        frequency = math.random()
    }
    me = entity {
        mili_ai,
        mili_sw
    }
    sim_world:add(me)

    _"Then you can sit on all my"
    _("TANGENTS:", ("f(t) = %f·2π%f·cos(%f + 2π%ft)"):format(
        mili_sw.amplitude,
        mili_sw.frequency,
        mili_sw.phase,
        mili_sw.frequency
    ), "\n")

    _"If I approach infinity"
    for n = 0, 1 / 0 do
        -- _(mili_sw:calculate(n))
        break
    end

    _"Then you can be my"
    _("LIMITATIONS: ", 0 / 0, "\n")

    _"Switch my current"
    _"To AC to DC\n"
    sim_world:modify(me, ai.set_current, "AC")
    sim_world:modify(me, ai.set_current, "DC")

    _"And then blind my vision"
    _"So dizzy so dizzy\n"
    sim_world:modify(me, ai.set_vision_enabled, false)
    
    _"Oh we can travel"
    _"To A.D to B.C\n"
    local bc_epoch = -124334381143
    sim_world.time = bc_epoch - sim_world.time
    sim_world.time = bc_epoch - sim_world.time

    _"And we can unite"
    _"So deeply so deeply\n"
    local unification = entity.component(function(...)
        return {...}
    end)
    sim_world:add(entity {
        unification(
            active_user,
            unpack(sim_world:filter(function(e)
                return e[ai] and e[ai].name == "Mili_AI"
            end)))
    })
    -- TODO: Finish the rest of the song
end)

print(result, err)