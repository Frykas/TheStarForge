-- Melee primary ability
StarforgeWarpCombo = WeaponAbility:new()

function StarforgeWarpCombo:init()
  self.comboStep = 1

  self.energyUsage = self.energyUsage or 0

  self:computeDamageAndCooldowns()

  self.weapon:setStance(self.stances.idle)

  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.cooldownTimer = self.cooldowns[1]

  self.animKeyPrefix = self.animKeyPrefix or ""

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function StarforgeWarpCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
      self:readyFlash()
    end
  end
  world.debugText(self.cooldownTimer, vec2.add(mcontroller.position(), {0, 1}), "red")

  if self.flashTimer > 0 then
    self.flashTimer = math.max(0, self.flashTimer - self.dt)
    if self.flashTimer == 0 then
      animator.setGlobalTag("bladeDirectives", "")
    end
  end

  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) and fireMode == (self.activatingFireMode or self.abilitySlot) then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  if not self.weapon.currentAbility and self:shouldActivate() then
    self:setState(self.windup)
  end
end

-- State: windup
function StarforgeWarpCombo:windup()
  local stance = self.stances["windup"..self.comboStep]

  animator.setGlobalTag("stanceDirectives", stance.directives or "")
  self.weapon:setStance(stance)

  if stance.teleport then
    local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
    animator.setAnimationState("swoosh", animStateKey)
    animator.playSound(animStateKey)

    local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
    animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  end
  
  self.edgeTriggerTimer = 0
  
  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(stance.duration)
  end
  animator.setGlobalTag("stanceDirectives", "")

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end
  
  if stance.teleport then
    self:setState(self.teleport)
  elseif self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- waiting for next combo input
function StarforgeWarpCombo:teleport()
  local stance = self.stances["fire"..self.comboStep]
  
  --Create the teleportation effect and add 0.5 for both animations to take effect
  status.addEphemeralEffect(stance.teleportStatus or "starforge-teleporteffect", stance.duration + 0.5)

  animator.setGlobalTag("stanceDirectives", stance.directives or "")
  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local oldPosition = mcontroller.position()
  local targetPosition = vec2.add(oldPosition, vec2.rotate({mcontroller.facingDirection() * stance.teleportTarget[1], stance.teleportTarget[2]}, self.weapon.aimAngle * mcontroller.facingDirection()))

  local groundCollision = world.lineTileCollisionPoint(mcontroller.position(), targetPosition)
  if groundCollision then
    local groundPos, normal = groundCollision[1], groundCollision[2]
    targetPosition = groundPos
  end
	
  local targets = world.entityQuery(mcontroller.position(), stance.forgivenessRange, {
    withoutEntityId = activeItem.ownerEntityId(),
    includedTypes = {"creature"},
    order = "nearest"
  })
  if targets[1] and entity.entityInSight(targets[1]) and world.entityCanDamage(activeItem.ownerEntityId(), targets[1]) then
	targetPosition = world.entityPosition(targets[1])
  end
  world.resolvePolyCollision(mcontroller.collisionPoly(), vec2.add(targetPosition, stance.teleportOffset), stance.teleportTolerance)

  --Allow first teleport effect to take place
  util.wait(0.25)
  
  if stance.projectileType and targetPosition then
	local angleToTarget = vec2.angle({targetPosition[2] - mcontroller.position()[2], targetPosition[1] - mcontroller.position()[1]})
	local aimVector = vec2.rotate({0, 1}, -angleToTarget)
	--aimVector[1] = aimVector[1] * mcontroller.facingDirection()
	
	local params = stance.projectileParameters or {}
	params.power = stance.projectileDamage * config.getParameter("damageLevelMultiplier")
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
	params.speed = util.randomInRange(params.speed)
		
    world.spawnProjectile(
	  stance.projectileType,
	  targetPosition,
	  activeItem.ownerEntityId(),
	  aimVector,
	  false,
	  params
	)
  end
  
  util.wait(stance.duration, function()
	--Reset player momentum, prevents fall damage
	mcontroller.setXVelocity(0, 0)
	mcontroller.setYVelocity(0, 0)
	mcontroller.setPosition(targetPosition)
  end)
  animator.setGlobalTag("stanceDirectives", "")
  
  mcontroller.setPosition(oldPosition)

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
  end
end

function StarforgeWarpCombo:wait()
  local stance = self.stances["wait"..(self.comboStep - 1)]

  animator.setGlobalTag("stanceDirectives", stance.directives or "")
  self.weapon:setStance(stance)

  util.wait(stance.duration, function()
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)
  animator.setGlobalTag("stanceDirectives", "")

  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  self.comboStep = 1
end

-- State: preslash
-- brief frame in between windup and fire
function StarforgeWarpCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  animator.setGlobalTag("stanceDirectives", stance.directives or "")
  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)
  animator.setGlobalTag("stanceDirectives", "")

  self:setState(self.fire)
end

-- State: fire
function StarforgeWarpCombo:fire()
  local stance = self.stances["fire"..self.comboStep]

  animator.setGlobalTag("stanceDirectives", stance.directives or "")
  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)
  
  util.wait(stance.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
  end)
  animator.setGlobalTag("stanceDirectives", "")

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
  end
end

function StarforgeWarpCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function StarforgeWarpCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function StarforgeWarpCombo:computeDamageAndCooldowns()
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["fire"..i].duration
    if self.stances["preslash"..i] then
      attackTime = attackTime + self.stances["preslash"..i].duration
    end
    table.insert(attackTimes, attackTime)
  end

  self.cooldowns = {}
  local totalAttackTime = 0
  local totalDamageFactor = 0
  for i, attackTime in ipairs(attackTimes) do
    self.stepDamageConfig[i] = util.mergeTable(copy(self.damageConfig), self.stepDamageConfig[i])
    self.stepDamageConfig[i].timeoutGroup = "primary"..i

    local damageFactor = self.stepDamageConfig[i].baseDamageFactor
    self.stepDamageConfig[i].baseDamage = damageFactor * self.baseDps * self.fireTime

    totalAttackTime = totalAttackTime + attackTime
    totalDamageFactor = totalDamageFactor + damageFactor

    local targetTime = totalDamageFactor * self.fireTime
    local speedFactor = 1.0 * (self.comboSpeedFactor ^ i)
    table.insert(self.cooldowns, math.max(0.75, (targetTime - totalAttackTime) * speedFactor))
  end
end

function StarforgeWarpCombo:uninit()
  self.weapon:setDamage()
end
