require "/scripts/util.lua"
require "/scripts/c5easing.lua"

-- Base gun fire ability
StarforgeGunFire = WeaponAbility:new()

function StarforgeGunFire:init()
  self.weapon:setStance(self.weapon.abilities[1].stances.idle)

  for part, state in pairs(self.pullOutAnimationStates or {}) do
    animator.setAnimationState(part, state)
  end

  self.cooldownTimer = self.fireTime
  
  self.unholster = self.stances.unholsterTwirl

  self.autoAltCounter = 0

  self.weapon.onLeaveAbility = self.weapon.onLeaveAbility or function()
    self.weapon:setStance(self.weapon.abilities[1].stances.idle)
    self:reset()
  end
end

function StarforgeGunFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  --[[self.speentimer = self.speentimer and (self.speentimer + dt) or 0
  local spinValue = math.sin(self.speentimer / 0.1)
  local extra = ""
  if spinValue < 0 then
    spinValue = spinValue * -1
    extra = "?flipx"
  end
  animator.setGlobalTag("speen", "?scalenearest=" .. spinValue .. ";1" .. extra)]]

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and (self.skipCollisionCheck or not world.lineTileCollision(mcontroller.position(), self:firePosition())) then

    if self.chargeTime then
      self:setState(self.charge)    
    elseif self.fireType == "auto" and status.overConsumeResource("energy", self:energyPerShot()) then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
  
  if self.remoteDetonateProjectile then
    if self.fireMode == "alt" and self.projectileId then
      if world.entityExists(self.projectileId) then
        world.callScriptedEntity(self.projectileId, "detonate")
      end
      self.projectileId = nil
    end
  end
  
  if self.unholster then
    self:setState(self.unholsterTwirl)
    self.unholster = nil
  end
end

function StarforgeGunFire:auto()
  self.weapon:setStance(self.stances.fire)

  if self.stances.fire.preDuration then
    util.wait(self.stances.fire.preDuration)
  end

  self.projectileId = self:fireProjectile()
  self:muzzleFlash()
  if self.knockbackForce then
    self:knockbackFire()
  end

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function StarforgeGunFire:unholsterTwirl()
  self.weapon:setStance(self.stances.unholsterTwirl)
  self.weapon:updateAim()

  animator.playSound("unholsterTwirl")
  
  local progress = 0
  util.wait(self.stances.unholsterTwirl.duration, function()
    local from = self.stances.unholsterTwirl.weaponOffset or {0,0}
    local to = self.weapon.abilities[1].stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {c5Easing.easeOut(progress, from[1], to[1]), c5Easing.easeOut(progress, from[2], to[2])}
	
    self.weapon.relativeWeaponRotation = util.toRadians(c5Easing.easeOut(progress, self.stances.unholsterTwirl.weaponRotation, self.weapon.abilities[1].stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(c5Easing.easeOut(progress, self.stances.unholsterTwirl.armRotation, self.weapon.abilities[1].stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.unholsterTwirl.duration))
  end)
  
  return
end

function StarforgeGunFire:charge()
  if animator.hasSound("chargeLoop") then
    animator.playSound("chargeLoop", -1)
  end

  if self.chargeAnimations then
    animator.setAnimationState("gun", "charge")
  end
  
  --Timer used for optional shaking
  local timer = 0

  if self.holdToCharge then
    --While charging, but not yet ready, count down the charge timer
    while (not self.autoFire or (timer < self.chargeTime)) and self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      timer = timer + self.dt

      self:chargeFunctions(timer)

      coroutine.yield()
    end
  else
    util.wait(self.chargeTime, function()
      timer = timer + self.dt

      self:chargeFunctions(timer)
    end)
  end
  if animator.hasSound("chargeLoop") then
    animator.stopAllSounds("chargeLoop")
  end
  
  if timer >= self.chargeTime and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    if self.fireType == "burst" then
      self:setState(self.burst)
    else
      self:setState(self.auto)
    end
  else
    self:reset()
  end
end

function StarforgeGunFire:chargeFunctions(timer)
  --Optional particle emitter
  if self.chargeParticleEmitter then
    animator.setParticleEmitterActive(self.stances.fire.particleEmitter, true)
  end

  --Prevent energy regen while charging
  status.setResourcePercentage("energyRegenBlock", 0.6)

  --Optionally update the charge intake particles
  if self.useChargeParticles then
    self:updateChargeIntake(timer)
  end
  
  --Enable walk while charging
  if self.walkWhileCharging == true then
    mcontroller.controlModifiers({runningSuppressed=true})
  end

  if self.chargeShake then
    local wavePeriod = (self.chargeShakeWavePeriod or 0.125) / (2 * math.pi) / (1 + (math.min(timer, self.chargeTime) * (self.chargeShakeFactor or 1)))
    local waveAmplitude = (self.chargeShakeWaveAmplitude or 0.075) * (1 + (math.min(timer, self.chargeTime) * (self.chargeShakeFactor or 1)))

    timer = timer + self.dt
    local rotation = waveAmplitude * math.sin(timer / wavePeriod)

    self.weapon.relativeArmRotation = (rotation * 0.5) + util.toRadians(self.weapon.abilities[1].stances.idle.armRotation) --Add weaponRotation again, as relativeWeaponRotation overwrites it
    self.weapon.relativeWeaponRotation = rotation + util.toRadians(self.weapon.abilities[1].stances.idle.weaponRotation)
  end

  status.overConsumeResource("energy", self:energyPerShot() * self.dt * (self.burstCount or 1))
end

function StarforgeGunFire:burst(charged)
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 and (charged or status.overConsumeResource("energy", self:energyPerShot())) do
    self.projectileId = self:fireProjectile(nil, nil, self.noBurstRecoil and 0 or (self.burstCount - shots))
    self:muzzleFlash()
    if self.knockbackForce then
      self:knockbackFire()
    end

    --Enable walk while firing
    if self.stances.fire.controlModifiers then
      mcontroller.controlModifiers(self.stances.fire.controlModifiers)
    end
	
    self.weapon.relativeWeaponRotation = util.toRadians(c5Easing.easeOut(1 - (shots / self.burstCount), self.weapon.abilities[1].stances.idle.weaponRotation, self.stances.cooldown.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(c5Easing.easeOut(1 - shots / self.burstCount, self.weapon.abilities[1].stances.idle.armRotation, self.stances.fire.armRotation))

    shots = shots - 1
    util.wait(self.burstTime)
  end

  self.cooldownTimer = self.fireTime + (self.burstTime * self.burstCount)
  self:setState(self.cooldown)
end

function StarforgeGunFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local duration = self.useStanceDuration and self.stances.cooldown.duration or (self.cooldownTimer * 0.9)
  local progress = 0
  --local maxRecoil = self.burstTime and 5 or 1;
  util.wait(duration, function()
    if self.stances.cooldown.controlModifiers then
      mcontroller.controlModifiers(self.stances.cooldown.controlModifiers)
    end

    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.weapon.abilities[1].stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {c5Easing.easeOut(progress, from[1], to[1]), c5Easing.easeOut(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(c5Easing.customEase(progress, self.stances.cooldown.weaponRotation, self.weapon.abilities[1].stances.idle.weaponRotation, 5.9, 1.15, 0.65, -0.024))
    self.weapon.relativeArmRotation = util.toRadians(c5Easing.easeOut(progress, self.stances.cooldown.armRotation, self.weapon.abilities[1].stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / duration))
  end)
  
  if self.autoAltInterval then
    self.autoAltCounter = self.autoAltCounter + 1
    if self.autoAltCounter >= self.autoAltInterval then
      triggerAlt(self.altHoldTime)
      self.autoAltCounter = 0
    end
  end

  self:reset()
end

function StarforgeGunFire:muzzleFlash(pitchIncrease)
  --Add normal pitch variance to shots
  local pitchVariance = ((self.pitchFactor or 1) + (self.pitchVariance or 0.15)) - (math.random() * ((self.pitchVariance or 0.15) * 2)) + (pitchIncrease or 0)
  animator.setSoundPitch("fire", pitchVariance)
  animator.playSound(self.fireSound or "fire")
  
  if self.muzzleFlashSuffix == "" then return end
  
  animator.setPartTag("muzzleFlash" .. (self.muzzleFlashSuffix or ""), "variant", math.random(1, self.muzzleFlashVariants or 3))
  animator.setAnimationState("firing", (self.muzzleFlashState or "fire") .. (self.muzzleFlashSuffix or ""))
  
  local flashString = self.muzzleFlashEmitter or ((self.useElementalMuzzleEmitter and self.weapon.elementalType ~= "physical") and (self.weapon.elementalType .. "MuzzleFlash") or "muzzleFlash")
  animator.burstParticleEmitter(flashString .. (self.muzzleFlashSuffix or ""))

  --Optional firing animations
  if self.animatedFire == true then
    if self.cycleAfterShot then
  	  if animator.animationState("gun") == "idle1" then
        animator.setAnimationState("gun", "transitionToIdle2")
      elseif animator.animationState("gun") == "idle2" then
        animator.setAnimationState("gun", "transitionToIdle1")
      end
    else
      animator.setAnimationState("gun", "reload")
    end
  end

  animator.setLightActive("muzzleFlash", true)
end

function StarforgeGunFire:knockbackFire()
  local momentum = vec2.mul(vec2.mul(self:aimVector(), self.knockbackForce), -1)
  if self.knockbackJump then
    mcontroller.controlJump()
  end
  mcontroller.addMomentum(momentum)
end

function StarforgeGunFire:fireProjectile(projectileType, params, burstNumber, position)
  local params = sb.jsonMerge(self.projectileParameters, params or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  
  local shotNumber = 0

  if self.consumeOnShot then
    for _, config in ipairs(self.consumeOnShot) do
      player.consumeItem({name = config.item, count = config.count or 1})
    end
  end

  local baseSpeed = params.speed
  if math.ceil(self.projectileCount) > 1 and not baseSpeed and (self.projectileSpeedVariance or config.getParameter("itemName") == "starforge-combatrifle") then -- im lazy lol
    local config = root.projectileConfig(self.projectileType)
    baseSpeed = {math.max(5, config.speed - 20), config.speed + 20}
  end
  local baseTTL = params.timeToLive
  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
      
    local projectileType = projectileType or self.projectileType
    if type(projectileType) == "table" then
      projectileType = projectileType[math.random(#projectileType)]
    end
    if baseTTL then
      params.timeToLive = util.randomInRange(baseTTL)
    end
    if baseSpeed then
      params.speed = util.randomInRange(baseSpeed)
    end
	
    shotNumber = i

    projectileId = world.spawnProjectile(
        projectileType,
        position or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy, shotNumber, burstNumber),
        self.trackSourceEntity or false,
        params
      )
  end
  return projectileId
end

function StarforgeGunFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(vec2.add(self.weapon.muzzleOffset, self.fireOffset or {0, 0})))
end

function StarforgeGunFire:aimVector(inaccuracy, shotNumber, burstNumber)
  local angleAdjustmentList = self.angleAdjustmentsPerShot or {}

  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy or 0, 0) + (angleAdjustmentList[shotNumber] or 0) + ((burstNumber or 0) * (util.toRadians(self.stances.fire.armRotation * (self.armRotationModifier or 0.15)))))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function StarforgeGunFire:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function StarforgeGunFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * (self.fireTime))) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function StarforgeGunFire:uninit()
  self:reset()
end

function StarforgeGunFire:reset()
  if animator.hasSound("chargeLoop") then
    animator.stopAllSounds("chargeLoop")
  end

  if self.chargeAnimations then
    animator.setAnimationState("gun", "idle")
  end
end