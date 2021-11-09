require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

StarforgeHookSlash = WeaponAbility:new()

function StarforgeHookSlash:init()
  self.freezeTimer = 0
end

-- Ticks on every update regardless if this is the active ability
function StarforgeHookSlash:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.freezeTimer = math.max(0, self.freezeTimer - self.dt)
  if self.freezeTimer > 0 and not mcontroller.onGround() then
    mcontroller.controlApproachVelocity({0, 0}, 1000)
  end

  if self.damageListener then
    self.damageListener:update()
  end
end

-- used by fist weapon combo system
function StarforgeHookSlash:startAttack()
  self:setState(self.windup)

  self.weapon.freezesLeft = 0
  self.freezeTimer = self.freezeTime or 0
end

-- State: windup
function StarforgeHookSlash:windup()
  self.weapon:setStance(self.stances.windup)

  util.wait(self.stances.windup.duration)

  self:setState(self.windup2)
end

-- State: windup2
function StarforgeHookSlash:windup2()
  self.weapon:setStance(self.stances.windup2)

  util.wait(self.stances.windup2.duration)

  self:setState(self.fire)
end

-- State: special
function StarforgeHookSlash:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("attack", "special")
  animator.playSound("special")
  
  local firePosition = vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("weapon", "projectileFirePoint") or {0,0}))
  local params = self.projectileParameters or {}
  params.power = self.projectileDamage * config.getParameter("damageLevelMultiplier")
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)
	
  world.debugPoint(firePosition, "red")
	
  if not world.lineTileCollision(mcontroller.position(), firePosition) and status.overConsumeResource("energy", self.energyUsage or 0) then
	for i = 1, (self.projectileCount or 1) do
	  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(self.inaccuracy or 0, 0) + (self.projectileAimAngleOffset or 0))
	  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
		
	  world.spawnProjectile(
		self.projectileType,
		firePosition,
		activeItem.ownerEntityId(),
		aimVector,
		false,
		params
	  )
	end
  end

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("specialswoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)

  finishFistCombo()
  activeItem.callOtherHandScript("finishFistCombo")
end

function StarforgeHookSlash:uninit(unloaded)
  self.weapon:setDamage()
end
