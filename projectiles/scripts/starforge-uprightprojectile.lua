require "/scripts/vec2.lua"

function init()
end

function update(dt)
  if self.hitGround or mcontroller.onGround() then
    mcontroller.setRotation(0)
    self.hitGround = true
  else
    if config.getParameter("rotateInAir") then
      mcontroller.setRotation(math.atan(mcontroller.velocity()[2], mcontroller.velocity()[1]))
	end
	if config.getParameter("alwaysUpright", true) then
      mcontroller.setRotation(0)
	end
  end
end