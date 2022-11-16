require "/scripts/util.lua"

function init()
  self.spinDirection = config.getParameter("spinDirection", 1)
  self.spinRate = config.getParameter("spinRate", 0.5)
end

function update(dt)
  --Spinning
  local direction = util.toDirection(mcontroller.velocity()[1]) * self.spinDirection
  mcontroller.setRotation(mcontroller.rotation() + (self.spinRate * (dt * direction)))
end