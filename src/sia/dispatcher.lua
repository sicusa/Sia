---@class sia.dispatcher
---@field package _cmd_listeners table<any, sia.dispatcher.command_handler[]>
---@field package _sender_listeners table<any, sia.dispatcher.command_handler[]>
---@field package _sending boolean
---@field package _listeners_to_remove table<sia.dispatcher.command_handler>
---@overload fun(): sia.dispatcher
local dispatcher = {}

---@alias sia.dispatcher.command_handler fun(command: any, ...): any | nil

dispatcher.__index = dispatcher
setmetatable(dispatcher, {
    __call = function()
        local instance = setmetatable({}, dispatcher)
        instance._cmd_listeners = {}
        instance._sender_listeners = {}
        instance._sending = false
        return instance
    end
})

---@param listeners table<any, sia.dispatcher.command_handler[]>
---@param index any
---@param handler sia.dispatcher.command_handler
local function raw_listen(listeners, index, handler)
    local ls = listeners[index]
    if ls == nil then
        ls = {}
        listeners[index] = ls
    end
    ls[#ls+1] = handler
end

---@param listeners table<any, sia.dispatcher.command_handler[]>
---@param index any
---@param handler sia.dispatcher.command_handler
---@return boolean
local function raw_unlisten(listeners, index, handler)
    local ls = listeners[index]
    if ls == nil then
        return false
    end

    local found_i
    for i = 1, #ls do
        if ls[i] == handler then
            found_i = i
            break
        end
    end
    if found_i == nil then
        return false
    end

    local last_i = #ls
    if last_i == found_i then
        if last_i == 1 then
            listeners[index] = nil
        else
            ls[last_i] = nil
        end
    else
        ls[found_i] = ls[last_i]
        ls[last_i] = nil
    end
    
    return true
end

---@param command any
---@param handler sia.dispatcher.command_handler
function dispatcher:listen(command, handler)
    raw_listen(self._cmd_listeners, command, handler)
end

---@param command any
---@param handler sia.dispatcher.command_handler
---@return boolean
function dispatcher:unlisten(command, handler)
    if self._sending then
        error("cannot unlistener command while sending")
    end
    return raw_unlisten(self._cmd_listeners, command, handler)
end

---@param sender any
---@param handler sia.dispatcher.command_handler
function dispatcher:listen_on(sender, handler)
    raw_listen(self._sender_listeners, sender, handler)
end

---@param sender any
---@param handler sia.dispatcher.command_handler
---@return boolean
function dispatcher:unlisten_on(sender, handler)
    if self._sending then
        error("cannot unlisten sender while sending")
    end
    return raw_unlisten(self._sender_listeners, sender, handler)
end

---@param sender any
function dispatcher:clear_listeners_on(sender)
    self._sender_listeners[sender] = nil
end

---@param listeners sia.dispatcher.command_handler[]
---@param command any
---@param sender any
local function execute_listeners(listeners, command, sender, ...)
    local len = #listeners
    local i = 1
    while i <= len do
        while listeners[i](command, sender, ...) do
            listeners[i] = listeners[len]
            listeners[len] = nil
            len = len - 1
            if len < i then return end
        end
        i = i + 1
    end
end

---@param command any
---@param sender any
function dispatcher:send(command, sender, ...)
    self._sending = true

    local ls = self._cmd_listeners[command]
    if ls ~= nil then
        execute_listeners(ls, command, sender, ...)
    end

    ls = self._sender_listeners[sender]
    if ls ~= nil then
        execute_listeners(ls, command, sender, ...)
    end

    self._sending = false
end

return dispatcher