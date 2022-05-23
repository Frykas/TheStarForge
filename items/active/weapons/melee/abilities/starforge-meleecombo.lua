-- Melee primary ability
StarforgeMeleeCombo = WeaponAbility:new()

function StarforgeMeleeCombo:init()
  self.comboStep = 1
  animator.setGlobalTag("comboDirectives", "")

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
function StarforgeMeleeCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
      self:readyFlash()
    end
  end

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
function StarforgeMeleeCombo:windup()
  local stance = self.stances["windup"..self.comboStep]
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")
  
  -- Optionally flash the weapon
  if stance.flashTime then
	self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end
  -- Optional Emotes
  if stance.emote then
	activeItem.emote(stance.emote)
  end

  self.weapon:setStance(stance)

  self.edgeTriggerTimer = 0

  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(stance.duration)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- waiting for next combo input
function StarforgeMeleeCombo:wait()
  local stance = self.stances["wait"..(self.comboStep - 1)]
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")
  
  -- Optionally flash the weapon
  if stance.flashTime then
	self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end
  -- Optional Emotes
  if stance.emote then
	activeItem.emote(stance.emote)
  end

  self.weapon:setStance(stance)

  util.wait(stance.duration, function()
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)

  animator.setGlobalTag("comboDirectives", "")
  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  self.comboStep = 1
end

-- State: preslash
-- brief frame in between windup and fire
function StarforgeMeleeCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(self.fire)
end

-- State: fire
function StarforgeMeleeCombo:fire()
  local stance = self.stances["fire"..self.comboStep]
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")
  
  -- Optionally flash the weapon
  if stance.flashTime then
	self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end
  -- Optional Emotes
  if stance.emote then
	activeItem.emote(stance.emote)
  end

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)

  -- If this step is configured as a "spin" move, spin the weapon
  if stance.spinRate then
	util.wait(stance.duration, function()
	  local damageArea = partDamageArea("swoosh")
	  self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
	
	  -- Remove the weapon from the player's hand, allowing it to rotate freely
	  activeItem.setOutsideOfHand(true)
	
	  -- Spin the weapon
	  self.weapon.relativeWeaponRotation = self.weapon.relativeWeaponRotation + util.toRadians(stance.spinRate * self.dt)
	
	  -- Optionally force the player to walk while in this stance
	  if stance.forceWalking then
		mcontroller.controlModifiers({runningSuppressed=true})
	  end
	  
	  -- Optionally freeze the player in place if so configured
	  if stance.freezePlayer then
		mcontroller.setVelocity({0,0})
	  end
	end)
	animator.setAnimationState("swoosh", "idle")
  -- If this step is a regular attack, simply set the damage area for the duration of the step
  else
	util.wait(stance.duration, function()
	  local damageArea = partDamageArea("swoosh")
	  self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
	  
	  --Optionally freeze the player in place if so configured
	  if stance.freezePlayer then
		mcontroller.setVelocity({0,0})
	  end
	end)
  end
  
  if stance.continueStep then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    animator.setGlobalTag("comboDirectives", "")
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
  end
end

function StarforgeMeleeCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function StarforgeMeleeCombo:animatedFlash(flashTime, flashDirectives)
  animator.setGlobalTag("bladeDirectives", flashDirectives)
  self.flashTimer = flashTime or self.flashTime
end

function StarforgeMeleeCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function StarforgeMeleeCombo:computeDamageAndCooldowns()
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
    table.insert(self.cooldowns, (targetTime - totalAttackTime) * speedFactor)
  end
end

function StarforgeMeleeCombo:uninit()
  self.weapon:setDamage()
end
