require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  --Sticking
  self.validEntityTypes = config.getParameter("validEntityTypes", {"creature"})
  self.stickActionOnReap = config.getParameter("stickActionOnReap",{})
  self.actionOnStick = config.getParameter("actionOnStick",{})
  self.searchDistance = config.getParameter("searchDistance", 0.1)
  self.retainDamage = config.getParameter("retainStickingDamage", false)
  
  self.stickingTarget = nil
  self.stickingOffset = {0,0}
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
      self.stickingTarget = targets[1]
      mcontroller.setVelocity({0,0})
      self.stuckToTarget = true
      if config.getParameter("stickToTargetTime") then
        projectile.setTimeToLive(config.getParameter("stickToTargetTime"))
      end
    end
  end

  --While our target lives, make the projectile follow the target
  if self.stickingTarget then
    if world.entityExists(self.stickingTarget) then
      if not self.hasActioned then
        for i, action in ipairs(self.actionOnStick) do
          projectile.processAction(action)
        end
        self.hasActioned = true
      end
      local targetStickingPosition = vec2.add(world.entityPosition(self.stickingTarget), self.stickingOffset)
      mcontroller.setPosition(targetStickingPosition)
      local stickingVelocity = vec2.mul(self.stickingOffset, config.getParameter("wfStickingOffsetMultiplier",-1))
      mcontroller.setVelocity(stickingVelocity)
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
  if self.hasStruckTarget and not self.retainDamage then
    projectile.setPower(0)
  end
end

function nebUpdateAimPosition(aimPosition)
  self.aimPosition = aimPosition
  return true
end

function hit(entityId)
  if not self.stuckToGround and not self.stickingTarget then
    self.stickingTarget = entityId
    mcontroller.setVelocity({0,0})
    self.stuckToTarget = true
    self.stickingOffset = world.distance(mcontroller.position(), world.entityPosition(self.stickingTarget))
    if config.getParameter("stickToTargetTime") then
      projectile.setTimeToLive(config.getParameter("stickToTargetTime"))
    end
  end
  self.hasStruckTarget = true
end

function destroy()
  if self.stuckToTarget then
    for i, action in ipairs(self.stickActionOnReap) do
	  projectile.processAction(action)
    end
  end
end

