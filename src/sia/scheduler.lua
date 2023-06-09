---@class sia.scheduler
---@field package _task_count integer
---@field package _orphan_task_seq sia.scheduler.task_graph_node[]
---@field package _depended_task_seq sia.scheduler.task_graph_node[]
---@field package _depended_task_seq_dirty boolean
---@field package _task_graph_nodes table<sia.scheduler.task_graph_node, boolean | integer>
---@field package _tasks_to_remove sia.scheduler.task_graph_node[]
---@field package _ticking boolean
---@overload fun(): sia.scheduler
local scheduler = {}

---@alias sia.scheduler.callback fun(): any | nil
---@alias sia.scheduler.task_graph_node.status
---| "added"
---| "adding"
---| "removed"

---@class sia.scheduler.task_graph_node
---@field callback sia.scheduler.callback
---@field depended_nodes? table<sia.scheduler.task_graph_node, true>
---@field depending_nodes? table<sia.scheduler.task_graph_node, true>
---@field status? sia.scheduler.task_graph_node.status

scheduler.__index = scheduler
setmetatable(scheduler, {
    __call = function(_)
        local instance = setmetatable({}, scheduler)
        instance._task_count = 0
        instance._orphan_task_seq = {}
        instance._depended_task_seq = {}
        instance._depended_task_seq_dirty = false
        instance._task_graph_nodes = {}
        instance._tasks_to_remove = {}
        instance._ticking = false
        return instance
    end
})

---@param callback sia.scheduler.callback
---@param dependencies? sia.scheduler.task_graph_node[]
---@return sia.scheduler.task_graph_node
function scheduler:create_task(callback, dependencies)
    ---@type sia.scheduler.task_graph_node
    local node = {
        callback = callback
    }

    local task_nodes = self._task_graph_nodes

    if dependencies == nil or #dependencies == 0 then
        local task_seq = self._orphan_task_seq
        local index = #task_seq + 1
        task_seq[index] = node
        task_nodes[node] = index
    else
        local depended_nodes = {}
        for i, depended_node in ipairs(dependencies) do
            if task_nodes[depended_node] == nil then
                error("cannot create task: invalid depended task graph node #"..i)
            end
            depended_nodes[depended_node] = true
            local dep_nodes = depended_node.depending_nodes
            if dep_nodes == nil then
                dep_nodes = {}
                depended_node.depending_nodes = dep_nodes
            end
            dep_nodes[node] = true
        end
        node.depended_nodes = depended_nodes
        task_nodes[node] = true
        self._depended_task_seq_dirty = true
    end

    self._task_count = self._task_count + 1
    return node
end

---@param self sia.scheduler
---@param task_nodes table<sia.scheduler.task_graph_node, boolean | integer>
---@param value boolean | integer
---@param node sia.scheduler.task_graph_node
local function raw_remove_task(self, task_nodes, value, node)
    if type(value) == "number" then
        -- orphan task
        local task_seq = self._orphan_task_seq
        local last_i = #task_seq

        if last_i == value then
            task_seq[last_i] = nil
            task_nodes[node] = nil
        else
            local last_node = task_seq[last_i]
            task_seq[value] = last_node
            task_seq[last_i] = nil

            task_nodes[node] = nil
            task_nodes[last_node] = value
        end
    else
        -- depending task
        for depended_node in pairs(node.depended_nodes) do
            local dep_nodes = depended_node.depending_nodes
            if dep_nodes == nil then
                error("cannot remove task: corrupted task graph")
            end
            dep_nodes[node] = nil
        end

        task_nodes[node] = nil
        self._depended_task_seq_dirty = true
    end
end

---@param node sia.scheduler.task_graph_node
function scheduler:remove_task(node)
    local task_nodes = self._task_graph_nodes
    local value = task_nodes[node]

    if value == nil or node.status == "removed" then
        error("cannot remove task: invalid task graph node")
    elseif node.depending_nodes ~= nil and #node.depending_nodes ~= 0 then
        error("cannot remove task: there are other tasks depending on it")
    end

    node.status = "removed"
    self._task_count = self._task_count - 1

    if self._ticking then
        local tasks_to_remove = self._tasks_to_remove
        tasks_to_remove[#tasks_to_remove + 1] = node
        return
    end

    raw_remove_task(self, task_nodes, value, node)
end

function scheduler:get_task_count()
    return self._task_count
end

---@param task_seq sia.scheduler.task_graph_node[]
---@param offset integer
---@param node sia.scheduler.task_graph_node
---@return integer
local function add_depended_tasks(task_seq, offset, node)
    local status = node.status
    if node.depended_nodes == nil or status == "added" then
        return 0
    elseif status == "adding" then
        error("failed to calculate task sequence: circular dependency found -> "..node)
    end
    node.status = "adding"

    local count = 0
    for dep_node in pairs(node.depended_nodes) do
        count = count + add_depended_tasks(task_seq, count + offset, dep_node)
    end

    count = count + 1
    task_seq[count + offset] = node
    node.status = "added"
    return count
end

function scheduler:tick()
    local orphan_task_seq = self._orphan_task_seq
    local depended_task_seq = self._depended_task_seq

    if self._depended_task_seq_dirty then
        local init_seq_len = #depended_task_seq
        local count = 0

        for node in pairs(self._task_graph_nodes) do
            count = count + add_depended_tasks(depended_task_seq, count, node)
        end

        for node in pairs(self._task_graph_nodes) do
            node.status = nil
        end

        if count < init_seq_len then
            for i = count + 1, init_seq_len do
                depended_task_seq[i] = nil
            end
        end

        self._depended_task_seq_dirty = false
    end

    local tasks_to_remove = self._tasks_to_remove
    self._ticking = true

    for i = 1, #orphan_task_seq do
        local node = orphan_task_seq[i]
        if node.callback() then
            tasks_to_remove[#tasks_to_remove+1] = node
        end
    end

    for i = 1, #depended_task_seq do
        local node = depended_task_seq[i]
        if node.callback() then
            tasks_to_remove[#tasks_to_remove+1] = node
        end
    end

    self._ticking = false

    for i = 1, #tasks_to_remove do
        local node = tasks_to_remove[i]
        if node.status ~= "removed" then
            local task_nodes = self._task_graph_nodes
            local value = task_nodes[node]
            raw_remove_task(self, task_nodes, value, node)
        end
        tasks_to_remove[i] = nil
    end
end

return scheduler