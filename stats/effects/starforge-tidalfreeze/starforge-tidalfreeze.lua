require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  animator.setParticleEmitterOffsetRegion("decay", mcontroller.boundBox())
  animator.setParticleEmitterActive("decay", true)
  effect.setParentDirectives(config.getParameter("directive"))

  local boundBox = mcontroller.boundBox()
  self.entitySize = 1
  for i, coord in ipairs(boundBox) do
    if coord > self.entitySize then
      self.entitySize = coord
    end
  end
  self.maximumFrost = self.entitySize / config.getParameter("sizeToFrostFactor", 1)
  self.minimumFrost = config.getParameter("minimumFrostCount", 3)

  self.frostProjectileType = config.getParameter("frostProjectileType", "standardbullet")
  self.timeBetweenFrost = config.getParameter("timeBetweenFrost", {1, 2})
  self.speedMultiplierLostPerFrost = config.getParameter("speedMultiplierLostPerFrost", 0.05)
  self.frostTimer = randomFloat(self.timeBetweenFrost) * 0.5

  self.heatGainScale = config.getParameter("heatGainScale", 0.5)
  self.heatDecayRate = config.getParameter("heatDecayRate", 2.0)
  self.heatThreshold = config.getParameter("heatThreshold", 20.0)
  self.heat = 0

  self.frostBreakCooldownTime = config.getParameter("frostBreakCooldown", 2.0)
  self.frostBreakCooldownTimer = 0

  self.shatterChanceOnHit = config.getParameter("shatterChanceOnHit", 0.25)
  self.shatterDamage = config.getParameter("shatterDamage", 6)
  self.lastHealth = status.resource("health")

  self.frost = {}

  animator.playSound("loop", -1)
end

function update(dt)
  local livingFrost = {}
  for _, frostId in ipairs(self.frost) do
    if world.entityExists(frostId) then
      table.insert(livingFrost, frostId)
    end
  end
  self.frost = livingFrost

  self.frostTimer = math.max(0, self.frostTimer - dt)
  if self.frostTimer == 0 and #self.frost < self.maximumFrost then
    createFrost(self.frostProjectileType)
    self.frostTimer = randomFloat(self.timeBetweenFrost)
  end

  local speedReduction = 1 - math.min(#self.frost * self.speedMultiplierLostPerFrost, 1.0)
  mcontroller.controlModifiers({
      groundMovementModifier = speedReduction,
      speedModifier = speedReduction,
      airJumpModifier = speedReduction
    })
    
  if #self.frost > self.minimumFrost then
    local xSpeed = math.abs(mcontroller.velocity()[1])
    self.heat = math.max(0, self.heat + (xSpeed * self.heatGainScale - self.heatDecayRate) * dt)

    self.frostBreakCooldownTimer = math.max(0, self.frostBreakCooldownTimer - dt)
    if self.heat >= self.heatThreshold and self.frostBreakCooldownTimer == 0 then
      local breakIndex = math.random(#self.frost)
      shatter(breakIndex)
      table.remove(self.frost, breakIndex)
      self.heat = 0
      self.frostBreakCooldownTimer = self.frostBreakCooldownTime
    end
  end

  local currentHealth = status.resource("health")
  if currentHealth < self.lastHealth and #self.frost > self.minimumFrost then
    if math.random() < self.shatterChanceOnHit then
      local breakIndex = math.random(#self.frost)
      shatter(breakIndex)
      table.remove(self.frost, breakIndex)
    end
  end
  self.lastHealth = currentHealth

  if not status.resourcePositive("health") then
    effect.setParentDirectives(config.getParameter("deathDirective"))
    shatter()
  end

  world.debugText("Frost: " .. #self.frost .. "/" .. self.maximumFrost, vec2.add(mcontroller.position(), {0, -1}), "yellow")
  world.debugText("Speed mult: " .. string.format("%.2f", 1.0 - speedReduction), vec2.add(mcontroller.position(), {0, -2}), "yellow")
  world.debugText("Heat: " .. string.format("%.1f", self.heat) .. "/" .. self.heatThreshold, vec2.add(mcontroller.position(), {0, -3}), "yellow")
end

function createFrost(frostType)
  local boundBox = mcontroller.boundBox()
  local sector = math.random(1, 4)
  local offset = {0, 0}

  if sector == 1 then
    offset = {math.random() * boundBox[1], math.random() * boundBox[2]}
  elseif sector == 2 then
    offset = {math.random() * boundBox[3], math.random() * boundBox[4]}
  elseif sector == 3 then
    offset = {math.random() * boundBox[1], math.random() * boundBox[4]}
  elseif sector == 4 then
    offset = {math.random() * boundBox[3], math.random() * boundBox[2]}
  end

  local projectileId = world.spawnProjectile(frostType, vec2.add(mcontroller.position(), offset), entity.id(), vec2.rotate({1, 0}, math.random() * math.pi * 2), true)
  world.callScriptedEntity(projectileId, "setParentEntity", entity.id())

  table.insert(self.frost, projectileId)
end

function shatter(index)
  if index and self.frost[index] then
    if world.entityExists(self.frost[index]) then
      status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = self.shatterDamage * 0.5,
        damageSourceKind = "starforge-tidalfrost",
        sourceEntityId = entity.id()
      })
      world.callScriptedEntity(self.frost[index], "blossom")
    end
  else
    for _, frostId in ipairs(self.frost) do
      if world.entityExists(frostId) then
        world.callScriptedEntity(frostId, "blossom")
      end
    end
  end
end

function randomFloat(range)
  return math.random() * (range[2] - range[1]) + range[1]
end

function uninit()
  status.clearPersistentEffects("frostSlow")
  local totalDamage = 0
  for _, frostId in ipairs(self.frost) do
    if world.entityExists(frostId) then
      totalDamage = totalDamage + self.shatterDamage
      world.callScriptedEntity(frostId, "kill")
    end
  end  
  if totalDamage > 0 then
    status.applySelfDamageRequest({
      damageType = "IgnoresDef",
      damage = totalDamage,
      damageSourceKind = "starforge-tidalfrost",
      sourceEntityId = entity.id()
    })
  end
end

--/spawnitem antidote 1 '{"description":"Use this to test a status effect.","shortdescription":"Test Potion","maxstack":100,"effects":[["starforge-tidalfreeze"]]}'