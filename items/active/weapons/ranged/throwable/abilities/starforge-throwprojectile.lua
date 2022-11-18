require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

StarforgeThrowProjectile = WeaponAbility:new()

function StarforgeThrowProjectile:init()
  self.weapon:setStance(self.stances.idle)
  animator.setAnimationState("weapon", "visible")
  
  activeItem.setHoldingItem(not self.hideItemWhileIdle)

  self.cooldownTimer = 0
  
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
	animator.setAnimationState("weapon", "visible")
  
    activeItem.setHoldingItem(not self.hideItemWhileIdle)
  end
end

function StarforgeThrowProjectile:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and (self:energyPerShot() == 0) or not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

	self:setState(self.prepare)
  end
end

function StarforgeThrowProjectile:prepare()
  activeItem.setHoldingItem(true)
  
  self.weapon:setStance(self.stances.prepare)
  self.weapon:updateAim()

  local projectileTimesAndAngles = copy(self.projectileTimesAndAngles)
  
  if self.stances.prepare.smooth then
	local progress = 0
	util.wait(self.stances.prepare.duration, function(dt)
	  local from = self.stances.prepare.weaponOffset or {0,0}
	  local to = self.stances.throw.weaponOffset or {0,0}
	  self.weapon.weaponOffset = {util.interpolateSigmoid(progress, from[1], to[1]), util.interpolateSigmoid(progress, from[2], to[2])}
	  
	  self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateSigmoid(progress, self.stances.prepare.weaponRotation, self.stances.throw.weaponRotation))
	  self.weapon.relativeArmRotation = util.toRadians(util.interpolateSigmoid(progress, self.stances.prepare.armRotation, self.stances.throw.armRotation))
	  
	  progress = math.min(1.0, progress + (self.dt / self.stances.prepare.duration))
	  
      local newTimesAndAngles = {}
      for _, timeAndAngle in pairs(projectileTimesAndAngles) do
        if timeAndAngle[1] <= dt and status.overConsumeResource("energy", self:energyPerShot()) then
		  animator.setAnimationState("weapon", "invisible")
          self:spawnProjectile(timeAndAngle[2])
        else
          table.insert(newTimesAndAngles, {timeAndAngle[1] - dt, timeAndAngle[2]})
        end
      end
      projectileTimesAndAngles = newTimesAndAngles
	end)
  else
	if self.stances.prepare.duration then
	  util.wait(self.stances.prepare.duration)
	end
  end

  self:setState(self.throw)
end

function StarforgeThrowProjectile:throw()
  self.weapon:setStance(self.stances.throw)
  self.weapon:updateAim()
  
  if not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
	animator.setAnimationState("weapon", "invisible")
  
	util.wait(self.stances.throw.duration, function(dt)
    end)
  end
  
  item.consume(self.consumeCount or 0)
  
  util.wait(self.reloadWait)
  self.cooldownTimer = self.cooldownTime
  
  if not self.hideItemWhileIdle then
    self:setState(self.reload)
  end
end

function StarforgeThrowProjectile:reload()
  self.weapon:setStance(self.stances.reload)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.reload.duration, function()
	local from = self.stances.reload.weaponOffset or {0,0}
	local to = self.stances.reload.endWeaponOffset or {0,0}
	self.weapon.weaponOffset = {util.interpolateSigmoid(progress, from[1], to[1]), util.interpolateSigmoid(progress, from[2], to[2])}
	  
	self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateSigmoid(progress, self.stances.reload.weaponRotation, self.stances.reload.endWeaponRotation))
	self.weapon.relativeArmRotation = util.toRadians(util.interpolateSigmoid(progress, self.stances.reload.armRotation, self.stances.reload.endArmRotation))
	
	if progress > self.stances.reload.loadTime and not self.hideItemWhileIdle then
	  animator.setAnimationState("weapon", "visible")
	end
	
	progress = math.min(1.0, progress + (self.dt / self.stances.reload.duration))
  end)
end

function StarforgeThrowProjectile:spawnProjectile(angleAdjust)
  animator.playSound("throw")
  
  --Set up projectile type
  local projectileType = self.projectileType
  if type(projectileType) == "table" then
	projectileType = projectileType[math.random(#projectileType)]
  end
  
  --Set up projectile parameters
  local params = sb.jsonMerge(self.projectileParameters, {})
  params.power = self.baseDamage / self.projectileCount / #self.projectileTimesAndAngles
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  
  if self.projectileFacesDirection and self.weapon.aimDirection > 0 then
    params.processing = "?flipx"
  end
  
  --For every projectileCount, fire a projectile
  local baseSpeed = params.speed
  local baseTTL = params.timeToLive
  for i = 1, self.projectileCount do
    if baseTTL then
      params.timeToLive = util.randomInRange(baseTTL)
    end
    if baseSpeed then
      params.speed = util.randomInRange(baseSpeed)
    end
	params.speed = util.randomInRange(params.speed)

	world.spawnProjectile(
	  projectileType,
	  firePosition or self:firePosition(),
	  activeItem.ownerEntityId(),
	  self:aimVector(self.inaccuracy, angleAdjust),
	  false,
	  params
	)
  end
end

function StarforgeThrowProjectile:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.fireOffset))
end

function StarforgeThrowProjectile:updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.aimOffset, activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function StarforgeThrowProjectile:aimVector(inaccuracy, angleAdjust)
  local aimVector = vec2.withAngle(self.weapon.aimAngle + sb.nrand(inaccuracy, 0) + util.toRadians(angleAdjust))
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
  
  --[[local aimVector = {}
  if self.angleAdjustmentsPerShot then
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0) + self.angleAdjustmentsPerShot[shotNumber])
  else
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  end
  
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector]]
end

function StarforgeThrowProjectile:energyPerShot()
  return self.energyUsage * (self.energyUsageMultiplier or 1.0)
end


function StarforgeThrowProjectile:uninit()
end
