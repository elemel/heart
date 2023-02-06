local Class = require("heart.Class")

local M = Class.new()

function M:init()
  self._properties = {}
  self._eventHandlers = {}
end

function M:getProperty(name)
  return self._properties[name]
end

function M:setProperty(name, value)
  self._properties[name] = value
end

function M:addEvent(event)
  if self._eventHandlers[event] then
    error("Duplicate event: " .. event)
  end

  self._eventHandlers[event] = {}
end

function M:addEventHandler(event, handler)
  local handlers = self._eventHandlers[event]

  if not handlers then
    error("No such event: " .. event)
  end

  table.insert(handlers, handler)
end

function M:handleEvent(event, ...)
  local handlers = self._eventHandlers[event]

  if not handlers then
    error("No such event: " .. event)
  end

  for _, handler in ipairs(handlers) do
    local result = handler(...)

    if result then
      return result
    end
  end

  return nil
end

return M
