require "/scripts/vec2.lua"

function init()
  self.maxTeleportChance = config.getParameter("maxTeleportChance", 0.025)
  self.currentTeleportChance = 0
  
  self.maxTeleportDistance = config.getParameter("maxTeleportDistance", 5)
  self.teleportInterval = effect.duration() / config.getParameter("minTeleportCount", 3)
  self.timer = 0
  
  self.teleportProjectileConfig = config.getParameter("teleportProjectileConfig", {})
  self.blinkOffset = config.getParameter("blinkOffset", {})
  self.blinkTolerance = config.getParameter("blinkTolerance", 2)
end

function update(dt)
  self.currentTeleportChance = (self.timer / self.teleportInterval) * self.maxTeleportChance
  if (self.timer >= self.teleportInterval) or (math.random() < (self.maxTeleportChance * dt)) then
    teleport()
	self.timer = 0
  end
  self.timer = self.timer + dt
end

function teleport()
  local lastPosition = mcontroller.position()
  
  local targetPosition = vec2.add({(math.random() * self.maxTeleportDistance) - (self.maxTeleportDistance * 0.5), (math.random() * self.maxTeleportDistance) - (self.maxTeleportDistance * 0.5)}, lastPosition)
  
  local resolvedPoint = targetPosition
  if world.isTileProtected(lastPosition) or world.isTileProtected(resolvedPoint) then
    local newPos, norm = world.lineTileCollisionPoint(lastPosition, resolvedPoint)
    resolvedPoint = world.resolvePolyCollision(mcontroller.collisionPoly(), vec2.add(newPos, self.blinkOffset), self.blinkTolerance)  
  end
  mcontroller.setPosition(resolvedPoint)

  world.spawnProjectile("whipcrackphysical", lastPosition, entity.id(), {0, 0}, false, self.teleportProjectileConfig)
  status.addEphemeralEffect("blinkin")
  animator.playSound("teleport")
end

function onExpire()
  teleport()
end