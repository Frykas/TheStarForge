require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  --Sticking
  self.validEntityTypes = config.getParameter("validEntityTypes", {"creature"})
  self.stickActionOnReap = config.getParameter("stickActionOnReap", {})
  self.actionOnStick = config.getParameter("actionOnStick", {})
  self.damageMultiplierOnStick = config.getParameter("damageMultiplierOnStick", 1)
  self.proximitySearchRadius = config.getParameter("proximitySearchRadius")

  self.spinning = config.getParameter("spinRate")

  local powerMultiplier = projectile.powerMultiplier()
  local curve = 4.15
  local targetMultiplier = 1 + (curve * math.log(powerMultiplier))
  self.adjustedStickMultiplier = targetMultiplier / powerMultiplier

  projectile.setPower(config.getParameter("initialDamageMultiplier", 1) * projectile.power())
  self.baseDamage = projectile.power()
  
  self.targetRotation = mcontroller.rotation()
  self.stickingTarget = nil
  self.stickingOffset = {0, 0}
  self.stuckToTarget = false
  self.hasActioned = false
end

function update(dt)
  --While our target lives, make the projectile follow the target
  if self.stickingTarget then
    --If our entity exists do the sticking actions
    if world.entityExists(self.stickingTarget) then
      --If applicable, process actions on stick
      if not self.hasActioned then
        for i, action in ipairs(self.actionOnStick) do
          projectile.processAction(action)
        end
        self.hasActioned = true
      end
	    --Find the position to stick to and stick to it
      local targetStickingPosition = vec2.add(world.entityPosition(self.stickingTarget), self.stickingOffset)
      mcontroller.setPosition(targetStickingPosition)
	    --Adjust velocity as to not offset from entity
      local stickingVelocity = self.stickingOffset
      mcontroller.setVelocity(stickingVelocity)
      mcontroller.setRotation(self.targetRotation)
    else
      self.stickingTarget = nil
      projectile.setPower(self.baseDamage)
    end
  end

  --If we were stuck to a target, but got unstuck, kill the projectile
  if self.stuckToTarget and not self.stickingTarget then
    projectile.die()
  end

  --Look for a target to stick to
  if not self.stickingTarget then
	  local projectileLengthVector = vec2.norm(mcontroller.velocity())
    self.stuckToGround = world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), projectileLengthVector))
    if not self.stuckToGround then
      self.targetRotation = math.atan(mcontroller.velocity()[2], mcontroller.velocity()[1])
    end
  end
  if not self.spinning then
    mcontroller.setRotation(self.targetRotation)
  end

  if self.stuckToGround then
    if self.proximitySearchRadius then
      local targets = world.entityQuery(mcontroller.position(), self.proximitySearchRadius, {
        withoutEntityId = projectile.sourceEntity(),
        includedTypes = self.validEntityTypes,
        order = "nearest"
      })

      for _, target in ipairs(targets) do
        if entity.entityInSight(target) and world.entityCanDamage(projectile.sourceEntity(), target) then
          projectile.die()
          return
        end
      end
    end
  end
end

function hit(entityId)
  if entityId and world.entityExists(entityId) then
    local enemyPos = world.entityPosition(entityId)
    local dist = world.magnitude(enemyPos, mcontroller.position())
    if dist > 4 then
      mcontroller.setPosition(enemyPos)
    end

    self.targetRotation = mcontroller.rotation()
    --Set the sticking target
    self.stickingTarget = entityId
  
    self.stuckToTarget = true
    --Determine where to stick on the enemy
    self.stickingOffset = world.distance(mcontroller.position(), world.entityPosition(self.stickingTarget))
    --If specified set the time to live for when you have stuck to an enemy
    if config.getParameter("stickToTargetTime") then
      projectile.setTimeToLive(config.getParameter("stickToTargetTime"))
    end
    
    projectile.setPower(self.baseDamage * self.damageMultiplierOnStick * self.adjustedStickMultiplier)
    --mcontroller.setVelocity({0, 0})
  end
end

starforge_sticking_advancedPeriodicActions = advancedPeriodicActions
function advancedPeriodicActions(action, dt, index)
  if action.requiresSticking and not self.stickingTarget then
    return action
  end

  starforge_sticking_advancedPeriodicActions(action, dt, index)
end

function destroy()
  if self.stuckToTarget then
    for i, action in ipairs(self.stickActionOnReap) do
	    projectile.processAction(action)
    end
  end
end

