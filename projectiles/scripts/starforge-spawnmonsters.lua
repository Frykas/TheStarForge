function init()
  self.onDeath = config.getParameter("onDeath", false)
  self.forceSpawnPos = config.getParameter("forceSpawnPos", false)
  if not self.onDeath then
    world.spawnStagehand(entity.position(), "starforge-spawnmonster", {
      monsterConfigs = config.getParameter("monsterConfigs"),
      owner = projectile.sourceEntity()
    })
    projectile.die()
  end
end

function uninit()
  if self.onDeath then
    world.spawnStagehand(entity.position(), "starforge-spawnmonster", {
      monsterConfigs = config.getParameter("monsterConfigs"),
      owner = projectile.sourceEntity(),
      forceSpawnPos = self.forceSpawnPos
    })
  end
end