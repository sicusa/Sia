local group = require("sia.group")

---@class sia.system
---@field name? string
---@field description? string
---@field authors? string[]
---@field version? number[]
---@field children? sia.system[]
---@field depend? sia.system[]
---@field select? table[]
---@field trigger? table<sia.system.triggerable_command, true>
---@field before_execute? sia.system.before_executor
---@field execute? sia.system.executor
---@field package _select_key string
---@field package _tasks table<sia.scheduler, table<sia.scheduler.task_graph_node, sia.world>>
---@overload fun(options: system.options): sia.system
local system = {}

---@alias sia.system.before_executor fun(world?: sia.world, sched?: sia.scheduler): any?
---@alias sia.system.executor fun(world?: sia.world, sched?: sia.scheduler, entity?: sia.entity, arg?: any): any
---@alias sia.system.triggerable_command sia.command | "add" | "remove"

---@class system.options
---@field name? string
---@field description? string
---@field authors? string[]
---@field version? number[]
---@field children? sia.system[]
---@field depend? sia.system[]
---@field select? table[]
---@field trigger? sia.system.triggerable_command[]
---@field before_execute? sia.system.before_executor
---@field execute? sia.system.executor

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

---@param triggers sia.command[]
---@return table<sia.command, true>?
local function to_trigger_table(triggers)
    if triggers == nil then
        return nil
    end
    local t = {}
    for i = 1, #triggers do
        t[triggers[i]] = true
    end
    return t
end

system.__index = system
setmetatable(system, {
    __call = function(_, options)
        local instance = setmetatable({}, system)

        instance.name = options.name
        instance.description = options.description
        instance.authors = options.authors
        instance.version = options.version

        instance.children = options.children
        instance.depend = options.depend
        instance.select = options.select
        instance.trigger = to_trigger_table(options.trigger)
        instance.execute = options.execute

        instance._select_key = calculate_select_key(options.select)
        instance._tasks = {}

        return instance
    end
})

---@class system.group: sia.world.group
---@field package _system_ref_count number

---@type table<sia.world, table<string, system.group>>
local world_groups_cache = {}

---@param world sia.world
---@param select sia.component[]
---@return system.group
local function create_system_group(world, select)
    local grp = world:create_group(function(e)
        for i = 1, #select do
            if e[select[i]] == nil then
                return false
            end
        end
        return true
    end)
    grp._system_ref_count = 1
    return grp --[[@as system.group]]
end

---@param output_tasks sia.scheduler.task_graph_node[]
---@param systems sia.system[]?
---@param world sia.world
---@param sched sia.scheduler
local function add_depended_system_tasks(output_tasks, systems, world, sched)
    if systems == nil then
        return
    end

    for i = 1, #systems do
        local dep_sys = systems[i]
        if dep_sys.execute ~= nil then
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
            add_depended_system_tasks(output_tasks, dep_sys.children, world, sched)
        end
    end

    return output_tasks
end

---@param children sia.system[]
---@param world sia.world
---@param sched sia.scheduler
---@param parent_task? sia.scheduler.task_graph_node
---@return sia.scheduler.task_graph_node[]?
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

---@param world sia.world
---@param sched sia.scheduler
---@param parent_task? sia.scheduler.task_graph_node
function system:register(world, sched, parent_task)
    local dep_tasks = {parent_task}
    add_depended_system_tasks(dep_tasks, self.depend, world, sched)

    local children = self.children
    local execute = self.execute
    local before_execute = self.before_execute

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

    local select = self.select
    local select_key
    local select_group
    local groups_cache

    local trigger = self.trigger
    local monitor_entities
    local entity_add_listener

    if select ~= nil then
        select_key = self._select_key

        if trigger ~= nil then
            local disp = world.dispatcher
            select_group = group()
            monitor_entities = {}

            local has_add_trigger = trigger["add"]
            local has_remove_trigger = trigger["remove"]

            entity_add_listener = function(_, e)
                for i = 1, #select do
                    if e[select[i]] == nil then
                        return
                    end
                end

                local trigger_listener = function(command)
                    if trigger[command] then
                        select_group:add(e)
                    elseif command == "remove" then
                        monitor_entities[e] = nil
                        if has_remove_trigger then
                            select_group:add(e)
                        else
                            select_group:remove(e)
                        end
                    end
                end

                disp:listen_on(e, trigger_listener)
                monitor_entities[e] = trigger_listener

                if has_add_trigger then
                    select_group:add(e)
                end
            end

            disp:listen("add", entity_add_listener)
        else
            groups_cache = world_groups_cache[world]
            if groups_cache == nil then
                select_group = create_system_group(world, select)
                groups_cache = {[select_key] = select_group}
                world_groups_cache[world] = groups_cache
            else
                select_group = groups_cache[select_key]
                if select_group == nil then
                    select_group = create_system_group(world, select)
                    groups_cache[select_key] = select_group
                else
                    select_group._system_ref_count = select_group._system_ref_count + 1
                end
            end
        end
    end

    local task_func
    local dispose

    if select_group ~= nil then
        if trigger ~= nil then
            if before_execute == nil then
                task_func = function()
                    local len = #select_group
                    if len == 0 then return end

                    local i = 1
                    while i <= len do
                        if execute(world, sched, select_group[i]) then
                            dispose()
                            return
                        end
                        i = i + 1
                        len = #select_group
                    end

                    select_group:clear()
                end
            else
                task_func = function()
                    local len = #select_group
                    if len == 0 then return end

                    local i = 1
                    local arg = before_execute(world, sched)

                    while i <= len do
                        if execute(world, sched, select_group[i], arg) then
                            dispose()
                            return
                        end
                        i = i + 1
                        len = #select_group
                    end

                    select_group:clear()
                end
            end
        else
            if before_execute == nil then
                task_func = function()
                    local i = 1
                    while i <= #select_group do
                        if execute(world, sched, select_group[i]) then
                            dispose()
                            return
                        end
                        i = i + 1
                    end
                end
            else
                task_func = function()
                    local i = 1
                    local arg = before_execute(world, sched)

                    while i <= #select_group do
                        if execute(world, sched, select_group[i], arg) then
                            dispose()
                            return
                        end
                        i = i + 1
                    end
                end
            end
        end
    else
        if before_execute == nil then
            task_func = function()
                if execute(world, sched) then
                    dispose()
                end
            end
        else
            task_func = function()
                local arg = before_execute(world, sched)
                if execute(world, sched, nil, arg) then
                    dispose()
                end
            end
        end
    end

    local task = sched:create_task(task_func, dep_tasks)
    tasks_entry[task] = world

    local children_disposers =
        children and register_children(children, world, sched, task)

    dispose = function()
        if task.status == "removed" then
            error("system has been disposed")
        end
        sched:remove_task(task)

        tasks_entry[task] = nil
        if next(tasks_entry) == nil then
            tasks[sched] = nil
        end

        if select_group ~= nil then
            if trigger ~= nil then
                local disp = world.dispatcher
                disp:unlisten("add", entity_add_listener)

                for e, trigger_listener in pairs(monitor_entities) do
                    disp:unlisten_on(e, trigger_listener)
                end
            else
                local group_ref_count = select_group._system_ref_count
                if group_ref_count == 0 then
                    world:remove_group(select_group --[[@as system.group]])
                    groups_cache[select_key] = nil

                    if next(groups_cache) == nil then
                        world_groups_cache[world] = nil
                    end
                else
                    select_group._system_ref_count = select_group._system_ref_count - 1
                end
            end
        end

        if children_disposers ~= nil then
            for i = 1, #children_disposers do
                children_disposers[i]()
            end
        end
    end

    return task, dispose
end

return system