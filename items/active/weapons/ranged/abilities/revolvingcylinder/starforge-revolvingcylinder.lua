require "/scripts/util.lua"
require "/scripts/interp.lua"

StarForgeRevolvingCylinder = WeaponAbility:new()

function StarForgeRevolvingCylinder:init()
  self.cooldownTimer = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.weapon.abilities[1].stances.idle)
  end
end

function StarForgeRevolvingCylinder:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and self.cooldownTimer == 0
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and not status.resourceLocked("energy") 
	and status.overConsumeResource("energy", self:energyPerShot()) then

    self:setState(self.charge)
  end
end

function StarForgeRevolvingCylinder:charge()
  self.weapon:setStance(self.stances.charge)

  animator.setAnimationState("gun", "charge")
  animator.setAnimationState("firing", "charge")

  local chargeTimer = 0

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
    chargeTimer = math.min(self.chargeTime, chargeTimer + self.dt)

    coroutine.yield()
  end

  if chargeTimer == self.chargeTime then
    self:setState(self.fire)
  else
    self:reset()
  end
end

function StarForgeRevolvingCylinder:fire()
  if world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    self:reset()
    return
  end

  self.weapon:setStance(self.stances.fire)

  self:muzzleFlash()
  self:fireProjectile()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.cooldownTimer
  self:setState(self.cooldown)
end

function StarForgeRevolvingCylinder:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.setAnimationState("gun", "transitionToIdle1")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("chargeFire")

  animator.setLightActive("muzzleFlash", true)
end

function StarForgeRevolvingCylinder:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.weapon.abilities[1].stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.weapon.abilities[1].stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.weapon.abilities[1].stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function StarForgeRevolvingCylinder:fireProjectile()
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)
  
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

function StarForgeRevolvingCylinder:energyPerShot()
  return self.energyUsage * self.chargeTime * (self.energyUsageMultiplier or 1.0)
end

function StarForgeRevolvingCylinder:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.chargeTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function StarForgeRevolvingCylinder:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function StarForgeRevolvingCylinder:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function StarForgeRevolvingCylinder:reset()
  animator.setAnimationState("firing", "off")
  animator.setAnimationState("gun", "transitionToIdle1")
end

function StarForgeRevolvingCylinder:uninit()
end
