---@class command
---@field private _executor command.executor
---@operator call(command.executor): command
local command = {}

---@alias command.executor fun(...)

command.__index = command
setmetatable(command, {
    __call = function(self, executor)
        local instance = setmetatable({}, self)
        instance.__index = instance
        instance._executor = executor
        return instance
    end
})

function command:__call(...)
    return setmetatable({...}, self)
end

function command:execute(...)
    self:_executor(...)
end

function command:static_execute(cmd_data, ...)
    self._executor(cmd_data, ...)
end

command.callback = command(function(cmd, ...)
    cmd[1](...)
end)

command.sequence = command(function(cmd, ...)
    for i = 1, #cmd do
        cmd[i]:execute(...)
    end
end)

return command