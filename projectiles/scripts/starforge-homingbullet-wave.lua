require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.targetSpeed = vec2.mag(mcontroller.velocity())
  self.searchDistance = config.getParameter("searchRadius")
  self.maxWaves = config.getParameter("maxWaves", -1)
  self.waves = 0
  
  --Checking which type of homing code to use
  self.homingStyle = config.getParameter("homingStyle", "controlVelocity")
  if self.homingStyle == "controlVelocity" then
	self.controlForce = config.getParameter("baseHomingControlForce") * self.targetSpeed
  elseif self.homingStyle == "rotateToTarget" then
	self.rotationRate = config.getParameter("rotationRate")
	self.trackingLimit = config.getParameter("trackingLimit")
  end
  
  if config.getParameter("homingStartDelay") ~= nil then
	self.homingEnabled = false
	self.countdownTimer = config.getParameter("homingStartDelay")
  else
	self.homingEnabled = true
  end
  
  --Seting up the sine wave movement
  self.wavePeriod = config.getParameter("wavePeriod") / (2 * math.pi)
  self.waveAmplitude = config.getParameter("waveAmplitude") * (config.getParameter("barrel", 1) % 2 == 1 and -1 or 1)

  self.timer = self.wavePeriod * 0.25
  local vel = mcontroller.velocity()
  if vel[1] < 0 then
    self.waveAmplitude = -self.waveAmplitude
  end
  self.lastAngle = 0
end

function update(dt)  
  --Move the projectile in a sine wave motion by adjusting velocity direction
  if (self.maxWaves == -1) or (self.waves < self.maxWaves) then
	self.timer = self.timer + dt
	local newAngle = self.waveAmplitude * math.sin(self.timer / self.wavePeriod)

	mcontroller.setVelocity(vec2.rotate(mcontroller.velocity(), newAngle - self.lastAngle))

	self.lastAngle = newAngle
	
	--Count up the waves we've completed
	self.waves = self.timer / self.wavePeriod / (2 * math.pi)
  end
  
  if self.homingEnabled == true then
	local targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
      withoutEntityId = projectile.sourceEntity(),
      includedTypes = {"creature"},
      order = "nearest"
    })

	if targets[1] then
	  target = targets[1]
	end

	if target then
	  if (config.getParameter("requireLineOfSight", true) and entity.entityInSight(target) or true) and world.entityCanDamage(projectile.sourceEntity(), target) and not (world.getProperty("entityinvisible" .. tostring(target)) and not config.getParameter("ignoreInvisibility", false)) then
		local targetPos = world.entityPosition(target)
		local myPos = mcontroller.position()
		local dist = world.distance(targetPos, myPos)
		local mag = world.magnitude(targetPos, myPos)

		if self.homingStyle == "controlVelocity" then
		  mcontroller.approachVelocity(vec2.mul(vec2.norm(dist), self.targetSpeed), self.controlForce)
		elseif self.homingStyle == "rotateToTarget" then
		  local vel = mcontroller.velocity()
		  local angle = vec2.angle(vel)
		  local toTargetAngle = util.angleDiff(angle, vec2.angle(dist))
		  
		  if math.abs(toTargetAngle) > self.trackingLimit then
			return
		  end

		  local rotateAngle = math.max(dt * -self.rotationRate, math.min(toTargetAngle, dt * self.rotationRate))

		  vel = vec2.rotate(vel, rotateAngle)
		  mcontroller.setVelocity(vel)
		end
		
		if config.getParameter("dieDistance", false) and mag < config.getParameter("dieDistance", 2) then
		  projectile.die()
		end
	  end
	end
  else
	self.countdownTimer = math.max(0, self.countdownTimer - dt)
	if self.countdownTimer == 0 then
	  self.homingEnabled = true
	end
  end
end
