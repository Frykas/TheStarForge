function update()
  if projectile.collision() or mcontroller.isCollisionStuck() or mcontroller.isColliding() then
	projectile.die()
  end
end

function hit(entityId)
sb.logInfo("hit")
  if config.getParameter("killOnHit") then
    projectile.die()
  end
end

