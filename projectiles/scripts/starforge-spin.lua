require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.spinDirection = config.getParameter("spinDirection", -1)
  self.spinRate = config.getParameter("spinRate", 0.5)
  self.minSpinSpeed = config.getParameter("minSpinSpeed", 25)
  self.ignoreVelocity = config.getParameter("ignoreVelocity", false)
  self.countMovementDirection = config.getParameter("countMovementDirection", false)
end

function update(dt)
  --Spinning
  local direction = (self.countMovementDirection and util.toDirection(mcontroller.velocity()[1]) or 1) * self.spinDirection
  local speed = math.max(self.minSpinSpeed, self.ignoreVelocity and 1 or vec2.mag(mcontroller.velocity()))
  mcontroller.setRotation(mcontroller.rotation() + (speed * self.spinRate) * (dt * direction))
end