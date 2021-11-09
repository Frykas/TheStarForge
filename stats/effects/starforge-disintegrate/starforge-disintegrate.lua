require "/scripts/util.lua"

function init()  
  animator.setParticleEmitterOffsetRegion("sparks", mcontroller.boundBox())
  animator.setParticleEmitterActive("sparks", true)
  effect.setParentDirectives(config.getParameter("directive"))
  
  self.effectsOnExpire = config.getParameter("effectsOnExpire")
  
  script.setUpdateDelta(5)
end

function update(dt)
  if not status.resourcePositive("health") and status.resourceMax("health") >= config.getParameter("minMaxHealth", 0) then
    effect.setParentDirectives(config.getParameter("deathDirective"))
	explode()
  end
  
  --If the target doesn't die quickly enough, expire this effect and activate the next
  if effect.duration() < 0.25 then
	effect.expire()
  end
end

function explode()
  if not self.exploded then
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), 0, {0, 0}, false)
    self.exploded = true
  end
end

function onExpire()
  if self.effectsOnExpire and not self.exploded then
    for _, effect in pairs(self.effectsOnExpire) do
	  status.addEphemeralEffect(effect, config.getParameter("effectOnExpireDuration", 5), effect.sourceEntity())
    end
  end
end

function uninit()
end
