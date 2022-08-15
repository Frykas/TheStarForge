function init()
  self.parameters = config.getParameter("lightningParameters", {})
  self.parameters.hostProjectile = entity.id()
  self.parameters.hostEntity = projectile.sourceEntity()
  self.parameters.hostVelocity = mcontroller.velocity()
  self.parameters.power = projectile.power()
  --sb.logInfo("POWER IS %s", projectile.power())
  self.parameters.damageTeamType = "friendly"
  self.parameters.level = 1
end

function update(dt)
  if not self.chainLightningCompanion then
    self.chainLightningCompanion = true
	world.spawnMonster(
	  "starforge-projectilelightningchain",
	  mcontroller.position(),
	  self.parameters
	)
  end
end

function detonate()
  projectile.die()
end