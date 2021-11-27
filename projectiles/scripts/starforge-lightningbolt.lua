require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.timeToLive = projectile.timeToLive()
  self.minChangeInterval = config.getParameter("minChangeInterval")
  self.maxChangeInterval = config.getParameter("maxChangeInterval")
  self.minAngle = config.getParameter("minAngle")
  self.maxAngle = config.getParameter("maxAngle")
  
  self.searchDistance = config.getParameter("searchRadius")
  self.homingStrength = config.getParameter("homingStrength")
  
  self.originalAngle = util.toDegrees(vec2.angle(mcontroller.velocity()))
  self.cooldownTimer = math.random(self.minChangeInterval * 1000, self.maxChangeInterval * 1000) / 1000
  
  self.advancedPeriodicActions = config.getParameter("advancedPeriodicActions", {})
  
  if config.getParameter("randomStartAngle") then
	if math.random() >= 0.5 then
	  self.lastAngleUp = true
	else
	  self.lastAngleUp = false
	end
  end
end

function update(dt)
  --Advanced Periodic Action
  for _, action in pairs(self.advancedPeriodicActions) do
    action = advancedPeriodicActions(action, dt, _)
  end

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  self.currentAngle = util.toDegrees(vec2.angle(mcontroller.velocity()))
  
  --After the specified interval has elapsed, rotate our velocity up or down
  if self.cooldownTimer == 0 then
	local rotateByAngle = math.random(self.minAngle, self.maxAngle)
	
	--Optionally reverse rotation angle
	if isAngleAbove(self.currentAngle, self.originalAngle) then
	  rotateByAngle = rotateByAngle * -1
	end
	
	--Apply rotation and reset cooldown
	mcontroller.setVelocity(vec2.rotate(mcontroller.velocity(), util.toRadians(rotateByAngle)))
	self.cooldownTimer = math.random(self.minChangeInterval * 1000, self.maxChangeInterval * 1000) / 1000
  end
  
  --Optionally apply homing
  if self.homingStrength and self.searchDistance then
	local targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
      includedTypes = {"creature"},
      order = "nearest"
    })

	for _, target in ipairs(targets) do
	  if entity.entityInSight(target) then
		local distance = world.distance(world.entityPosition(target), mcontroller.position())
		local angleToTarget = util.toDegrees(vec2.angle(distance))
		
		if isAngleAbove(angleToTarget, self.originalAngle) then
		  world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), vec2.withAngle(util.toRadians(angleToTarget), 2)), "blue")
		  self.originalAngle = self.originalAngle + (self.homingStrength * dt)
		else
		  world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), vec2.withAngle(util.toRadians(angleToTarget), 2)), "pink")
		  self.originalAngle = self.originalAngle - (self.homingStrength * dt)
		end
		return
	  end
	end
  end
  
  self.targetSpeed = vec2.mag(mcontroller.velocity())
  
  --Code for ensuring a constant speed
  local currentVelocity = mcontroller.velocity()
  local newVelocity = vec2.mul(vec2.norm(currentVelocity), self.targetSpeed)
  mcontroller.setVelocity(newVelocity)
end

function advancedPeriodicActions(action, dt, index)
  if action.action == "projectile" and action.taperTrailParticle then
	local modifier = 0.625 + (projectile.timeToLive() * 2)
    action.config.scaleModifier = modifier
  end
  if action.terminateOnDeath then
	if action.action == "projectile" then
	  action.config.timeToLive = projectile.timeToLive()
	elseif action.action == "particle" then
	  action.specification.timeToLive = projectile.timeToLive()
	end
  elseif action.beginDestructionOnDeath then
	if action.action == "projectile" then
	  action.config.timeToLive = projectile.timeToLive() + self.timeToLive
	elseif action.action == "particle" then
	  action.specification.destructionTime = projectile.timeToLive() / 2
	end
  end
  
  if action.complete then
	return action
  elseif action.delayTime then
	action.delayTime = action.delayTime - dt
	if action.delayTime <= 0 then
	  action.delayTime = nil
	end
  elseif action.loopTime and action.loopTime ~= -1 then
	action.loopTimer = action.loopTimer or 0
	action.loopTimer = math.max(0, action.loopTimer - dt)
	if action.loopTimer == 0 then
	  action.loopTimer = action.loopTime
	  if action.loopTimeVariance then
	    action.loopTimer = action.loopTimer + (2 * math.random() - 1) * action.loopTimeVariance
	  end
	  projectile.processAction(action)
	end
  else
	projectile.processAction(action)
	action.complete = true
  end
end

-- Returns true if the current angle is above the reference angle
function isAngleAbove(angle, reference)
  -- If the angles are the same, randomize output
  if (angle == reference) then
	return math.random() >= 0.5
  end
  
  local difference = (angle - reference + 180 + 360) % 360 - 180  
  if difference <= 180 and difference >= 0 then
	return true
  else
	return false
  end
end