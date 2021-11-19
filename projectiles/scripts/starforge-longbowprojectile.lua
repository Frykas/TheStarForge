require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.basePosition = mcontroller.position()
  
  self.teleportPiercing = config.getParameter("teleportPiercing", false)
  self.teleportDelay = config.getParameter("teleportDelay", 0.1)
  self.teleportGenerosity = config.getParameter("teleportGenerosity", 2)
  self.teleportRange = config.getParameter("teleportRange", 15)
  
  self.teleportOutActions = config.getParameter("teleportOutActions", {})
  self.teleportInActions = config.getParameter("teleportInActions", {})
  
  self.hasTeleported = false
end

function update(dt)
  self.teleportDelay = math.max(0, self.teleportDelay - dt)
  if self.teleportDelay == 0 and not self.hasTeleported then
    teleport()
	self.hasTeleported = true
  end
end

function teleport()
  --Optionally process the teleport out actions
  if self.teleportOutActions then
	for _, action in pairs(self.teleportOutActions) do
	  projectile.processAction(action)
	end
  end
  
  local teleportPosition = vec2.add(mcontroller.position(), vec2.mul(vec2.norm(mcontroller.velocity()), self.teleportRange))
  local groundPositionAndNormal = world.lineTileCollisionPoint(mcontroller.position(), teleportPosition) or {teleportPosition}
  self.targetPosition = groundPositionAndNormal[1]
  
  if self.teleportPiercing == false then
	local targets = world.entityLineQuery(mcontroller.position(), self.targetPosition, {
	  withoutEntityId = projectile.sourceEntity(),
	  includedTypes = {"creature"},
	  order = "nearest"
    })
	for _, target in ipairs(targets) do
	  --Make sure we can damage the targeted entity
	  if world.entityCanDamage(projectile.sourceEntity(), target) then
		local targetPosition = world.entityPosition(target)
		--Make sure we have line of sight on this entity
		if not world.lineCollision(mcontroller.position(), targetPosition) then
		  local vectorBack = vec2.mul(vec2.norm(world.distance(self.basePosition, targetPosition)), self.teleportGenerosity)
		  self.targetPosition = vec2.add(targetPosition, vectorBack)
		end
	  end
	end
  end
  
  --Optionally move the projectile back a little so it doesnt instantly collide
  local vectorBack =  vec2.mul(vec2.norm(mcontroller.velocity()), -self.teleportGenerosity)
  self.targetPosition = vec2.add(self.targetPosition, vectorBack)
  
  mcontroller.setPosition(self.targetPosition)
  
  --Optionally process the teleport in actions
  if self.teleportInActions then
	for _, action in pairs(self.teleportInActions) do
	  projectile.processAction(action)
	end
  end
end
