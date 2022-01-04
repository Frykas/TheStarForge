require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Base gun fire ability
StarforgeExecute = WeaponAbility:new()

function StarforgeExecute:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function StarforgeExecute:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
	
    self:setState(self.twirl)
  end
end

function StarforgeExecute:fire()
  self.weapon:setStance(self.stances.fire)

  self.projectileId = self:fireProjectile()
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function StarforgeExecute:twirl()
  self.weapon:setStance(self.stances.twirl)
  self.weapon:updateAim()
  
  animator.playSound("unholsterTwirl")
  
  local progress = 0
  util.wait(self.stances.twirl.duration, function()
    local from = self.stances.twirl.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {util.interpolateHalfSigmoid(progress, from[1], to[1]), util.interpolateHalfSigmoid(progress, from[2], to[2])}
	
	self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateHalfSigmoid(progress, self.stances.twirl.weaponRotation, self.stances.idle.weaponRotation))
	self.weapon.relativeArmRotation = util.toRadians(util.interpolateHalfSigmoid(progress, self.stances.twirl.armRotation, self.stances.idle.armRotation))

	progress = math.min(1.0, progress + (self.dt / self.stances.twirl.duration))
  end)
  
  if status.overConsumeResource("energy", self:energyPerShot()) then
    self:setState(self.fire)
  end
end

function StarforgeExecute:charge()
  if animator.hasSound("chargeLoop") then
    animator.playSound("chargeLoop", -1)
  end
  --Timer used for optional shaking
  local timer = 0
  util.wait(self.chargeTime, function()
	--Optional particle emitter
	if self.chargeParticleEmitter then
	  animator.setParticleEmitterActive(self.stances.fire.particleEmitter, true)
	  self.currentParticleEmitter = self.stances.fire.particleEmitter
	end
    if self.chargeShake then
	  local wavePeriod = (self.chargeShakeWavePeriod or 0.125) / (2 * math.pi) / (1 + (timer * (self.chargeShakeFactor or 1)))
	  local waveAmplitude = (self.chargeShakeWaveAmplitude or 0.075) * (1 + (timer * (self.chargeShakeFactor or 1)))
	
	  timer = timer + self.dt
	  local rotation = waveAmplitude * math.sin(timer / wavePeriod)
	
	  self.weapon.relativeArmRotation = rotation + util.toRadians(self.stances.idle.armRotation) --Add weaponRotation again, as relativeWeaponRotation overwrites it
    end
  end)
  animator.stopAllSounds("chargeLoop")
  
  if self.windDownAnimation then
    
  end
  
  self.weapon:setStance(self.stances.fire)

  self.projectileId = self:fireProjectile()
  self:muzzleFlash()

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function StarforgeExecute:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 and status.overConsumeResource("energy", self:energyPerShot()) do
    self.projectileId = self:fireProjectile()
    self:muzzleFlash()
    shots = shots - 1

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
  self:setState(self.cooldown)
end

function StarforgeExecute:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {util.interpolateHalfSigmoid(progress, from[1], to[1]), util.interpolateHalfSigmoid(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateHalfSigmoid(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(util.interpolateHalfSigmoid(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function StarforgeExecute:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, self.muzzleFlashVariants or 3))
  animator.setAnimationState("firing", "fire")
  
  animator.burstParticleEmitter("muzzleFlash")

  --Optional firing animations
  if self.animatedFire == true then
	if animator.animationState("gun") == "idle1" then
	  animator.setAnimationState("gun", "transitionToIdle2")
	elseif animator.animationState("gun") == "idle2" then
	  animator.setAnimationState("gun", "transitionToIdle1")
	end
  end
  
  --Add normal pitch variance to shots
  local pitchVariance = (1 + (self.pitchVariance or 0.15)) - (math.random() * ((self.pitchVariance or 0.15) * 2))
  animator.setSoundPitch("altFire", pitchVariance)
  animator.playSound("altFire")

  animator.setLightActive("muzzleFlash", true)
end

function StarforgeExecute:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function StarforgeExecute:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function StarforgeExecute:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function StarforgeExecute:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function StarforgeExecute:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function StarforgeExecute:uninit()
end
