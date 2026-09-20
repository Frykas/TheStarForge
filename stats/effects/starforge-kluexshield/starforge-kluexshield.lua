require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/status.lua"

function init()
  self.healthToShieldPercent = config.getParameter("healthToShieldPercent", {0.5, 5})
  self.playerHealthToShieldPercent = config.getParameter("playerHealthToShieldPercent", 0.25)
  self.brokenShieldRegenDelay = config.getParameter("brokenShieldRegenDelay", 5)
  self.shieldRegenDelay = config.getParameter("shieldRegenDelay", 0.25)
  self.shieldRegenDelayTimer = 0
  self.shieldRegenRate = config.getParameter("shieldRegenRate", 0.25)
  
  self.distanceFromEntity = config.getParameter("distanceFromEntity", {0, 1})
  self.transparency = config.getParameter("transparency", {0.3, 0.65})
  self.segmentOffsets = config.getParameter("segmentOffsets", {})

  activateShield()

  self.listener = damageListener("damageTaken", function(notifications)
    if not self.shieldActive then return end

    for _, notification in ipairs(notifications) do
      if notification.healthLost > 0 then
        damageShield(notification.healthLost)
      end
    end
  end)

  updateTransformationGroups()
  script.setUpdateDelta(1)
end

function update(dt)
  updateTransformationGroups()
  updateShield(dt)
  updateTransparency()
end

function uninit()
  reset()
end

function reset()
  self.shieldActive = false
  if self.statHandler then
    effect.removeStatModifierGroup(self.statHandler)
    self.statHandler = nil
  end
end

function damageShield(damage)
  if self.currentShieldHealth >= damage then
    self.currentShieldHealth = self.currentShieldHealth - damage
    status.modifyResource("health", damage)
    self.shieldRegenDelayTimer = self.shieldRegenDelay
    updateStatGroup()
  else
    local absorbed = self.currentShieldHealth
    self.currentShieldHealth = 0
    status.modifyResource("health", absorbed)
    self.shieldRegenDelayTimer = self.brokenShieldRegenDelay
    reset()
  end
end

function activateShield()
  local factor = world.threatLevel() / 10
  local shieldScale = self.healthToShieldPercent[1] + (self.healthToShieldPercent[2] - self.healthToShieldPercent[1]) * factor
  
  local baseMaxHealth = status.stat("maxHealth")
  self.shieldMaxHealth = baseMaxHealth * shieldScale
  self.currentShieldHealth = self.shieldMaxHealth

  updateStatGroup()
  self.shieldActive = true
end

function updateStatGroup()
  if self.statHandler then
    effect.removeStatModifierGroup(self.statHandler)
  end

  self.statHandler = effect.addStatModifierGroup({
    {stat = "grit", amount = 1.0},
    {stat = "maxHealth", amount = self.shieldMaxHealth},
    {stat = "starforge-shieldHealth", amount = self.currentShieldHealth}
  })
end

function updateShield(dt)
  if self.shieldActive then
    self.listener:update()
  end

  self.shieldRegenDelayTimer = math.max(self.shieldRegenDelayTimer - dt, 0)

  if self.shieldRegenDelayTimer == 0 then
    if not self.shieldActive then
      activateShield()
    end
    
    local regenAmount = self.shieldRegenRate * self.shieldMaxHealth * dt
    self.currentShieldHealth = math.min(self.currentShieldHealth + regenAmount, self.shieldMaxHealth)
    updateStatGroup()
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
  if not self.shieldMaxHealth or self.shieldMaxHealth == 0 then return 0 end
  return math.max(0, self.currentShieldHealth / self.shieldMaxHealth)
end

function updateTransparency()
  local alphaFactor = self.shieldActive and self.transparency[1] + (shieldHealthFactor() * (self.transparency[2] - self.transparency[1])) or 0

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