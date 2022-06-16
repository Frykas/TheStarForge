require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"
require "/items/active/weapons/ranged/starforge-gunfire.lua"

StarforgeAltFire = StarforgeGunFire:new()

function StarforgeAltFire:new(abilityConfig)
  local primary = config.getParameter("primaryAbility")
  return StarforgeGunFire.new(self, sb.jsonMerge(primary, abilityConfig))
end

function StarforgeAltFire:init()
  self.cooldownTimer = self.fireTime
end

function StarforgeAltFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  world.debugText("Projectile Type Alt: " .. sb.print(self.projectileType), vec2.add(mcontroller.position(), {0,1}), "yellow")

  if self.fireMode == "alt"
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    
    if self.fireType == "auto" and status.overConsumeResource("energy", self:energyPerShot()) then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
end

function StarforgeAltFire:auto()
  self.weapon:setStance(self.stances.fire)
  if self.animateWeapon then
	animator.setAnimationState("weapon", "active")
  end

  StarforgeGunFire.fireProjectile(self)
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function StarforgeAltFire:burst()
  self.weapon:setStance(self.stances.fire)
  if self.animateWeapon then
	animator.setAnimationState("weapon", "active")
  end

  local shots = self.burstCount
  while shots > 0 and status.overConsumeResource("energy", self:energyPerShot()) do
    StarforgeGunFire.fireProjectile(self)
    self:muzzleFlash()
    shots = shots - 1

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

function StarforgeAltFire:muzzleFlash()
  if self.hidePrimaryMuzzleFlash == false then
    animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
    animator.setAnimationState("firing", "fire")
    animator.setLightActive("muzzleFlash", true)
  end
  
  if self.useParticleEmitter then
    animator.burstParticleEmitter("altMuzzleFlash", true)
  end
  
  if self.playAltFireAnimation then
    animator.setAnimationState("altFire", "fire")
  end

  animator.playSound(self.fireSound or "fire")
end

function StarforgeAltFire:firePosition()
  if self.fireOffset then
    return vec2.add(mcontroller.position(), activeItem.handPosition(vec2.add(self.weapon.muzzleOffset, self.fireOffset)))
  else
    return StarforgeGunFire.firePosition(self)
  end
end
