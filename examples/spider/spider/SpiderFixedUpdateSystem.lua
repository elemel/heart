local heart = require("heart")

local clamp = heart.math.clamp
local distance2 = heart.math.distance2

local M = heart.class.newClass()

function M:init(engine, config)
  self.engine = assert(engine)
end

function M:handleEvent(dt)
  local epsilon = 0.01
  local world = self.engine.domains.physics.world
  local bodies = self.engine.domains.physics.bodies
  local distanceJoints = self.engine.domains.physics.distanceJoints
  local ropeJoints = self.engine.domains.physics.ropeJoints
  local transformComponents = self.engine.componentManagers.transform
  local spiderEntities = self.engine.componentEntitySets.spider
  local spiderComponents = self.engine.componentManagers.spider
  local parents = self.engine.entityParents

  local moveInputs = spiderComponents.moveInputs
  local jumpInputs = spiderComponents.jumpInputs
  local previousJumpInputs = spiderComponents.previousJumpInputs

  local footComponents = self.engine.componentManagers.foot
  local localJointNormals = footComponents.localJointNormals

  for spiderId in pairs(spiderEntities) do
    local spiderBody = bodies[spiderId]

    local dx = moveInputs[spiderId][1] * dt
    local dy = moveInputs[spiderId][2] * dt

    local footIds = self.engine:findDescendantComponents(spiderId, "foot")
    local jointCount = 0
    local maxLength = 2

    for _, footId in ipairs(footIds) do
      if distanceJoints[footId] then
        jointCount = jointCount + 1
      end
    end

    if jumpInputs[spiderId] and jointCount >= 1 then
      local threadBodyId = nil

      local threadAnchorX = 0
      local threadAnchorY = 0

      local jumpDirectionX = 0
      local jumpDirectionY = 0

      for _, footId in ipairs(footIds) do
        if distanceJoints[footId] then
          local body1, body2 = distanceJoints[footId]:getBodies()
          local anchorX1, anchorY1, anchorX2, anchorY2 = distanceJoints[footId]:getAnchors()

          threadBodyId = body2:getUserData()

          threadAnchorX = anchorX2
          threadAnchorY = anchorY2

          local localNormal = localJointNormals[footId]
          jumpDirectionX, jumpDirectionY = body2:getWorldVector(localNormal[1], localNormal[2])

          self.engine:destroyComponent(footId, "distanceJoint")
          transformComponents:setMode(footId, "local")
          jointCount = jointCount - 1
        end
      end

      local spiderTransform = transformComponents:getTransform(spiderId)
      threadAnchorX, threadAnchorY = spiderTransform:inverseTransformPoint(threadAnchorX, threadAnchorY)

      spiderBody:applyLinearImpulse(16 * jumpDirectionX, 16 * jumpDirectionY - 16)

      self.engine:createComponent(spiderId, "ropeJoint", {
        body1 = spiderId,
        body2 = threadBodyId,

        x1 = 0,
        y1 = 0.75 + 0.375,

        x2 = threadAnchorX,
        y2 = threadAnchorY,

        collideConnected = true,
        maxLength = 16,
      })
    end

    for _, footId in ipairs(footIds) do
      if distanceJoints[footId] then
        local x1, y1, x2, y2 = distanceJoints[footId]:getAnchors()
        local _, oldTargetBody = distanceJoints[footId]:getBodies()

        local directionX, directionY = heart.math.normalize2(x2 - x1, y2 - y1)

        local rayX2 = x1 + maxLength * directionX
        local rayY2 = y1 + maxLength * directionY

        local targetFixture = nil
        local targetX = 0
        local targetY = 0
        local targetNormalX = 0
        local targetNormalY = 0

        world:rayCast(
          x1, y1, rayX2, rayY2,

          function(fixture, x, y, normalX, normalY, fraction)
            if fixture:getBody() == spiderBody then
              return 1
            end

            targetFixture = fixture

            targetX = x
            targetY = y

            targetNormalX = normalX
            targetNormalY = normalY

            return fraction
          end)

        if not targetFixture or targetFixture:getBody() ~= oldTargetBody or heart.math.squaredDistance2(targetX, targetY, x2, y2) > epsilon * epsilon then
          if jointCount > 1 then
            self.engine:destroyComponent(footId, "distanceJoint")
            transformComponents:setMode(footId, "local")
            jointCount = jointCount - 1
          end
        end
      end

      if not jumpInputs[spiderId] and not distanceJoints[footId] then
        local legId = parents[footId]
        local legTransform = transformComponents:getTransform(legId)
        local x1, y1 = legTransform:getPosition()

        local angle = 2 * math.pi * love.math.random()

        local x2 = x1 + maxLength * math.cos(angle)
        local y2 = y1 + maxLength * math.sin(angle)

        local targetFixture = nil
        local targetX = 0
        local targetY = 0
        local targetNormalX = 0
        local targetNormalY = 0

        world:rayCast(
          x1, y1, x2, y2,

          function(fixture, x, y, normalX, normalY, fraction)
            if fixture:isSensor() or fixture:getBody() == spiderBody then
              return 1
            end

            targetFixture = fixture

            targetX = x
            targetY = y

            targetNormalX = normalX
            targetNormalY = normalY

            return fraction
          end)

        if targetFixture then
          local footTransform = transformComponents:getTransform(footId)
          local targetBody = targetFixture:getBody()
          local targetBodyId = targetBody:getUserData()
          local localX1, localY1 = footTransform:inverseTransformPoint(x1, y1)
          local x2, y2 = footTransform:inverseTransformPoint(targetX, targetY)

          self.engine:createComponent(footId, "distanceJoint", {
            body1 = spiderId,
            body2 = targetBodyId,

            x1 = localX1,
            y1 = localY1,

            x2 = x2,
            y2 = y2,

            collideConnected = true,
            frequency = 10,
            dampingRatio = 1,
          })

          jointCount = jointCount + 1
          local localNormal = localJointNormals[footId]
          localNormal[1], localNormal[2] = targetBody:getLocalVector(targetNormalX, targetNormalY)

          self.engine:destroyComponent(spiderId, "ropeJoint")
        end
      end
    end

    for _, footId in ipairs(footIds) do
      if distanceJoints[footId] then
        local x1, y1, x2, y2 = distanceJoints[footId]:getAnchors()

        local oldLength = heart.math.distance2(x1, y1, x2, y2)
        local newLength = heart.math.distance2(x1 + 8 * dx, y1 + 8 * dy, x2, y2)
        local length = distanceJoints[footId]:getLength()

        length = length + newLength - oldLength
        length = math.max(length, 0.25)

        if length < maxLength then
          distanceJoints[footId]:setLength(length)
          bodies[spiderId]:setAwake(true)
        elseif jointCount > 1 then
          self.engine:destroyComponent(footId, "distanceJoint")
          transformComponents:setMode(footId, "local")
          jointCount = jointCount - 1
        else
          distanceJoints[footId]:setLength(maxLength)
          bodies[spiderId]:setAwake(true)
        end
      end
    end

    if ropeJoints[spiderId] then
      if jumpInputs[spiderId] and not previousJumpInputs[spiderId] then
        ropeJoints[spiderId]:setMaxLength(16)
      end

      if not jumpInputs[spiderId] and previousJumpInputs[spiderId] then
        local x1, y1, x2, y2 = ropeJoints[spiderId]:getAnchors()
        ropeJoints[spiderId]:setMaxLength(distance2(x1, y1, x2, y2))
      end

      if not jumpInputs[spiderId] then
        local x1, y1, x2, y2 = ropeJoints[spiderId]:getAnchors()

        local oldLength = heart.math.distance2(x1, y1, x2, y2)
        local newLength = heart.math.distance2(x1 + 4 * dx, y1 + 4 * dy, x2, y2)
        local length = ropeJoints[spiderId]:getMaxLength()

        length = length + newLength - oldLength
        length = clamp(length, 0.25, 16)

        ropeJoints[spiderId]:setMaxLength(length)
      end
    end
  end
end

return M
