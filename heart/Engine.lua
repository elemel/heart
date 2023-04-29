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

function M:removeEvent(event)
  if not self._eventHandlers[event] then
    error("No such event: " .. event)
  end

  self._eventHandlers[event] = nil
end

function M:getEvents(events)
  events = events or {}

  for event in pairs(self._eventHandlers) do
    table.insert(events, event)
  end

  return events
end

function M:addEventHandler(event, handler, index)
  local handlers = self._eventHandlers[event]

  if not handlers then
    error("No such event: " .. event)
  end

  if index then
    table.insert(handlers, index, handler)
  else
    table.insert(handlers, handler)
  end
end

function M:removeEventHandler(event, index)
  local handlers = self._eventHandlers[event]

  if not handlers then
    error("No such event: " .. event)
  end

  return table.remove(handlers, index)
end

function M:getEventHandlers(event, handlers)
  local eventHandlers = self._eventHandlers[event]

  if not eventHandlers then
    error("No such event: " .. event)
  end

  handlers = handlers or {}

  for _, handler in ipairs(eventHandlers) do
    table.insert(handlers, handler)
  end

  return handlers
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
