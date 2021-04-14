require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Made by neb, supports many barrels

-- Base gun fire ability
StarForgeMultiBarrelFire = WeaponAbility:new()

function StarForgeMultiBarrelFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  
  self.firePositions = self.muzzleOffsets
	
  self.barrelIndex = 0
  
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
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

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

function StarForgeMultiBarrelFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

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

function StarForgeMultiBarrelFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

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
