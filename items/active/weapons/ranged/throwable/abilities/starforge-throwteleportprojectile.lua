require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/weapon.lua"

StarforgeThrowTeleportProjectile = WeaponAbility:new()

function StarforgeThrowTeleportProjectile:init()
  self:reset()
  
  self.cooldownTimer = self.fireTime
  self.stanceResetTimer = nil

  self.weapon:setStance(self.weapon.abilities[1].stances.idle)
  
  if config.getParameter("weaponThrown") then
    self:setState(self.cooldown)
  end
end

function StarforgeThrowTeleportProjectile:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if config.getParameter("weaponThrown") == nil or not world.entityExists(config.getParameter("weaponThrown")) then
    activeItem.setHoldingItem(true)
  end
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  if not self.weapon.currentAbility
    and self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and self.cooldownTimer == 0
    and (not self.energyUsage or (self.energyUsage > 0 and not status.resourceLocked("energy"))) then

    self:setState(self.windup)
  end
end

function StarforgeThrowTeleportProjectile:windup()
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

function StarforgeThrowTeleportProjectile:preslash()
  self.weapon:setStance(self.stances.preslash)
  
  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self:energyPerShot()) then
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
    local pitchVariance = (1 + (self.pitchVariance or 0.1)) - (math.random() * ((self.pitchVariance or 0.1) * 2))
    animator.setSoundPitch("throw", pitchVariance)
    animator.playSound("throw")
    animator.setAnimationState("weapon", "invisible")

    self.teleportTimer = 0
    
    util.wait(self.stances.preslash.duration * (self.stanceSpeedFactor or 1))
  end
  
  if config.getParameter("weaponThrown") then
    self:setState(self.fire)
  end
end

function StarforgeThrowTeleportProjectile:teleport()
  status.setPersistentEffects("starforge-throwteleportprojectile", { { stat = "invulnerable", amount = 1.0 }, { stat = "activeMovementAbilities", amount = 1 } })
  
  --Create the teleportation effect and add 0.5 for both animations to take effect
  if self.teleportStatus ~= false then
    status.addEphemeralEffect(self.teleportStatus or "starforge-teleporteffect", ((self.teleportDelay or 0.25) + 0.1))
  end
  
  world.sendEntityMessage(config.getParameter("weaponThrown"), "killProjectile")

  local blinkPosition = self:findBlinkPosition(config.getParameter("weaponThrown") and world.entityPosition(config.getParameter("weaponThrown")) or mcontroller.position())
  if blinkPosition then
    if self.dashConfig then
      local dashConfig = sb.jsonMerge(self.dashConfig, {})
      dashConfig.height = mcontroller.boundBox()[4] - mcontroller.boundBox()[2]
      activeItem.setScriptedAnimationParameter("dash", {first = mcontroller.position(), last = blinkPosition, config = dashConfig})
    end

    if self.teleportSound and animator.hasSound(self.teleportSound) then
      local pitchVariance = self.pitchVariance or 0.1
      local pitch = (1 - pitchVariance) + (pitchVariance * 2 * math.random())
      animator.setSoundPitch(self.teleportSound, pitch)
      animator.playSound(self.teleportSound)
    end
    
    util.wait(self.teleportDelay or 0.25)

    local params = sb.jsonMerge(self.teleportProjectileParameters, {})
    params.powerMultiplier = activeItem.ownerPowerMultiplier()
    params.power = (self.teleportBaseDamage or 1) * config.getParameter("damageLevelMultiplier")
    
    world.spawnProjectile(self.teleportProjectileType, blinkPosition, activeItem.ownerEntityId(), vec2.norm(world.distance(mcontroller.position(), blinkPosition)), false, params)
    
    self.weapon:setStance(self.stances.catch)
    mcontroller.setPosition(blinkPosition)

    util.wait(0.1, function(dt)
      mcontroller.setYVelocity(0)
    end)
    activeItem.setScriptedAnimationParameter("dash", nil)

    self.cooldownTimer = self.fireTime
    self.weapon:setStance(self.weapon.abilities[1].stances.idle)
    animator.setAnimationState("weapon", "visible")
    activeItem.setInstanceValue("weaponThrown", nil)
    activeItem.setHoldingItem(true)
  end
  
  self:reset()
end
 
function StarforgeThrowTeleportProjectile:findBlinkPosition(position)
  local collisionPoint = world.lineCollision(mcontroller.position(), position, {"Null", "Block", "Dynamic", "Slippery"})
  
  if collisionPoint then
    return world.resolvePolyCollision(mcontroller.collisionPoly(), collisionPoint, 4) or collisionPoint
  else
    return world.resolvePolyCollision(mcontroller.collisionPoly(), position, 4) or position
  end
end

function StarforgeThrowTeleportProjectile:fire()
  self.weapon:updateAim()

  self.weapon:setStance(self.stances.fire)
  
  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration * (self.stanceSpeedFactor or 1))
  end
  
  self:setState(self.cooldown)
end

function StarforgeThrowTeleportProjectile:cooldown()
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  while world.entityExists(config.getParameter("weaponThrown")) do
    self.teleportTimer = (self.teleportTimer or 0) + script.updateDt()

    if (not self.weapon.currentAbility
      and self.fireMode == (self.activatingFireMode or self.abilitySlot))
      or self.teleportTimer >= self.teleportTime then

      self:setState(self.teleport)
    end
    coroutine.yield()
  end
  
  --Return the weapon to the player's hand
  --Add normal pitch variance to shots
  local pitchVariance = (1 + (self.pitchVariance or 0.1)) - (math.random() * ((self.pitchVariance or 0.1) * 2))
  animator.setSoundPitch("catch", pitchVariance)
  animator.playSound("catch")
  self:setState(self.teleport)
end

function StarforgeThrowTeleportProjectile:aimVector()
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle)
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function StarforgeThrowTeleportProjectile:energyPerShot()
  return self.energyUsage * (self.energyUsageMultiplier or 1.0)
end

function StarforgeThrowTeleportProjectile:damagePerShot()
  return (self.baseDamage or (self.baseDps * (self.fireTime))) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier")
end

function StarforgeThrowTeleportProjectile:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition())
end

function StarforgeThrowTeleportProjectile:reset()
  self.cooldownTimer = self.fireTime
  activeItem.setScriptedAnimationParameter("dash", nil)
  status.setPersistentEffects("starforge-throwteleportprojectile", {})
end

function StarforgeThrowTeleportProjectile:uninit()
  self:reset()
end
