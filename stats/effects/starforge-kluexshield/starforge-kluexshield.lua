require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.healthToShieldPercent = config.getParameter("healthToShieldPercent", {0.5, 5})
  self.playerHealthToShieldPercent = config.getParameter("playerHealthToShieldPercent", 0.25)
  self.shieldRegenDelay = config.getParameter("shieldRegenDelay", 0.25)
  self.shieldRegenDelayTimer = 0
  self.shieldRegenRate = config.getParameter("shieldRegenRate", 0.25)
  
  self.distanceFromEntity = config.getParameter("distanceFromEntity", {0, 1})
  self.transparency = config.getParameter("transparency", {0.3, 0.65})
  self.segmentOffsets = config.getParameter("segmentOffsets", {})

  self.entityType = world.entityType(entity.id())
  self.shieldMaxHealth = activateShield()

  updateTransformationGroups()
  script.setUpdateDelta(1)
end

function update(dt)
  updateTransformationGroups()
  updateShield(dt)
  updateTransparency()
end

function uninit()
  status.clearPersistentEffects("starforge-kluexShield")
end

function activateShield()
  local factor = world.threatLevel() / 10
  local shieldScale = self.healthToShieldPercent[1] + (self.healthToShieldPercent[2] - self.healthToShieldPercent[1]) * factor
  local shieldMaxHealth = status.resourceMax("health") * shieldScale

  if self.entityType == "monster" or self.entityType == "npc" then
    --figure out how to handle this... should i add max hp? or something else...
  elseif self.entityType == "player" then
    shieldMaxHealth = self.playerHealthToShieldPercent * status.resourceMax("health")
    status.setResource("damageAbsorption", shieldMaxHealth)
  end

  return shieldMaxHealth
end

function updateShield(dt)
  self.shieldRegenDelayTimer = math.max(self.shieldRegenDelayTimer - dt, 0)

  if self.shieldRegenDelayTimer == 0 then
    local regenAmount = self.shieldRegenRate * self.shieldMaxHealth * dt
    if self.entityType == "monster" or self.entityType == "npc" then
      --figure out how to handle this
    elseif self.entityType == "player" and status.resourcePositive("damageAbsorption") then
      status.modifyResource("damageAbsorption", regenAmount)
    end
  end
end

function updateTransformationGroups()
  local bounds = entitySize()

  for transGroup, offset in pairs(self.segmentOffsets) do
    if vec2.mag(offset) > 0 then
      local direction = vec2.norm(offset)

      local extX = direction[1] >= 0 and bounds.right or bounds.left
      local extY = direction[2] >= 0 and bounds.up or bounds.down

      local entitySizeOffset = {
        direction[1] * extX,
        direction[2] * extY
      }

      local entityOffset = vec2.mul(direction, shieldHealthToOffset())
      local finalOffset = vec2.add(vec2.add(entityOffset, offset), entitySizeOffset)

      animator.resetTransformationGroup(transGroup)
      animator.translateTransformationGroup(transGroup, finalOffset)
    end
  end
end

function shieldHealthToOffset()
  local offsetCalculated = (self.distanceFromEntity[2] - self.distanceFromEntity[1]) * shieldHealthFactor()
  return offsetCalculated + self.distanceFromEntity[1]
end

function shieldHealthFactor()
  local factor = 1
  if self.entityType == "monster" and status.resourcePositive("shieldHealth") then
    factor = status.resource("shieldHealth") / self.shieldMaxHealth
  elseif self.entityType == "npc" and status.resourcePositive("shieldStamina") then
    factor = status.resource("shieldStamina")
  elseif self.entityType == "player" and status.resourcePositive("damageAbsorption") then
    factor = status.resource("damageAbsorption") / self.shieldMaxHealth
  end
  return factor
end

function updateTransparency()
  local alphaFactor = self.transparency[1] + (shieldHealthFactor() * (self.transparency[2] - self.transparency[1]))

  local alphaHex = string.format("%02X", math.floor(alphaFactor * 255 + 0.5))
  animator.setGlobalTag("transparency", "?multiply=FFFFFF" .. alphaHex)
end

function entitySize()
  local xMin, yMin, xMax, yMax = 0, 0, 0, 0
  for _, coord in ipairs(mcontroller.collisionPoly()) do
    xMin = math.min(xMin, coord[1])
    xMax = math.max(xMax, coord[1])
    yMin = math.min(yMin, coord[2])
    yMax = math.max(yMax, coord[2])
  end 

  return {
    left = math.abs(xMin),
    right = math.abs(xMax),
    down = math.abs(yMin),
    up = math.abs(yMax)
  }
end