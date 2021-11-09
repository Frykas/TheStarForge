require "/scripts/vec2.lua"

function init()
  self.returning = config.getParameter("returning", false)
  self.returnOnHit = config.getParameter("returnOnHit", false)
  self.pickupDistance = config.getParameter("pickupDistance")
  self.timeToLive = config.getParameter("timeToLive")
  self.speed = config.getParameter("speed")
  self.ownerId = projectile.sourceEntity()

  self.maxDistance = config.getParameter("maxDistance")
  self.stickTime = config.getParameter("stickTime", 0)
  self.hasStuck = false
  
  self.actionOnHold = config.getParameter("actionOnHold")

  self.initialPosition = mcontroller.position()
  self.gunPosition = vec2.sub(self.initialPosition, world.entityPosition(self.ownerId))
end

function update(dt)
  if self.ownerId and world.entityExists(self.ownerId) then	
	--Actions during inital being shot
    if not self.returning then
	  local speed = vec2.mag(mcontroller.velocity())
	  if speed >= self.speed * 0.4 then
	    --Advanced Periodic Action
	    for _, action in pairs(config.getParameter("advancedPeriodicActions", {})) do
	  	  advancedPeriodicActions(action, dt)
	    end
	  end
	  
      if self.stickTimer then
		mcontroller.setVelocity({0,0})
        self.stickTimer = math.max(0, self.stickTimer - dt)
        if self.stickTimer == 0 then
          self.returning = true
        end
      elseif mcontroller.stickingDirection() or mcontroller.isColliding() then
		--Manually stick on collide
        self.stickTimer = self.stickTime	
		if self.actionOnHold and not self.activated then
		  for _, action in pairs(self.actionOnHold) do
			projectile.processAction(action)
		  end
		  self.activated = true
		end
      else
        local distanceTraveled = world.magnitude(mcontroller.position(), self.initialPosition)
        if distanceTraveled > self.maxDistance then
          self.waitTime = self.waitTimer
		  self.returning = true
        end
      end
	--Returning actions
    else
      mcontroller.applyParameters({collisionEnabled=false})
      local toTarget = world.distance(vec2.add(self.gunPosition, world.entityPosition(self.ownerId)), mcontroller.position())
      if vec2.mag(toTarget) < self.pickupDistance then
        projectile.die()
      else
        mcontroller.setVelocity(vec2.mul(vec2.norm(toTarget), self.speed))
      end
	end
  else
    projectile.die()
  end
end

function advancedPeriodicActions(action, dt)
  if action.action == "particle" and action.specification and action.lengthSpeedMultiplier then
    action.specification.length = vec2.mag(mcontroller.velocity()) * action.lengthSpeedMultiplier
  end
  if action.complete then
	return
  elseif action.delayTime then
	action.delayTime = action.delayTime - dt
	if action.delayTime <= 0 then
	  action.delayTime = nil
	end
  elseif action.loopTime and action.loopTime ~= -1 then
	action.loopTimer = action.loopTimer or 0
	action.loopTimer = math.max(0, action.loopTimer - dt)
	if action.loopTimer == 0 then
	  projectile.processAction(action)
	  action.loopTimer = action.loopTime
	  if action.loopTimeVariance then
	    action.loopTimer = action.loopTimer + (2 * math.random() - 1) * action.loopTimeVariance
	  end
	end
  else
	projectile.processAction(action)
	action.complete = true
  end
end

function hit(entityId)
  if self.returnOnHit then 
	self.stickTimer = self.stickTime 
	if self.actionOnHold and not self.activated then
	  for _, action in pairs(self.actionOnHold) do
		projectile.processAction(action)
	  end
	  self.activated = true
	end
  end
end

function projectileIds()
  return {entity.id()}
end
