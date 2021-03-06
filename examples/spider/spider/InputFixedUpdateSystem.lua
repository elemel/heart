local heart = require("heart")

local M = heart.class.newClass()

function M:init(engine, config)
  self.engine = assert(engine)
end

function M:handleEvent(dt)
  local playerEntities = self.engine.componentEntitySets.player
  local spiderComponents = self.engine.componentManagers.spider

  local moveInputs = spiderComponents.moveInputs

  local previousJumpInputs = spiderComponents.previousJumpInputs
  local jumpInputs = spiderComponents.jumpInputs

  local upInput = love.keyboard.isDown("w")
  local leftInput = love.keyboard.isDown("a")
  local downInput = love.keyboard.isDown("s")
  local rightInput = love.keyboard.isDown("d")

  local jumpInput = love.keyboard.isDown("space")

  local inputX = (rightInput and 1 or 0) - (leftInput and 1 or 0)
  local inputY = (downInput and 1 or 0) - (upInput and 1 or 0)

  if inputX ~= 0 and inputY ~= 0 then
    inputX, inputY = heart.math.normalize2(inputX, inputY)
  end

  for id in pairs(playerEntities) do
    moveInputs[id][1] = inputX
    moveInputs[id][2] = inputY

    previousJumpInputs[id] = jumpInputs[id]
    jumpInputs[id] = jumpInput
  end
end

return M
