require "/items/active/weapons/weapon.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

StarForgeApplyStatusEffect = WeaponAbility:new()

function StarForgeApplyStatusEffect:init()
  if self.cooldownPersistent then
	self.cooldownTimer = config.getParameter("cooldownTimer", 0)
  else
	self.cooldownTimer = self.cooldownTime
  end
  
  if self.cooldownTimer == 0 then
	self.abilityReady = true
  else
	self.abilityReady = false
  end
end

function StarForgeApplyStatusEffect:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  if self.cooldownPersistent then
	activeItem.setInstanceValue("cooldownTimer", self.cooldownTimer)
  end
  world.debugText(self.cooldownTimer, mcontroller.position(), "red")
  
  if self.cooldownTimer == 0 and not self.abilityReady and status.statusProperty(self.statusEffect, 0) == 0 then
	if self.lightIndicator then
	  animator.setAnimationState("light", "active")
	end
	animator.burstParticleEmitter("statusReady")
    animator.playSound("abilityReady")
    self.abilityReady = true
  elseif self.cooldownTimer ~= 0 then
	if self.lightIndicator then
	  animator.setAnimationState("light", "inactive")
	end
	self.abilityReady = false
  end

  if self.weapon.currentAbility == nil
    and self.cooldownTimer == 0
    and self.abilityReady
    and not status.resourceLocked("energy")
    and self.fireMode == "alt" then
    
    self:setState(self.activate)
  end
  
  --If we are affected by our status and in idle, set custom idle stance
  if status.statusProperty(self.statusEffect, 0) == 1 then
    if not self.weapon.currentAbility then
	  if self.stances.statusIdle.emote then
		activeItem.emote(self.stances.statusIdle.emote)
	  end
	  self.weapon:setStance(self.stances.statusIdle)
	  self.weapon:updateAim()
    end
	animator.setAnimationState("status", "active")
  else
    if not self.weapon.currentAbility then
	  self.weapon:setStance(self.stances.idle)
	  self.weapon:updateAim()
	end
	animator.setAnimationState("status", "inactive")
  end
end

function StarForgeApplyStatusEffect:activate()
  self.weapon:setStance(self.stances.activate)
  
  if self.forceStopSound then
	animator.playSound("activateStatusEffect", -1)
  else
	animator.playSound("activateStatusEffect")
  end
  animator.burstParticleEmitter("activateStatusEffect")
  
  --Optionally activate the effect before any wait duration
  if self.activateInstantly and not (self.blockingStat and status.statPositive(self.blockingStat)) then
	status.addEphemeralEffect(self.statusEffect)
	self.cooldownTimer = self.cooldownTime
	self.abilityReady = false
  end
  
  local progress = 0
  if self.stances.activate.duration then
    util.wait(self.stances.activate.duration, function()
	  --Optionally rotate the weapon
	  if self.stances.activate.endWeaponRotation then
		self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.activate.weaponRotation, self.stances.activate.endWeaponRotation))
	  end
	  
	  --Optionally rotate the player's arm
	  if self.stances.activate.endArmRotation then
		self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.activate.armRotation, self.stances.activate.endArmRotation))
	  end

	  progress = math.min(1.0, progress + (self.dt / self.stances.activate.duration))
	end)
  end
  
  if not self.activateInstantly and not (self.blockingStat and status.statPositive(self.blockingStat)) then
	status.addEphemeralEffect(self.statusEffect, self.statusEffectDuration or nil)
	self.cooldownTimer = self.cooldownTime
	self.abilityReady = false
  end
  
  if self.forceStopSound then
	animator.stopAllSounds("activateStatusEffect")
  end
end

function StarForgeApplyStatusEffect:uninit()
  if self.cooldownPersistent then
	activeItem.setInstanceValue("cooldownTimer", self.cooldownTimer)
  end
  
  animator.stopAllSounds("activateStatusEffect")
end
