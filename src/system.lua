---Logic for entities
---@class system
---@field package _children? system[]
---@field package _select? table[]
---@field package _select_key string
---@field package _dependencies? system[]
---@field package _execute? system.executor
---@field package _tasks table<scheduler, table<scheduler.task_graph_node, world>>
---@operator call(system.options): system
local system = {}

---@alias system.executor fun(world?: world, sched?: scheduler, group?: system.group, ...): any

---@class system.options
---@field children? system[]
---@field select? table[]
---@field depend? system[]
---@field execute? system.executor

---@param select table[]
---@return string
local function calculate_select_key(select)
    if select == nil then
        return ""
    end
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
        instance._children = options.children
        instance._select = options.select
        instance._select_key = calculate_select_key(options.select)
        instance._dependencies = options.depend
        instance._execute = options.execute
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

---@param output_tasks scheduler.task_graph_node[]?
---@param systems system[]
---@param world world
---@param sched scheduler
local function add_depended_system_tasks(output_tasks, systems, world, sched)
    if systems == nil then
        return
    end

    for i = 1, #systems do
        local dep_sys = systems[i]
        if dep_sys._execute ~= nil then
            local dep_tasks_entry = dep_sys._tasks[sched]
            if dep_tasks_entry == nil then
                error("failed to register system: dependency check failed #"..i)
            end

            local found = false
            for dep_node, dep_node_world in pairs(dep_tasks_entry) do
                if dep_node_world == world then
                    output_tasks[#output_tasks+1] = dep_node
                    found = true
                end
            end

            if not found then
                error("failed to register system: dependency check failed #"..i)
            end
        else
            add_depended_system_tasks(output_tasks, dep_sys._children, world, sched)
        end
    end

    return output_tasks
end

---@param children system[]
---@param world world
---@param sched scheduler
---@param parent_task? scheduler.task_graph_node
---@return scheduler.task_graph_node[]?
local function register_children(children, world, sched, parent_task)
    if children == nil then
        return nil
    end

    local children_disposers = {}
    for i = 1, #children do
        local _, disposer = children[i]:register(world, sched, parent_task)
        children_disposers[i] = disposer
    end
    return children_disposers
end

---@param world world
---@param sched scheduler
---@param parent_task? scheduler.task_graph_node
function system:register(world, sched, parent_task)
    local dep_tasks = {parent_task}
    add_depended_system_tasks(dep_tasks, self._dependencies, world, sched)

    local children = self._children
    local execute = self._execute

    if execute == nil then
        local children_disposers =
            children and register_children(children, world, sched)

        return nil, children_disposers and function()
            for i = 1, #children_disposers do
                children_disposers[i]()
            end
        end
    end
        
    local tasks = self._tasks
    local tasks_entry = tasks[sched]

    if tasks_entry == nil then
        tasks_entry = {}
        tasks[sched] = tasks_entry
    end

    local select = self._select
    if select == nil then
        local task = sched:create_task(function()
            return execute(world, sched)
        end, dep_tasks)
        tasks_entry[task] = world

        local children_disposers =
            children and register_children(children, world, sched, task)

        return task, function()
            sched:remove_task(task)

            tasks_entry[task] = nil
            if next(tasks_entry) == nil then
                tasks[sched] = nil
            end

            if children_disposers ~= nil then
                for i = 1, #children_disposers do
                    children_disposers[i]()
                end
            end
        end
    end

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
            groups_cache[select_key] = group
        else
            group._system_ref_count = group._system_ref_count + 1
        end
    end

    local task = sched:create_task(function()
        return execute(world, sched, group)
    end, dep_tasks)
    tasks_entry[task] = world

    local children_disposers =
        children and register_children(children, world, sched, task)

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

        if children_disposers ~= nil then
            for i = 1, #children_disposers do
                children_disposers[i]()
            end
        end
    end
end

return system