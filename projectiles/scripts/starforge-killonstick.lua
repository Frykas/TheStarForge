local baseUpdate = update
local baseHit = hit

function update(dt)
  if baseUpdate then baseUpdate(dt) end
  
  if (not config.getParameter("canBounce", false)) and (projectile.collision() or mcontroller.isCollisionStuck() or mcontroller.isColliding()) then
	projectile.die()
  end
end

function hit(entityId)
  if baseHit then baseHit(entityId) end
  
  if config.getParameter("killOnHit") then
    projectile.die()
  end
end

