function update()
  if projectile.collision() or mcontroller.isCollisionStuck() or mcontroller.isColliding() then
	projectile.die()
  end
end
