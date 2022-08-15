require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  --Slow our energy regen
  effect.addStatModifierGroup({
	{stat = "energyRegenPercentageRate", effectiveMultiplier = config.getParameter("regenMultiplier", 0.8)},
	{stat = "energyRegenBlockTime", effectiveMultiplier = config.getParameter("regenBlockTimeMultiplier", 1.2)}
  })
  
  --Healing block check
  self.healthLastFrame = status.resource("health")
  
  --Projectile stats
  self.projectileCount = config.getParameter("projectileCount")
  self.sourceEntity = effect.sourceEntity()
  self.tickTime = config.getParameter("tickTime", 1)
  self.tickTimer = self.tickTime
end

function update(dt)
  --Slow victims movement
  mcontroller.controlModifiers(config.getParameter("mcontrollerModifiers", {
    groundMovementModifier = 0.75,
	speedModifier = 0.75,
	airJumpModifier = 0.90
  }))
  
  --Manually block healing so cheeky heals from op stuff do not work
  if status.resource("health") > self.healthLastFrame then
	status.setResource("health", self.healthLastFrame)
  end
  self.healthLastFrame = status.resource("health")
  
  --Projectile effect
  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
	sb.logInfo(status.resource("health"))
    self.tickTimer = self.tickTime
	spawnProjectiles()
  end
end

function spawnProjectiles()
  if world.entityExists(self.sourceEntity) then
	local projectileNumber = 0
	for i = 1, self.projectileCount do
	  projectileNumber = projectileNumber + 1
	
	  local aimVec = vec2.rotate({0, 1}, (360 / (config.getParameter("projectileCount") + 1) * projectileNumber) + math.random(360))
	
	  if config.getParameter("directPath", false) then
	    aimVec = {0, 0}
	  end
	
	  local projectileId = world.spawnProjectile(config.getParameter("projectileType"), mcontroller.position(), nil, aimVec, false)
	  if projectileId then
	    world.sendEntityMessage(projectileId, "setTargetEntity", self.sourceEntity)
	    self.projectileSpawned = true
	  end
	end
  end
end