require "/scripts/vec2.lua"

function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  
  self.teleportProjectileConfig = config.getParameter("teleportProjectileConfig", {})
  self.blinkOffset = config.getParameter("blinkOffset")
  self.blinkTolerance = config.getParameter("blinkTolerance")
  self.targetPosition = mcontroller.position()
  self.maxPitch = config.getParameter("maxPitch", 2) - 1
  animator.playSound("idleLoop", -1)
  
  self.baseDuration = effect.duration()
  
  message.setHandler("starforge-setteleportposition", function(_, _, position)
	self.targetPosition = position
  end)
end

function update(dt)
  local boostPercent = 1 - effect.duration() / self.baseDuration
  local boostPitch = boostPercent * self.maxPitch
  animator.setSoundPitch("idleLoop", 1 + boostPercent)

  local fade = string.format("=%.1f", boostPercent)
  effect.setParentDirectives(config.getParameter("directives", "") .. fade)
end

function onExpire()
  animator.stopAllSounds("idleLoop")
  local lastPosition = mcontroller.position()
  
  local resolvedPoint = world.resolvePolyCollision(mcontroller.collisionPoly(), vec2.add(self.targetPosition, self.blinkOffset), self.blinkTolerance)
  mcontroller.setPosition(resolvedPoint or self.targetPosition)

  world.spawnProjectile("whipcrackphysical", lastPosition, entity.id(), {0, 0}, false, self.teleportProjectileConfig)
  status.addEphemeralEffect("blinkin")
end