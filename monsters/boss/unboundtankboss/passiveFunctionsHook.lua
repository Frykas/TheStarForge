local oldInit = init
function init(...)
  self.bossStartPosition = mcontroller.position()
  self.trackAnimationTimer = 0
  self.warpGraceTimer = 2
  
  return oldInit(...)
end

local oldUpdate = update
function update(dt, ...)
  if hasTarget() then
    if status.resourcePositive("health") then
      mcontroller.setXVelocity((config.getParameter("movementSpeed", 16) * (1 - (status.resource("health") / status.resourceMax("health")))) + 2)
    elseif not status.resourcePositive("health") or mcontroller.xVelocity() == 0 then
      mcontroller.setXVelocity(0)
    end
	
	updateTankTracks(dt)
	
	self.warpGraceTimer = math.max(0, self.warpGraceTimer - dt)
	if self.warpGraceTimer == 0 then
	  for _, target in ipairs(self.targets) do 
	   if world.distance(world.entityPosition(target), mcontroller.position())[1] < 0 then
	      world.sendEntityMessage(target, "applyStatusEffect", "burning", 5)
	      world.sendEntityMessage(target, "applyStatusEffect", "starforge-teleporttoposition", 1)
		
	      world.sendEntityMessage(target, "starforge-setteleportposition", vec2.add(mcontroller.position(), {20, 2}))
		  self.warpGraceTimer = 1.125
	    end
	  end
    end
  end
  
  return oldUpdate(dt, ...)
end

function returnToStartPosition()
  mcontroller.setPosition(self.bossStartPosition)
end

function updateTankTracks(dt)
  self.trackAnimationTimer = (self.trackAnimationTimer + (dt * (mcontroller.xVelocity() * config.getParameter("trackAnimationSpeed", 1)))) % 1
  local trackAnimationFrame = math.floor(self.trackAnimationTimer * config.getParameter("trackAnimationFrames", 1))
	
  animator.setGlobalTag("trackAnimationFrame", trackAnimationFrame)
end