require "/scripts/util.lua"
require "/scripts/status.lua"

-- Melee primary ability
StarForgeFloatingShield = WeaponAbility:new()

function StarForgeFloatingShield:init()
  self.cooldownTimer = 0
  self.blastCooldownTimer = 0
  
  self.shieldHealth = 1000
  
  self.aimAngle = 0
end

-- Ticks on every update regardless if this is the active ability
function StarForgeFloatingShield:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  self.blastCooldownTimer = math.max(0, self.blastCooldownTimer - dt)

  if self.weapon.currentAbility == nil
    and fireMode == "alt"
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self:setState(self.defend)
  end
  
  self.aimAngle = (math.atan(self:firePosition()[2] - activeItem.ownerAimPosition()[2], self:firePosition()[1] - activeItem.ownerAimPosition()[1]) - (mcontroller.facingDirection() < 0 and 0 or -math.pi)) * (mcontroller.facingDirection() < 0 and -1 or 1)
end

function StarForgeFloatingShield:defend()
  self.weapon:setStance(self.stances.defendwindup)
  self.weapon:updateAim()
  
  --Shield animations
  animator.setAnimationState("shield", "activate")
  animator.playSound("raiseShield")
  
  --Shield windup animation
  util.wait(self.stances.defendwindup.duration)
  self.weapon:setStance(self.stances.defend)
  
  self.weapon:updateAim()
  
  --Seting up the damage listener for actions on shield hit
  self.damageListener = damageListener("damageTaken", function(notifications)
	--Optionally spawn a projectile whenever the shield is hit
	if self.blastOnShieldHit then
	  for _,notification in pairs(notifications) do
		if notification.hitType == "ShieldHit" then		  
		  --Fire a projectile when the shield is hit
		  if self.blastCooldownTimer == 0 then
			--Projectile parameters
			local params = copy(self.projectileParameters)
			params.power = self.baseDamage * config.getParameter("damageLevelMultiplier")
			params.powerMultiplier = activeItem.ownerPowerMultiplier()
			
			--Projectile spawn code
			local aim = self.aimAngle
			if not world.pointTileCollision(mcontroller.position()) then
			  for i = 1, self.projectileCount do
		  	    local aimAngle = vec2.rotate({1, 0}, self.aimAngle + sb.nrand((360 / (self.projectileCount + 1) * i) + math.random(360)))
			    world.spawnProjectile(self.projectileType, mcontroller.position(), activeItem.ownerEntityId(), aimAngle, false, params)
			  end
			  animator.playSound("shieldBurst")
			  animator.burstParticleEmitter("burst")
			  self.blastCooldownTimer = self.blastCooldownTime
			else
			  animator.playSound("shieldHit")
			end
		  else
			animator.playSound("shieldHit")
		  end
		  return
		end
	  end
	--If not configured to spawn a projectile, only play a hit sound
	else
	  for _,notification in pairs(notifications) do
		if notification.hitType == "ShieldHit" then
		  animator.playSound("shieldHit")
		  return
		end
	  end
	end
  end)
  
  --Rendering the shield health bar
  status.setPersistentEffects("broadswordParry", {{stat = "shieldHealth", amount = self.shieldHealth}})
  
  while self.fireMode == "alt" and status.overConsumeResource("energy", self.energyUsage * self.dt) do
	self.weapon:updateAim()

	self.damageListener:update()
	
	animator.resetTransformationGroup("shield")
	animator.rotateTransformationGroup("shield", self.aimAngle, {-self.shieldOffset[1], -self.shieldOffset[2]})
	animator.translateTransformationGroup("shield", vec2.rotate(self.shieldOffset, self.aimAngle))
	
    local shieldPoly = animator.partPoly("shield", "shieldPoly")
    activeItem.setItemShieldPolys({shieldPoly})
    if self.knockback > 0 then
	  local knockbackDamageSource = {
	    poly = shieldPoly,
	    damage = 0,
	    damageType = "Knockback",
	    sourceEntity = activeItem.ownerEntityId(),
	    team = activeItem.ownerTeam(),
	    knockback = self.knockback,
	    rayCheck = true,
	    damageRepeatTimeout = 0.25
      }
	  activeItem.setItemDamageSources({ knockbackDamageSource })
    end
  
	
	coroutine.yield()
  end
end

function StarForgeFloatingShield:firePosition()
  return mcontroller.position()
end

function StarForgeFloatingShield:reset()
  animator.setAnimationState("shield", "deactivate")
  activeItem.setItemShieldPolys({})
  activeItem.setItemDamageSources({})
  status.clearPersistentEffects("broadswordParry")
end

function StarForgeFloatingShield:uninit()
  self:reset()
end
