require "/scripts/vec2.lua"

function init()
  self.projectileType = config.getParameter("projectileType", "aviantrapbeam")
  self.fireInterval = config.getParameter("fireInterval", 0.05)
  self.baseDps = config.getParameter("baseDps", 20)
  self.spawnOffset = config.getParameter("spawnOffset", {0, 0})

  self.powerMultiplier = status.stat("powerMultiplier")
  if not self.powerMultiplier or self.powerMultiplier == 0 then self.powerMultiplier = 1.0 end
  if world.entityType(entity.id()) == "monster" then
    self.powerMultiplier = self.powerMultiplier * root.evalFunction("monsterLevelPowerMultiplier", world.callScriptedEntity(entity.id(), "monster.level"))
  end

  effect.addStatModifierGroup({
    {stat = "protection", amount = config.getParameter("protection", 85)},
    {stat = "grit", amount = config.getParameter("grit", 1.0)}
  })

  self.cooldownTimer = config.getParameter("startDelay", 0.5)
end

function getSurfaceNormal(pos)
  local checkDist = 1.5
  local bounds = mcontroller.boundBox()

  local touchBelow = world.pointTileCollision({pos[1], pos[2] + bounds[1] - 0.2}, {"Null", "Block", "Dynamic"})
  local touchAbove = world.pointTileCollision({pos[1], pos[2] + bounds[4] + 0.2}, {"Null", "Block", "Dynamic"})
  local touchLeft  = world.pointTileCollision({pos[1] + bounds[1] - 0.2, pos[2]}, {"Null", "Block", "Dynamic"})
  local touchRight = world.pointTileCollision({pos[1] + bounds[3] + 0.2, pos[2]}, {"Null", "Block", "Dynamic"})

  if touchAbove then return {0, -1} end
  if touchLeft then return {1, 0} end
  if touchRight then return {-1, 0} end
  if touchBelow then return {0, 1} end
  return false
end

function update(dt)
  self.cooldownTimer = self.cooldownTimer - dt

  if self.cooldownTimer <= 0 then
    self.cooldownTimer = self.fireInterval

    local pos = mcontroller.position()
    local surfaceNormal = getSurfaceNormal(pos)

    if surfaceNormal then
      mcontroller.setVelocity(vec2.mul(surfaceNormal, -1))

      local aimDirection = surfaceNormal
      local rotationAngle = vec2.angle(surfaceNormal) - (math.pi / 2)

      local facingOffset = {self.spawnOffset[1] * mcontroller.facingDirection(), self.spawnOffset[2]}
      local offset = vec2.rotate(facingOffset, rotationAngle)
      local spawnPos = vec2.add(pos, offset)

      world.spawnProjectile(
        self.projectileType,
        spawnPos,
        entity.id(),
        aimDirection,
        false,
        {
          damageRepeatGroup = "starforge-kluextortoiseconstruct",
          power = self.baseDps * self.powerMultiplier,
          damageTeam = entity.damageTeam()
        }
      )
    end
  end
end

function uninit()
  
end