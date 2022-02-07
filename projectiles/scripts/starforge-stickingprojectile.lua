require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  --Sticking
  self.validEntityTypes = config.getParameter("validEntityTypes", {"creature"})
  self.stickActionOnReap = config.getParameter("stickActionOnReap", {})
  self.actionOnStick = config.getParameter("actionOnStick", {})
  self.searchDistance = config.getParameter("searchDistance", 0.1)
  self.retainDamage = config.getParameter("retainStickingDamage", false)
  
  self.stickingTarget = nil
  self.stickingOffset = {0, 0}
  self.stuckToTarget = false
  self.stuckToGround = false
  self.hasActioned = false
end

function update(dt)
  --Sticking
  local targets = {}

  --Look for a target to stick to
  if not self.stickingTarget then
    local projectileLengthVector = vec2.norm(mcontroller.velocity())
    self.stuckToGround = world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), projectileLengthVector))
    targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
      withoutEntityId = projectile.sourceEntity(),
      includedTypes = self.validEntityTypes,
      order = "nearest"
    })
  end

  --If targets were found, set tracking info to the closest entity, unless we were already stuck in the ground
  if #targets > 0 and not self.stuckToGround then
    if world.entityExists(targets[1]) then
	  --Set the sticking target
      self.stickingTarget = targets[1]
      self.stuckToTarget = true
	  --Store rotation to lock it
	  self.stickingRotation = mcontroller.rotation()
	  --Determine where to stick on the enemy
	  self.stickingOffset = world.distance(mcontroller.position(), world.entityPosition(self.stickingTarget))
      --If specified set the time to live for when you have stuck to an enemy
	  if config.getParameter("stickToTargetTime") then
        projectile.setTimeToLive(config.getParameter("stickToTargetTime"))
      end
      --mcontroller.setVelocity({0, 0})
    end
  end

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
	  
	  --Lock rotation to the rotation upon hitting the enemy
	  mcontroller.setRotation(self.stickingRotation)
    else
      self.stickingTarget = nil
    end
  end

  --If we were stuck to a target, but got unstuck, kill the projectile
  if self.stuckToTarget and not self.stickingTarget then
    projectile.die()
  end

  if self.stuckToGround then
    if config.getParameter("proximitySearchRadius") then
      local targets = world.entityQuery(mcontroller.position(), self.proximitySearchRadius, {
        withoutEntityId = projectile.sourceEntity(),
        includedTypes = {"creature"},
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

function destroy()
  if self.stuckToTarget then
    for i, action in ipairs(self.stickActionOnReap) do
	  projectile.processAction(action)
    end
  end
end

