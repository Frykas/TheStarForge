require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.validEntityTypes = config.getParameter("validEntityTypes", { "player", "npc", "monster" })
  self.hitsBeforeReturning = config.getParameter("hitsBeforeReturning", -1)
  self.stickToTarget = config.getParameter("stickToTarget", false)
  self.actionOnUnstick = config.getParameter("actionOnUnstick", {})
  self.randomUnstickLaunchAngle = config.getParameter("randomUnstickLaunchAngle", true)
  
  self.actionOnStick = config.getParameter("actionOnStick", {})
  self.damageMultiplierOnStick = config.getParameter("damageMultiplierOnStick", 1)

  projectile.setPower(config.getParameter("initialDamageMultiplier", 1) * projectile.power())
  self.baseDamage = projectile.power()
  
  self.stickingOffset = {0, 0}
  self.hasActioned = false

  self.returning = config.getParameter("returning", false)
  self.returnOnBounce = config.getParameter("returnOnBounce", true)
  self.controlForce = config.getParameter("controlForce")
  self.pickupDistance = config.getParameter("pickupDistance")
  self.snapDistance = config.getParameter("snapDistance")
  self.timeToLive = config.getParameter("timeToLive")
  self.stickTime = config.getParameter("damageRepeatTimeout") and (config.getParameter("damageRepeatTimeout") * math.abs(self.hitsBeforeReturning)) or (self.timeToLive * 0.5)
  self.speed = config.getParameter("targetSpeed") or config.getParameter("speed")
  self.ignoreTerrain = config.getParameter("ignoreTerrain")
  self.ownerId = projectile.sourceEntity()
  self.minVelocity = config.getParameter("minVelocity", 0.2)

  if self.ignoreTerrain then mcontroller.applyParameters({collisionEnabled=false}) end

  message.setHandler("projectileIds", projectileIds)

  message.setHandler("setTargetPosition", function(_, _, targetPosition)
      self.targetPosition = targetPosition
    end)
	
  message.setHandler("returnToSender", function()
      setReturning()
    end)

  if boomerangExtra then
    boomerangExtra:init()
  end
end

function update(dt)
  if self.ownerId and world.entityExists(self.ownerId) then
    if boomerangExtra then
      boomerangExtra:update(dt)
    end
    
    if not self.stickingTarget and self.returnOnBounce and mcontroller.isColliding() then
      self.returning = true
    end

    if self.stickingTarget and not self.hasHadTarget then
      if world.entityExists(self.stickingTarget) then
        if not self.hasActioned then
          for i, action in ipairs(self.actionOnStick) do
            projectile.processAction(action)
          end
          self.hasActioned = true
        end
        self.stickTime = self.stickTime - dt
        local targetStickingPosition = vec2.add(world.entityPosition(self.stickingTarget), self.stickingOffset)
        mcontroller.setPosition(targetStickingPosition)
        local stickingVelocity = self.stickingOffset
        mcontroller.setVelocity(stickingVelocity)
        if self.stickTime <= 0 then
          unstickFromEnemy()
        end
      else
        unstickFromEnemy()
      end
    elseif not self.returning then
      mcontroller.approachVelocity({0, 0}, self.controlForce)
      if (not self.ignoreTerrain and mcontroller.isColliding()) or vec2.mag(mcontroller.velocity()) < self.minVelocity then
        self.returning = true
      end
    else
      local toTarget = world.distance(self.targetPosition or world.entityPosition(self.ownerId), mcontroller.position())
      if vec2.mag(toTarget) < self.pickupDistance then
        projectile.die()
      elseif projectile.timeToLive() < self.timeToLive * 0.5 then
        mcontroller.applyParameters({collisionEnabled=false})
        mcontroller.approachVelocity(vec2.mul(vec2.norm(toTarget), self.speed), 500)
      elseif vec2.mag(toTarget) < self.snapDistance then
        mcontroller.approachVelocity(vec2.mul(vec2.norm(toTarget), self.speed), 500)
      else
        mcontroller.approachVelocity(vec2.mul(vec2.norm(toTarget), self.speed), 2 * self.controlForce)
      end
    end
  else
    self.ownerId = nil
    self.findOwner = true
  end
end

function hit(entityId)
  if entityValid(entityId) then
    if self.hitsBeforeReturning ~= -1 then
      self.hitsBeforeReturning = self.hitsBeforeReturning - 1
      if self.hitsBeforeReturning <= 0 then
        unstickFromEnemy()
      end
    end

    if self.stickToTarget and entityId and world.entityExists(entityId) then
      local enemyPos = world.entityPosition(entityId)
      local dist = world.magnitude(enemyPos, mcontroller.position())
      if dist > 4 then
        mcontroller.setPosition(enemyPos)
      end

      self.stickingTarget = entityId
      self.stickingOffset = world.distance(mcontroller.position(), world.entityPosition(self.stickingTarget))
      
      projectile.setPower(self.baseDamage * self.damageMultiplierOnStick)
    end
  end
end

function entityValid(entityId)
  local valid = false
  for _, type in ipairs(self.validEntityTypes) do
    if world.entityType(entityId) == type then
      valid = true
    end
  end
  return valid
end

function uninit()
  if config.getParameter("messageOnCollect") and self.ownerId then
		world.sendEntityMessage(self.ownerId, config.getParameter("messageOnCollect"))
	end
end

function projectileIds()
  if boomerangExtra and boomerangExtra.projectileIds then
    return boomerangExtra:projectileIds()
  else
    return {entity.id()}
  end
end

function unstickFromEnemy()
  self.returning = true
  if self.stickingTarget then
    self.hasHadTarget = self.stickingTarget
    for i, action in ipairs(self.actionOnUnstick) do
      projectile.processAction(action)
    end
    self.stickingTarget = nil
    projectile.setPower(self.baseDamage)

    if self.randomUnstickLaunchAngle then
      local randomAngle = math.random() * math.pi * 2
      local randomVec = vec2.rotate({self.speed * 0.5, 0}, randomAngle)
      mcontroller.setVelocity(randomVec)
    end
  end
end

function setTargetPosition(targetPosition)
  self.targetPosition = targetPosition
end

starforge_sticking_advancedPeriodicActions = advancedPeriodicActions
function advancedPeriodicActions(action, dt, index)
  if action.requiresSticking and not self.stickingTarget then
    return action
  end

  starforge_sticking_advancedPeriodicActions(action, dt, index)
end