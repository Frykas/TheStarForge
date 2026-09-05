require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/weapon.lua"

StarforgeThrowReturningProjectile = WeaponAbility:new()

function StarforgeThrowReturningProjectile:init()
  self:reset()
  
  self.cooldownTimer = self.fireTime
  self.stanceResetTimer = nil

  self.weapon:setStance(self.stances.idle)
  
  if config.getParameter("weaponThrown") then
    self:setState(self.cooldown)
  end
end

function StarforgeThrowReturningProjectile:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if config.getParameter("weaponThrown") == nil or not world.entityExists(config.getParameter("weaponThrown")) then
    activeItem.setHoldingItem(true)
  end

  if self.stanceResetTimer then
    self.stanceResetTimer = math.max(0, self.stanceResetTimer - self.dt)
    if self.stanceResetTimer == 0 then
      self.weapon:setStance(self.stances.idle)
      self.stanceResetTimer = nil
    end
  end
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  world.debugText(self.cooldownTimer, mcontroller.position(), "red")
  
  if not self.weapon.currentAbility
    and self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then
    
	  self:setState(self.windup)
  end
end

function StarforgeThrowReturningProjectile:windup()
  local stance = self.stances.windup
  self.stanceResetTimer = nil
  self.weapon:setStance(stance)
  
  self.weapon:updateAim()
  
  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  end
  
  if stance.endWeaponRotation then
    --Smoothly windup
    local progress = 0
    util.wait(stance.duration * (self.stanceSpeedFactor or 1), function()
      progress = math.min(stance.duration * (self.stanceSpeedFactor or 1), progress + self.dt)
      local progressRatio = math.sin(progress / (stance.duration * (self.stanceSpeedFactor or 1)) * 1.57)
	
	    local from = stance.weaponOffset or {0,0}
      local to = stance.endWeaponOffset or {0,0}
      self.weapon.weaponOffset = {interp.linear(progressRatio, from[1], to[1]), interp.linear(progressRatio, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {stance.weaponRotation, stance.endWeaponRotation}))
      self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {stance.armRotation, stance.endArmRotation}))
    end)
  else
    util.wait(stance.duration * (self.stanceSpeedFactor or 1))
  end
  
  self:setState(self.preslash)
end

function StarforgeThrowReturningProjectile:preslash()
  self.weapon:setStance(self.stances.preslash)
  
  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) then
    --Set up projectile parameters
    local params = sb.jsonMerge(self.projectileParameters, {})
    params.power = self:damagePerShot()
    params.powerMultiplier = activeItem.ownerPowerMultiplier()
    
    if self.projectileFacesDirection and self.weapon.aimDirection > 0 then
      params.processing = "?flipx"
    end

    params.spinDirection = mcontroller.facingDirection()
    params.processing = (params.processing or "") .. (params.spinDirection < 0 and "?flipy" or "")

    local thrownProjectile = world.spawnProjectile(
      self.projectileType,
      self:firePosition(),
      activeItem.ownerEntityId(),
      self:aimVector(),
      false,
      params
    )
	
    activeItem.setInstanceValue("weaponThrown", thrownProjectile)
	
    --Play the throwing sound and hide the weapon using animation states
    animator.playSound("throw")
    animator.setAnimationState("weapon", "invisible")

    util.wait(self.stances.preslash.duration * (self.stanceSpeedFactor or 1))
  end
  
  if config.getParameter("weaponThrown") then
    self:setState(self.fire)
  end
end

function StarforgeThrowReturningProjectile:fire()
  self.weapon:updateAim()

  self.weapon:setStance(self.stances.fire)
  
  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration * (self.stanceSpeedFactor or 1))
  end
  
  self:setState(self.cooldown)
end

function StarforgeThrowReturningProjectile:cooldown()
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  while world.entityExists(config.getParameter("weaponThrown")) do
    --world.debugText("Active projectiles detected!", mcontroller.position(), "yellow")
    world.sendEntityMessage(config.getParameter("weaponThrown"), "setTargetPosition", self:firePosition())
    
    local targetPosition = world.entityPosition(config.getParameter("weaponThrown"))
    local toTarget = world.distance(targetPosition, mcontroller.position())
    local projectileFound = (vec2.mag(toTarget) < self.projectileDetectionRadius)
    
    --Set recall armRotation
    if projectileFound then
      activeItem.setHoldingItem(true)
      self.weapon:setStance(self.stances.recall)
      local targetAngle = math.atan(self:firePosition()[2] - targetPosition[2], self:firePosition()[1] - targetPosition[1])
      local angleAdjust = (mcontroller.facingDirection() > 0) and math.pi or 0
      
      self.weapon.relativeArmRotation = (targetAngle * mcontroller.facingDirection()) - angleAdjust
    else
      activeItem.setHoldingItem(false)
    end
    
    --Optionally recall by clicking again
    if not self.weapon.currentAbility
      and self.recallEnabled
      and self.fireMode == (self.activatingFireMode or self.abilitySlot) then
      
      world.sendEntityMessage(config.getParameter("weaponThrown"), "returnToSender")
    end
    coroutine.yield()
  end
  
  self.stanceResetTimer = self.stanceResetTime
  self.weapon:setStance(self.stances.catch)
  
  --Return the weapon to the player's hand
  animator.playSound("catch")
  animator.setAnimationState("weapon", "visible")
  activeItem.setInstanceValue("weaponThrown", nil)
  activeItem.setHoldingItem(true)
  
  self:reset()
end

function StarforgeThrowReturningProjectile:aimVector()
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle)
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function StarforgeThrowReturningProjectile:damagePerShot()
  return (self.baseDamage or (self.baseDps * (self.fireTime))) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier")
end

function StarforgeThrowReturningProjectile:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition())
end

function StarforgeThrowReturningProjectile:reset()
  self.cooldownTimer = self.fireTime
end

function StarforgeThrowReturningProjectile:uninit()
  self:reset()
end
