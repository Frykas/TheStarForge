require "/scripts/vec2.lua"

function init()
  self.techToUnlock = config.getParameter("techToUnlock")
  self.enableTech = config.getParameter("enableTech", false)
  self.equipTech = config.getParameter("equipTech", false)
  self.consumeOnUse = config.getParameter("consumeOnUse", true)
  self.techUnlockText = config.getParameter("techUnlockText", "Tech Unlocked")
  
  self.activated = false
  self.unlockAccepted = false
end

function update(dt, fireMode, shiftHeld)
  updateAim()

  --If pressing mouse button, attempt to add the tech
  if fireMode == "primary" and not self.activated then
	self.activated = true
	if canUnlock() then
	  
	  player.makeTechAvailable(self.techToUnlock)
	  if self.enableTech then
	    player.enableTech(self.techToUnlock)
		if self.equipTech then
		  player.equipTech(self.techToUnlock)
		end
	  end
	  
	  animator.playSound("unlock")
	  spawnText()
	  if self.consumeOnUse then
		item.consume(1)
	  end
	else
	  animator.playSound("fail")
	end
  end
  
  if fireMode ~= "primary" and self.activated and not self.unlockAccepted then
	self.activated = false
  end
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function spawnText()
  local displayPosition = vec2.add(mcontroller.position(), {0, 3})
  
  params = {}  
  params.actionOnReap = {
    {
      action = "particle",
      specification = {
		type = "text",
		text = "^shadow;" .. self.techUnlockText,
		color = {255, 255, 255, 255},
		fullbright = true,
		size = 2,
		approach = {0, 0},
		angularVelocity = 0,
		timeToLive = 0.7,
		layer = "front",
		destructionAction = "shrink",
		destructionTime = 0.5,
		flippable = false
	  }
    }
  }
  params.timeToLive = 0
  
  local projectileId = world.spawnProjectile(
    "invisibleprojectile",
    displayPosition,
    entity.id(),
    {0, 0},
    false,
    params
  )
end

function canUnlock()
  local canUnlock = true
  if self.enableTech then
    for _, tech in ipairs(player.enabledTechs()) do
      if tech == self.techToUnlock then
	    canUnlock = false
	  end
    end
  else
    for _, tech in ipairs(player.availableTechs()) do
      if tech == self.techToUnlock then
	    canUnlock = false
	  end
    end
  end
  return canUnlock
end
