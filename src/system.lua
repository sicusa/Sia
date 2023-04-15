---Logic for entities
---@class system
---@field package _select table[]
---@field package _select_key string
---@field package _dependencies system[]
---@field package _executor system.executor
---@field package _tasks table<scheduler, table<scheduler.task_graph_node, world>>
---@operator call(system.options): system
local system = {}

---@alias system.executor fun(group: system.group, world?: world, sched?: scheduler, ...): any

---@class system.options
---@field select table[]
---@field dependencies system[]
---@field execute system.executor

---@param select table[]
---@return string
local function calculate_select_key(select)
    local t = {}
    for i = 1, #select do
        t[#t+1] = tostring(select[i])
    end
    table.sort(t)
    return table.concat(t)
end

system.__index = system
setmetatable(system, {
    __call = function(_, options)
        local instance = setmetatable({}, system)
        instance._select = options.select
        instance._select_key = calculate_select_key(options.select)
        instance._dependencies = options.dependencies
        instance._executor = options.execute
        instance._tasks = {}
        return instance
    end
})

---@class system.group: world.group
---@field package _system_ref_count number

---@type table<world, table<string, system.group>>
local world_groups_cache = {}

---@param world world
---@param select entity.component[]
---@return system.group
local function create_system_group(world, select)
    local group = world:create_group(function(e)
        for i = 1, #select do
            if e[select[i]] == nil then
                return false
            end
        end
        return true
    end)
    group._system_ref_count = 1
    return group --[[@as system.group]]
end

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
    local select_key = self._select_key

    local groups_cache = world_groups_cache[world]
    local group

    if groups_cache == nil then
        group = create_system_group(world, select)
        groups_cache = {[select_key] = group}
        world_groups_cache[world] = groups_cache
    else
        group = groups_cache[select_key]
        if group == nil then
            group = create_system_group(world, select)
            groups_cache[select_key] = {[select_key] = group}
        else
            group._system_ref_count = group._system_ref_count + 1
        end
    end

    local executor = self._executor
    local task = sched:create_task(function()
        return executor(group, world, sched)
    end, dep_tasks)
    
    local tasks = self._tasks
    local tasks_entry = tasks[sched]

    if tasks_entry == nil then
        tasks_entry = {}
        tasks[sched] = tasks_entry
    end
    tasks_entry[task] = world

    return task, function()
        sched:remove_task(task)

        tasks_entry[task] = nil
        if next(tasks_entry) == nil then
            tasks[sched] = nil
        end

        local group_ref_count = group._system_ref_count
        if group_ref_count == 0 then
            world:remove_group(group)
            groups_cache[select_key] = nil

            if next(groups_cache) == nil then
                world_groups_cache[world] = nil
            end
        else
            group._system_ref_count = group._system_ref_count - 1
        end
    end
end

return system