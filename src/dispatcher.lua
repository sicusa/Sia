---@class dispatcher
---@field package _listeners table<any, dispatcher.command_handler[]>
---@field package _sending boolean
---@operator call(): dispatcher
local dispatcher = {}

---@alias dispatcher.command_handler fun(command: any, ...)

dispatcher.__index = dispatcher
setmetatable(dispatcher, {
    __call = function()
        local instance = setmetatable({}, dispatcher)
        instance._listeners = {}
        instance._sending = false
        return instance
    end
})

---@param command any
---@param handler dispatcher.command_handler
function dispatcher:listen(command, handler)
    local ls = self._listeners[command]
    if ls == nil then
        ls = {}
        self._listeners[command] = ls
    end
    ls[#ls+1] = handler
end

---@param command any
---@param handler dispatcher.command_handler
---@return boolean
function dispatcher:unlistener(command, handler)
    if self._sending then
        error("cannot unlistener command while sending it")
    end
    local ls = self._listeners[command]
    if ls == nil then
        return false
    end
    for i = 1, #ls do
        if ls[i] == handler then
            ls[i] = ls[#ls]
            ls[#ls] = nil
            return true
        end
    end
    return false
end

---@param command any
function dispatcher:send(command, ...)
    local ls = self._listeners[command]
    if ls == nil then
        return
    end
    self._sending = true
    for i = 1, #ls do
        ls[i](command, ...)
    end
    self._sending = false
end

return dispatcher