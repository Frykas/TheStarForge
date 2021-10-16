require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

-- fist weapon primary attack
StarforgePunch = WeaponAbility:new()

function StarforgePunch:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.weapon:setStance(self.stances.idle)

  self.flippedStances = sb.jsonMerge(self.stances, {})
  for _, stance in pairs(self.flippedStances) do
	stance.armRotation = stance.armRotation * -1
	if stance.backWeaponOffset then
	  stance.weaponOffset = stance.backWeaponOffset
	end
  end

  self.cooldownTimer = self:cooldownTime()

  self.freezesLeft = self.freezeLimit
  self.freezeTimer = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function StarforgePunch:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  self.freezeTimer = math.max(0, self.freezeTimer - dt)
  if self.freezeTimer > 0 and not mcontroller.onGround() and math.abs(world.gravity(mcontroller.position())) > 0 then
    mcontroller.controlApproachVelocity({0, 0}, 1000)
  end
end

function StarforgePunch:canStartAttack()
  return not self.weapon.currentAbility and self.cooldownTimer == 0
end

-- used by fist weapon combo system
function StarforgePunch:startAttack()
  local stance = self.stances
  if self.flipRotationWhenBack and not self.weapon:isFrontHand() then
	stance = self.flippedStances
    animator.setGlobalTag("flippedY", "?flipy")
  end
  self:setState(self.windup, stance)

  if self.weapon.freezesLeft > 0 then
    self.weapon.freezesLeft = self.weapon.freezesLeft - 1
    self.freezeTimer = self.freezeTime or 0
  end
end

-- State: windup
function StarforgePunch:windup(stance)
  self.weapon:setStance(stance.windup)

  util.wait(stance.windup.duration)

  self:setState(self.windup2, stance)
end

-- State: windup2
function StarforgePunch:windup2(stance)
  self.weapon:setStance(stance.windup2)

  util.wait(stance.windup2.duration)

  self:setState(self.fire, stance)
end

-- State: fire
function StarforgePunch:fire(stance)
  self.weapon:setStance(stance.fire)
  self.weapon:updateAim()

  animator.setAnimationState("attack", "fire")
  animator.playSound("fire")

  status.addEphemeralEffect("invulnerable", stance.fire.duration + 0.1)

  util.wait(stance.fire.duration, function()
    local damageArea = partDamageArea("swoosh")
    
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)

  animator.setGlobalTag("flippedY", "")
  self.cooldownTimer = self:cooldownTime()
end

function StarforgePunch:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function StarforgePunch:uninit(unloaded)
  self.weapon:setDamage()
end
