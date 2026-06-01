require "/scripts/util.lua"
require "/scripts/c5easing.lua"

-- Made by neb, supports many barrels

-- Base gun fire ability
StarForgeMultiBarrelFire = WeaponAbility:new()

function StarForgeMultiBarrelFire:init()
  self.weapon:setStance(self.weapon.abilities[1].stances.idle)

  self.cooldownTimer = self.fireTime
  
  self.unholster = self.stances.unholsterTwirl
  
  self.firePositions = self.muzzleOffsets
	
  self.barrelIndex = 0
  
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.weapon.abilities[1].stances.idle)
  end
end

function StarForgeMultiBarrelFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  for _, currentPos in ipairs(self.firePositions) do
    world.debugPoint(vec2.add(mcontroller.position(), activeItem.handPosition(currentPos)), "orange")
  end
  
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition(1)) then

    if self.fireType == "auto" and status.overConsumeResource("energy", self:energyPerShot()) then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
  
  if self.unholster then
    self:setState(self.unholsterTwirl)
	self.unholster = nil
  end
end

function StarForgeMultiBarrelFire:auto()
  self.weapon:setStance(self.stances.fire)

  self:fireProjectile()
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function StarForgeMultiBarrelFire:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 and status.overConsumeResource("energy", self:energyPerShot()) do
    self:fireProjectile()
    self:muzzleFlash()
    shots = shots - 1
	
    self.weapon.relativeWeaponRotation = util.toRadians(c5Easing.easeOut(1 - (shots / self.burstCount), 0, self.burstCount))
    self.weapon.relativeArmRotation = util.toRadians(c5Easing.easeOut(1 - shots / self.burstCount, self.weapon.abilities[1].stances.idle.armRotation, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
  self:setState(self.cooldown)
end

function StarForgeMultiBarrelFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local duration = self.useStanceDuration and self.stances.cooldown.duration or (self.cooldownTimer * 0.9)
  local progress = 0
  --local maxRecoil = self.burstTime and 5 or 1;
  util.wait(duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.weapon.abilities[1].stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {c5Easing.easeOut(progress, from[1], to[1]), c5Easing.easeOut(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(c5Easing.customEase(progress, self.stances.cooldown.weaponRotation, self.weapon.abilities[1].stances.idle.weaponRotation, 5.9, 1.15, 0.65, -0.024))
    self.weapon.relativeArmRotation = util.toRadians(c5Easing.easeOut(progress, self.stances.cooldown.armRotation, self.weapon.abilities[1].stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / duration))
  end)
end

function StarForgeMultiBarrelFire:unholsterTwirl()
  self.weapon:setStance(self.stances.unholsterTwirl)
  self.weapon:updateAim()

  animator.playSound("unholsterTwirl")
  
  local progress = 0
  util.wait(self.stances.unholsterTwirl.duration, function()
    local from = self.stances.unholsterTwirl.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {util.interpolateHalfSigmoid(progress, from[1], to[1]), util.interpolateHalfSigmoid(progress, from[2], to[2])}
	
	self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateHalfSigmoid(progress, self.stances.unholsterTwirl.weaponRotation, self.stances.idle.weaponRotation))
	self.weapon.relativeArmRotation = util.toRadians(util.interpolateHalfSigmoid(progress, self.stances.unholsterTwirl.armRotation, self.stances.idle.armRotation))

	progress = math.min(1.0, progress + (self.dt / self.stances.unholsterTwirl.duration))
  end)
  
  return
end

function StarForgeMultiBarrelFire:muzzleFlash()
  --Add normal pitch variance to shots
  local pitchVariance = (1 + (self.pitchVariance or 0.15)) - (math.random() * ((self.pitchVariance or 0.15) * 2))
  animator.setSoundPitch("fire", pitchVariance)
  animator.playSound("fire")
  
  animator.setPartTag("muzzleFlash" .. self.barrelIndex + 1 .. (self.muzzleFlashSuffix or ""), "variant", math.random(1, self.muzzleFlashVariants or 3))
  animator.setAnimationState("firing", "fire" .. (self.muzzleFlashSuffix or ""))
  
  local flashString = (self.useElementalMuzzleEmitter and self.weapon.elementalType ~= "physical") and (self.weapon.elementalType .. "MuzzleFlash") or "muzzleFlash"
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

function StarForgeMultiBarrelFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)
  
  local projectileTypePerBarrel = copy(self.projectileTypePerBarrel)
  local previousProjectile
  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

	-- Determine if it fires multiple projectiles at once
	if projectileTypePerBarrel then
	  projectileType = projectileTypePerBarrel[i]
	  params.barrel = self.fireAllProjectileCount and self.barrelIndex + i or self.barrelIndex
	elseif not projectileType then
	  projectileType = self.projectileType
	end
	
	-- Find random projectile
	if type(projectileType) == "table" then
	  if self.preventIdenticalProjectiles and type(previousProjectile) == "string" then
	    self:removeValue(previousProjectile, projectileType)
	  end
	  projectileType = projectileType[math.random(#projectileType)]
	  previousProjectile = projectileType
	end
	
    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(self.fireAllProjectileCount and i or 1),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
	
	if self.muzzleFlashKeys then
	  local key = self.muzzleFlashKeys[projectileType]
      animator.setPartTag("muzzleFlash" .. i, "muzzleFlashKey", key)
	  animator.setPartTag("muzzleFlash" .. i, "variant", math.random(1, 3))
	else
	  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
    end
  end
  
  self.barrelIndex = self.barrelIndex + (self.fireAllProjectileCount and self.projectileCount or 1)
  if self.barrelIndex >= #self.firePositions then
	self.barrelIndex = 0
  end
  return projectileId
end

function StarForgeMultiBarrelFire:removeValue(value, filteredTable)
  for x, tableValue in ipairs(filteredTable) do
	if tableValue == value then
	  table.remove(filteredTable, x)
	end
  end
end

function StarForgeMultiBarrelFire:firePosition(barrel)
  --Code for alternating barrels/muzzle positions
  local currentBarrel = barrel + self.barrelIndex
  currentFirePosition = self.firePositions[currentBarrel]
	
  return vec2.add(mcontroller.position(), activeItem.handPosition(currentFirePosition))
end

function StarForgeMultiBarrelFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function StarForgeMultiBarrelFire:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function StarForgeMultiBarrelFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function StarForgeMultiBarrelFire:uninit()
end
