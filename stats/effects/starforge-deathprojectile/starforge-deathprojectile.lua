require "/scripts/util.lua"

function update(dt)
  if not status.resourcePositive("health") and status.resourceMax("health") >= config.getParameter("minMaxHealth", 0) then
	explode()
  end
end

function explode()
  if not self.exploded then
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), 0, {0, 0}, false)
    self.exploded = true
	effect.expire()
  end
end