require "/scripts/vec2.lua"
require "/scripts/util.lua"

local oldInit = init
function init()
  if oldInit then oldInit() end
  
  self.maxWaves = config.getParameter("maxWaves", -1)
  self.waves = 0
  
  --Seting up the sine wave movement
  self.wavePeriod = config.getParameter("wavePeriod") / (2 * math.pi)
  self.waveAmplitude = config.getParameter("waveAmplitude")

  self.timer = self.wavePeriod * 0.25
  local vel = mcontroller.velocity()
  if vel[1] < 0 then
    self.waveAmplitude = -self.waveAmplitude
  end
  self.lastAngle = 0
end

local oldUpdate = update
function update(dt)  
  if oldUpdate then oldUpdate(dt) end
  
  --Move the projectile in a sine wave motion by adjusting velocity direction
  if (self.maxWaves == -1) or (self.waves < self.maxWaves) then
	self.timer = self.timer + dt
	local newAngle = self.waveAmplitude * math.sin(self.timer / self.wavePeriod)

	mcontroller.setVelocity(vec2.rotate(mcontroller.velocity(), newAngle - self.lastAngle))

	self.lastAngle = newAngle
	
	--Count up the waves we've completed
	self.waves = self.timer / self.wavePeriod / (2 * math.pi)
  end
end
