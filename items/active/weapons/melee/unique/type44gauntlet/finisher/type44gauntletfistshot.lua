require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

StarforgeFireFist = WeaponAbility:new()

function StarforgeFireFist:init()
  local level = tostring(config.getParameter("level", 1))

  self.freezeTimer = 0
  self.fireAngleOffset = util.toRadians(config.getParameter("fireAngleOffset", 0))

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function StarforgeFireFist:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.freezeTimer = math.max(0, self.freezeTimer - self.dt)
  if self.freezeTimer > 0 and not mcontroller.onGround() and math.abs(world.gravity(mcontroller.position())) > 0 then
    mcontroller.controlApproachVelocity({0, 0}, 1000)
  end  
end

-- used by fist weapon combo system
function StarforgeFireFist:startAttack()
  self:setState(self.windup)

  self.weapon.freezesLeft = 0
  self.freezeTimer = self.freezeTime or 0
end

-- State: windup
function StarforgeFireFist:windup()
  self.weapon:setStance(self.stances.windup)
  
  animator.setAnimationState("fist", "hidden")
  animator.playSound("fireFist")
  
  projectileId = self:fireProjectile()
  if projectileId then
    storage.projectileIds = {projectileId}
  end
  
  util.wait(self.stances.windup.duration)
  
  status.addEphemeralEffect("invulnerable", self.stances.fire.duration + 0.1)
  
  if self.recoilKnockbackVelocity then
	--If not crouching or if crouch does not impact recoil
	if not (self.crouchStopsRecoil and mcontroller.crouching()) then
	  local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.recoilKnockbackVelocity)
	  --If aiming down and not in zero G, reset Y velocity first to allow for breaking of falls
	  if (self.weapon.aimAngle <= 0 and not mcontroller.zeroG()) then
		mcontroller.setYVelocity(0)
	  end
	  mcontroller.addMomentum(recoilVelocity)
	  mcontroller.controlJump()
	--If crouching
	elseif self.crouchRecoilKnockbackVelocity then
	  local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.crouchRecoilKnockbackVelocity)
	  mcontroller.setYVelocity(0)
	  mcontroller.addMomentum(recoilVelocity)
	end
  end

  self:setState(self.fire)
end

-- State: fire
function StarforgeFireFist:fire()
  self.weapon:setStance(self.stances.fire)

  util.wait(self.stances.fire.duration)

  self:setState(self.recoil)
end

-- Helper function
function StarforgeFireFist:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.ownerAimPosition = activeItem.ownerAimPosition()

  local isFrontHand = self.weapon:isFrontHand()

  if not projectileType then
    projectileType = self[isFrontHand and "frontProjectileType" or "backProjectileType"] 
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
        firePosition or vec2.add(mcontroller.position(), activeItem.handPosition()),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function StarforgeFireFist:aimVector(inaccuracy)
  local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())

  local aimVector = vec2.rotate({1, 0}, aimAngle + self.fireAngleOffset + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * aimDirection
  return aimVector
end

function StarforgeFireFist:damagePerShot()
  return (self.baseDamage or self.baseDps) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function StarforgeFireFist:checkProjectiles()
  if storage.projectileIds then
    local newProjectileIds = {}
    for i, projectileId in ipairs(storage.projectileIds) do
      if world.entityExists(projectileId) then
        local updatedProjectileIds = world.callScriptedEntity(projectileId, "projectileIds")

        if updatedProjectileIds then
          for j, updatedProjectileId in ipairs(updatedProjectileIds) do
            table.insert(newProjectileIds, updatedProjectileId)
          end
        end
      end
    end
    storage.projectileIds = #newProjectileIds > 0 and newProjectileIds or nil
  end
end

-- State: recoil
function StarforgeFireFist:recoil()
  self.weapon:setStance(self.stances.recoil)
  self.weapon:updateAim()

  util.wait(self.stances.recoil.duration)
  
  self.hasFinishedCombo = true

  self:setState(self.returning)
end

function StarforgeFireFist:returning()
  while storage.projectileIds do
    self:checkProjectiles()
    animator.setAnimationState("fist", "hidden")
	if not self.holdRecoilStance then
	  activeItem.setHoldingItem(false)
	end
    coroutine.yield()
  end
  
  self:setState(self.catch)
end

-- State: catch
function StarforgeFireFist:catch()
  self.weapon:setStance(self.stances.catch)
  self.weapon:updateAim()
  
  animator.playSound("catchFist")
  
  animator.setAnimationState("fist", "visible")
  activeItem.setHoldingItem(true)
  finishFistCombo()
  activeItem.callOtherHandScript("finishFistCombo")

  util.wait(self.stances.catch.duration)
end

function StarforgeFireFist:uninit(unloaded)
  self.weapon:setDamage()
end
