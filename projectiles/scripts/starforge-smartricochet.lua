require "/scripts/vec2.lua"
require "/scripts/util.lua"

starforge_smartRicochet_init = init
function init(...) if starforge_smartRicochet_init then starforge_smartRicochet_init(...) end
  self.lastVelocity = mcontroller.velocity()

  self.ricochetProjectileType = config.getParameter("ricochetProjectileType", config.getParameter("projectileName"))
  self.ricochetCount = config.getParameter("ricochetCount", 1)
  self.ricochetDamageMultiplier = config.getParameter("ricochetDamageMultiplier", 0.95)
  self.ricochetQueryRange = config.getParameter("ricochetQueryRange", 50)
  self.excludedEntityId = nil

  self.targetSpeed = config.getParameter("speed", 50)
end

starforge_smartRicochet_update = update
function update(dt) if starforge_smartRicochet_update then starforge_smartRicochet_update(dt) end
  local collision = world.lineTileCollisionPoint(mcontroller.position(), vec2.add(mcontroller.position(), vec2.mul(vec2.norm(mcontroller.velocity()), 2)))
  if collision then
    ricochet(collision)
  end
  self.lastVelocity = mcontroller.velocity()
end

starforge_smartRicochet_hit = hit
function hit(entityId) if starforge_smartRicochet_hit then starforge_smartRicochet_hit(entityId) end
  if config.getParameter("ricochetOffEnemies") then
    self.excludedEntityId = entityId
    ricochet()
  end
end

function ricochet(collision)
  collision = collision or {mcontroller.position(), vec2.rotate({0, 0}, math.random() * math.pi * 2)}
  if self.ricochetCount > 0 or self.ricochetCount == -1 then
    local velocityMultiplier = {math.abs(collision[2][1]) == 0 and 1 or math.abs(collision[2][1]) * -1, math.abs(collision[2][2]) == 0 and 1 or math.abs(collision[2][2]) * -1}
    local trajectoryVector = vec2.norm(vec2.mul(self.lastVelocity, velocityMultiplier))
    
    local targets = world.entityQuery(mcontroller.position(), self.ricochetQueryRange, {
        includedTypes = {"creature"},
        order = "nearest",
        withoutEntityId = self.excludedEntityId
      })

    for _, target in ipairs(targets) do
      if world.entityExists(target) and entity.entityInSight(target) and world.entityCanDamage(entity.id(), target) then
        trajectoryVector = world.distance(world.entityPosition(target), entity.position())

        break
        return
      end
    end

    for _, action in ipairs(config.getParameter("actionOnRicochet", {})) do 
      projectile.processAction(action)
    end
    if self.ricochetCount > 0 then
      self.ricochetCount = self.ricochetCount - 1
    end

    projectile.setPower(projectile.power() * self.ricochetDamageMultiplier)

    mcontroller.setVelocity(vec2.mul(vec2.norm(trajectoryVector), self.targetSpeed))
  else
    projectile.die()
  end
end

starforge_smartRicochet_destroy = destroy
function destroy(...) if starforge_smartRicochet_destroy then starforge_smartRicochet_destroy(...) end
end
