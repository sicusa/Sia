local entity = require("entity")

---@class system
---@field private _select table[]
---@field private _dependencies system[]
---@field private _handler system.entity_handler
---@field private _command_receiver system.command_receiver
---@field private _tasks table<scheduler, table<scheduler.task_graph_node, world>>
---@operator call(system.options): system
local system = {}

---@alias system.entity_handler fun(entity: entity, ...): command | nil
---@alias system.command_receiver fun(command: command, world?: world, sched?: scheduler)

---@class system.options
---@field select table[]
---@field dependencies system[]
---@field handler system.entity_handler
---@field command_receiver? system.command_receiver

system.__index = system
setmetatable(system, {
    __call = function(self, options)
        local instance = setmetatable({}, self)
        instance._select = options.select
        instance._dependencies = options.dependencies
        instance._handler = options.handler
        instance._command_receiver = options.command_receiver
        instance._tasks = {}
        return instance
    end
})

---@param world world
---@param sched scheduler
function system:register(world, sched)
    local deps = self._dependencies
    local dep_tasks = nil

    if deps ~= nil then
        dep_tasks = {}

        for i = 1, #deps do
            local dep_sys = deps[i]
            local dep_tasks_entry = dep_sys._tasks[sched]

            if dep_tasks_entry == nil then
                error("failed to register system: dependency check failed #"..i)
            end

            local found = false

            for dep_node, dep_node_world in pairs(dep_tasks_entry) do
                if dep_node_world == world then
                    dep_tasks[#dep_tasks+1] = dep_node
                    found = true
                end
            end

            if not found then
                error("failed to register system: dependency check failed #"..i)
            end
        end
    end

    local select = self._select
    local handler = self._handler

    local group = world:create_group(function(e)
        for i = 1, #select do
            if e[select[i]] == nil then
                return false
            end
        end
        return true
    end)

    local task

    local cmd_receiver = self._command_receiver
    if cmd_receiver then
        task = sched:create_task(function(...)
            for i = 1, #group do
                local cmd = handler(group[i], ...)
                if cmd then cmd_receiver(cmd, world, sched) end
            end
        end, dep_tasks)
    else
        task = sched:create_task(function(...)
            for i = 1, #group do
                local cmd = handler(group[i], ...)
                if cmd then cmd:execute(world, sched) end
            end
        end, dep_tasks)
    end

    local tasks = self._tasks
    local tasks_entry = tasks[sched]

    if tasks_entry == nil then
        tasks_entry = {}
        tasks[sched] = tasks_entry
    end
    tasks_entry[task] = world

    return task, function()
        sched:remove_task(task)
        world:remove_group(group)

        tasks_entry[task] = nil
        if next(tasks_entry) == nil then
            tasks[sched] = nil
        end
    end
end

return system