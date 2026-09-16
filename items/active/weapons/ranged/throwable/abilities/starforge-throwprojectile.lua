require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

StarforgeThrowProjectile = WeaponAbility:new()

function StarforgeThrowProjectile:init()
  self.weapon:setStance(self.stances.idle)
  animator.setAnimationState("weapon", "visible")
  
  activeItem.setHoldingItem(not self.hideItemWhileIdle)

  self.cooldownTimer = self.fireTime
  
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
    and (not self.energyUsage or (self.energyUsage > 0 and not status.resourceLocked("energy")))
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

	  self:setState(self.throw)
  end
end

function StarforgeThrowProjectile:throw()
  activeItem.setHoldingItem(true)
  
  self.weapon:setStance(self.stances.throw)
  self.weapon:updateAim()

  local projectileTimesAndAngles = copy(self.projectileTimesAndAngles)
  
  if self.stances.throw.smooth then
    local timer = 0
    util.wait(self.stances.throw.duration * (self.stanceSpeedFactor or 1), function(dt)
      local progress = timer / self.stances.throw.duration * (self.stanceSpeedFactor or 1)

      local from = self.stances.throw.weaponOffset or {0,0}
      local to = self.stances.throw.weaponOffset or {0,0}
      self.weapon.weaponOffset = {util.interpolateSigmoid(progress, from[1], to[1]), util.interpolateSigmoid(progress, from[2], to[2])}
      
      self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateSigmoid(progress, self.stances.throw.weaponRotation, self.stances.cooldown.weaponRotation))
      self.weapon.relativeArmRotation = util.toRadians(util.interpolateSigmoid(progress, self.stances.throw.armRotation, self.stances.cooldown.armRotation))
      
      timer = math.min(self.stances.throw.duration * (self.stanceSpeedFactor or 1), timer + self.dt)
	  
      local newTimesAndAngles = {}
      for _, timeAndAngle in pairs(projectileTimesAndAngles) do
        if (timeAndAngle[1] * (self.stanceSpeedFactor or 1)) <= timer and status.overConsumeResource("energy", self:energyPerShot()) then
		      animator.setAnimationState("weapon", "invisible")
          self:spawnProjectile(timeAndAngle[2])
          self.cheesePrevention = true
        else
          table.insert(newTimesAndAngles, {timeAndAngle[1], timeAndAngle[2]})
        end
      end
      projectileTimesAndAngles = newTimesAndAngles
	  end)
  else
    if self.stances.throw.duration then
      util.wait(self.stances.throw.duration * (self.stanceSpeedFactor or 1))
    end
  end
  
  self.cooldownTimer = self.fireTime

  self:setState(self.cooldown)
end

function StarforgeThrowProjectile:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()
  
  if not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
	animator.setAnimationState("weapon", "invisible")
  
	util.wait(self.stances.cooldown.duration * (self.stanceSpeedFactor or 1), function(dt)
    end)
  end
  
  item.consume(self.consumeCount or 0)
  self.cheesePrevention = false
  
  if not self.hideItemWhileIdle then
    self:setState(self.reload)
  end
end

function StarforgeThrowProjectile:reload()
  self.weapon:setStance(self.stances.reload)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.reload.duration * (self.stanceSpeedFactor or 1), function()
    local from = self.stances.reload.weaponOffset or {0,0}
    local to = self.stances.reload.endWeaponOffset or {0,0}
    self.weapon.weaponOffset = {util.interpolateSigmoid(progress, from[1], to[1]), util.interpolateSigmoid(progress, from[2], to[2])}
      
    self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateSigmoid(progress, self.stances.reload.weaponRotation, self.stances.reload.endWeaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(util.interpolateSigmoid(progress, self.stances.reload.armRotation, self.stances.reload.endArmRotation))
    
    if progress > self.stances.reload.loadTime and not self.hideItemWhileIdle then
      animator.setAnimationState("weapon", "visible")
    end
    
    progress = math.min(1.0, progress + (self.dt / self.stances.reload.duration * (self.stanceSpeedFactor or 1)))
  end)
end

function StarforgeThrowProjectile:spawnProjectile(angleAdjust)
  --Add normal pitch variance to shots
  local pitchVariance = (1 + (self.pitchVariance or 0.1)) - (math.random() * ((self.pitchVariance or 0.1) * 2)) + (pitchIncrease or 0)
  animator.setSoundPitch("throw", pitchVariance)
  animator.playSound("throw")
  
  --Set up projectile type
  local projectileType = self.projectileType
  if type(projectileType) == "table" then
	  projectileType = projectileType[math.random(#projectileType)]
  end
  
  --Set up projectile parameters
  local params = sb.jsonMerge(self.projectileParameters, {})
  params.power = self:damagePerShot()
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
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function StarforgeThrowProjectile:updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.aimOffset, activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function StarforgeThrowProjectile:damagePerShot()
  return (self.baseDamage or (self.baseDps * (self.fireTime))) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount / #self.projectileTimesAndAngles
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
  if self.cheesePrevention then
    item.consume(self.consumeCount or 0)
  end
end
