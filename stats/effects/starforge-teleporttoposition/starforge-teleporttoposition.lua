require "/scripts/vec2.lua"

function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  
  self.teleportProjectileConfig = config.getParameter("teleportProjectileConfig", {})
  self.blinkOffset = config.getParameter("blinkOffset")
  self.blinkTolerance = config.getParameter("blinkTolerance")
  self.targetPosition = mcontroller.position()
  
  self.baseDuration = effect.duration()
  
  message.setHandler("starforge-setteleportposition", function(_, _, position)
	self.targetPosition = position
  end)
end

function update(dt)
  local fade = string.format("=%.1f", effect.duration() / self.baseDuration)
  effect.setParentDirectives(config.getParameter("directives", "") .. fade)
end

function onExpire()
  local lastPosition = mcontroller.position()
  
  local resolvedPoint = world.resolvePolyCollision(mcontroller.collisionPoly(), vec2.add(self.targetPosition, self.blinkOffset), self.blinkTolerance)
  mcontroller.setPosition(resolvedPoint or self.targetPosition)

  world.spawnProjectile("whipcrackphysical", lastPosition, entity.id(), {0, 0}, false, self.teleportProjectileConfig)
  status.addEphemeralEffect("blinkin")
end