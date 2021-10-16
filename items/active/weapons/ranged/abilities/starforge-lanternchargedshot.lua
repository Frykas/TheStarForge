require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Charged primary ability
StarforgeLanternChargedShot = WeaponAbility:new()

function StarforgeLanternChargedShot:init()

  self.chargeTimer = self.chargeTime
  self.cooldownTimer = 0
  self.currentRotation = 0
  self.graceTime = 0
  self.rotationMemory = self.currentRotation
  self.shakeDirection = 1
  
  self.lastBaseFactor = vec2.norm(mcontroller.velocity())
  
  self.chargeHasStarted = false
  self.shouldDischarge = false
  
  --Optional animation set-up
  if self.activeAnimation then
	animator.setAnimationState("gun", "idle")
  end

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function StarforgeLanternChargedShot:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  --Lantern jingle  
  self.graceTime = math.min(math.pi/2, self.graceTime)
  self.graceTime = math.max(0, self.graceTime - self.dt)
  
  local baseFactor = vec2.norm(mcontroller.velocity())
  local targetRotation = baseFactor[1] * -0.75 * mcontroller.facingDirection()
  
  if self.graceTime > 0 then
    targetRotation = ((self.graceTime * 0.5) * math.sin(self.graceTime * (self.shakeVelocity))) * self.shakeDirection
  end
  
  self.currentRotation = self.rotationMemory + (targetRotation - self.rotationMemory) * (self.dt * 7)
  self.rotationMemory = self.currentRotation
  
  animator.resetTransformationGroup("lantern")
  animator.rotateTransformationGroup("lantern", self.currentRotation, {-0.125, -0.5})
  
  if mcontroller.running() or mcontroller.walking() then
    self.graceTime = 0
  end
  
  if not mcontroller.running() and not mcontroller.walking() and self.lastBaseFactor[1] ~= 0 and (math.abs(self.currentRotation - self.rotationMemory) < math.pi / 5 or math.abs(self.currentRotation - self.rotationMemory) > -0.05) and self.graceTime == 0 then
	self.graceTime = 2 * math.pi / self.shakeVelocity
	self.shakeDirection = -baseFactor[1] * mcontroller.facingDirection()
  end
  
  self.lastBaseFactor = baseFactor
  
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --world.debugText("Projectile Type Primary: " .. sb.print(self.projectileType), vec2.add(mcontroller.position(), {0,2}), "yellow")

  --If holding fire, and nothing is holding back the charging process
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
	and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
	and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    self:setState(self.charge)
  --If the charge was prematurely stopped or interrupted somehow
  elseif self.chargeHasStarted == true and (self.fireMode ~= (self.activatingFireMode or self.abilitySlot) or world.lineTileCollision(mcontroller.position(), self:firePosition())) then
    animator.stopAllSounds("chargeLoop")
	animator.setAnimationState("charge", "off")
	animator.setParticleEmitterActive("chargeparticles", false)
	self.chargeTimer = self.chargeTime
  end
  
  --Optional animation while firing
  if self.activeAnimation then
	if self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and animator.animationState("gun") == "idle" then
	  animator.setAnimationState("gun", "activate")
	elseif (self.fireMode ~= (self.activatingFireMode or self.abilitySlot) or self.cooldownTimer > 0) and animator.animationState("gun") == "active" then
	  animator.setAnimationState("gun", "deactivate")
	end
  end
end

function StarforgeLanternChargedShot:charge()
  self.weapon:setStance(self.stances.charge)
  
  self.chargeHasStarted = true

  animator.playSound("chargeLoop", -1)
  animator.setAnimationState("charge", "charging")
  animator.setParticleEmitterActive("chargeparticles", true)
  
  --While charging, but not yet ready, count down the charge timer
  while self.chargeTimer > 0 and self.fireMode == (self.activatingFireMode or self.abilitySlot) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) do
    self.chargeTimer = math.max(0, self.chargeTimer - self.dt)

	--Prevent energy regen while charging
	status.setResourcePercentage("energyRegenBlock", 0.6)
	
	--Enable walk while firing
	if self.walkWhileFiring == true then
      mcontroller.controlModifiers({runningSuppressed=true})
	end

    coroutine.yield()
  end
  
  --If the charge is ready, we have line of sight and plenty of energy, go to firing state
  if self.chargeTimer == 0 and status.overConsumeResource("energy", self:energyPerShot()) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
	self:setState(self.fire)
  --If not charging and charge isn't ready, go to cooldown
  else
    self.shouldDischarge = true
	animator.playSound("discharge")
    self:setState(self.cooldown)
  end
end

function StarforgeLanternChargedShot:fire()
  self.weapon:setStance(self.stances.fire)
  
  animator.stopAllSounds("chargeLoop")
  animator.setAnimationState("charge", "off")
  animator.setParticleEmitterActive("chargeparticles", false)
  
  self.chargeHasStarted = false
  
  --Fire a projectile and show a muzzleflash, then continue on with this state
  self:fireProjectile()
  self:muzzleFlash()
  
  --Optionally play a firing animation
  if self.singleFireAnimation then
	animator.setAnimationState("gun", "active")
  end
  
  --Optionally apply self-damage
  if self.selfDamage then
	status.applySelfDamageRequest({
	  damageType = "IgnoresDef",
	  damage = math.max(1, self.selfDamage * config.getParameter("damageLevelMultiplier") * activeItem.ownerPowerMultiplier()),
	  damageSourceKind = self.selfDamageSource,
	  sourceEntityId = activeItem.ownerEntityId()
	})
  end
  
  if self.recoilKnockbackVelocity then
	--If not crouching or if crouch does not impact recoil
	if not (self.crouchStopsRecoil and mcontroller.crouching()) then
	  local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.recoilKnockbackVelocity)
	  --If aiming down and not in zero G, reset Y velocity first to allow for breaking of falls
	  if (self.weapon.aimAngle <= 0 and not mcontroller.zeroG()) then
		mcontroller.setYVelocity(0)
	  end
	  mcontroller.addMomentum(recoilVelocity)
	  mcontroller.controlJump()
	--If crouching
	elseif self.crouchRecoilKnockbackVelocity then
	  local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.crouchRecoilKnockbackVelocity)
	  mcontroller.setYVelocity(0)
	  mcontroller.addMomentum(recoilVelocity)
	end
  end

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.chargeTimer = self.chargeTime
  
  self.cooldownTimer = self.cooldownTime
  self:setState(self.cooldown)
end

function StarforgeLanternChargedShot:fireProjectile(burstNumber)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  local projectileType = self.projectileType
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end
  
  local shotNumber = 0

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    self.graceTime = 3 * math.pi / self.shakeVelocity
	self.shakeDirection = -1
	
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end
	
	shotNumber = i

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(self.inaccuracy, shotNumber, burstNumber),
        false,
        params
      )
	
	--If the ability config has this set to true, then the projectile fired will align with the player's aimVector shortly after being fired (as in the Rocket Burst ability) 
	if self.alignProjectiles then
	  world.callScriptedEntity(projectileId, "setApproach", self:aimVector(0, 1))
	end
  end
  
  return projectileId
end

function StarforgeLanternChargedShot:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  if self.casingEjectParticles then
	animator.burstParticleEmitter("casingEject")
  end
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function StarforgeLanternChargedShot:cooldown()
  if self.shouldDischarge == true then
    self.weapon:updateAim()
	self.weapon:setStance(self.stances.discharge)
	self.shouldDischarge = false
	
	local progress = 0
    util.wait(self.stances.discharge.duration, function()
      local from = self.stances.discharge.weaponOffset or {0,0}
      local to = self.stances.idle.weaponOffset or {0,0}
      self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.discharge.weaponRotation, self.stances.idle.weaponRotation))
      self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.discharge.armRotation, self.stances.idle.armRotation))

      progress = math.min(1.0, progress + (self.dt / self.stances.discharge.duration))
    end)
  else
    self.weapon:updateAim()
	self.weapon:setStance(self.stances.cooldown)
	
    local progress = 0
    util.wait(self.stances.cooldown.duration, function()
      local from = self.stances.cooldown.weaponOffset or {0,0}
      local to = self.stances.idle.weaponOffset or {0,0}
      self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
      self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

      progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
    end)
  end
end

function StarforgeLanternChargedShot:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function StarforgeLanternChargedShot:aimVector(inaccuracy, shotNumber, burstNumber)
  local angleAdjustmentList = self.angleAdjustmentsPerShot or {}
  local aimVector = {}
  
  if self.allowIndependantAim then
	local aimAngle, aimDirection = activeItem.aimAngleAndDirection(self.weapon.aimOffset, activeItem.ownerAimPosition())
	aimVector = vec2.rotate({1, 0}, aimAngle + sb.nrand(inaccuracy or 0, 0) + (angleAdjustmentList[shotNumber] or 0) + ((burstNumber or 0) * (self.burstRiseAngle or 0)))
  else
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy or 0, 0) + (angleAdjustmentList[shotNumber] or 0) + ((burstNumber or 0) * (self.burstRiseAngle or 0)))
  end
  
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

function StarforgeLanternChargedShot:energyPerShot()
  if self.fireType == "burst" then
	return self.baseEnergyUsage * (self.energyUsageMultiplier or 1.0) / self.burstCount
  else
	return self.baseEnergyUsage * (self.energyUsageMultiplier or 1.0)
  end
end

function StarforgeLanternChargedShot:damagePerShot()
  if self.fireType == "burst" then
	return self.baseDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount / self.burstCount
  else
	return self.baseDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
  end
end

function StarforgeLanternChargedShot:uninit()
  self:reset()
end

function StarforgeLanternChargedShot:reset()
  animator.setAnimationState("charge", "off")
  animator.setParticleEmitterActive("chargeparticles", false)
  self.chargeHasStarted = false
  self.weapon:setStance(self.stances.idle)
end