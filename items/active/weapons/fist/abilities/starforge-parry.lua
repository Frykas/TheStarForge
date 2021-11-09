require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/poly.lua"
require "/items/active/weapons/weapon.lua"

-- fist weapon alt attack
StarforgeParry = WeaponAbility:new()

function StarforgeParry:init()
  self.cooldownTimer = self:cooldownTime()

  self.weapon.onLeaveAbility = function()
  end
end

-- Ticks on every update regardless if this is the active ability
function StarforgeParry:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
end

function StarforgeParry:canStartAttack()
  return not self.weapon.currentAbility and self.cooldownTimer == 0 and status.overConsumeResource("energy", self.energyUsage)
end

-- used by fist weapon combo system
function StarforgeParry:startAttack()
  self:setState(self.windup)
end

-- State: windup
function StarforgeParry:windup()
  self.weapon:setStance(self.stances.windup)

  util.wait(self.stances.windup.duration)

  self:setState(self.windup2)
end

-- State: windup2
function StarforgeParry:windup2()
  self.weapon:setStance(self.stances.windup2)

  util.wait(self.stances.windup2.duration)

  self:setState(self.parry)
end

-- State: parry
function StarforgeParry:parry()
  self.weapon:setStance(self.stances.parry)
  self.weapon:updateAim()
  
  --Play the iniate guard stance sound
  animator.playSound("guard")
  animator.setAnimationState("parryShield", "active")
  
  --Display the shield health bar
  status.setPersistentEffects("broadswordParry", {{stat = "shieldHealth", amount = 1000}})
  
  --Create a shield poly to block attacks
  local blockPoly = animator.partPoly("parryShield", "shieldPoly")
  activeItem.setItemShieldPolys({blockPoly})
  
  --Set up a damagelistener for incoming blocked damage
  local damageListener = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.sourceEntityId ~= -65536 and notification.healthLost == 0 then
        animator.playSound("parry")
		
		callFinisher()
        return
      end
    end
  end)

  util.wait(self.stances.parry.duration, function()
    --Interrupt when running out of shield stamina
    if not status.resourcePositive("shieldStamina") then
	  return true
	end

    damageListener:update()
  end)

  animator.setAnimationState("parryShield", "hidden")
  activeItem.setItemShieldPolys({})
  self.cooldownTimer = self:cooldownTime()
end

function StarforgeParry:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.parry.duration
end

function StarforgeParry:uninit(unloaded)
  animator.setAnimationState("parryShield", "hidden")
  status.clearPersistentEffects("broadswordParry")
  activeItem.setItemShieldPolys({})
  self.weapon:setDamage()
end
