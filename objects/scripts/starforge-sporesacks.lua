require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  animator.setAnimationState("burstState", "popped")
  object.setInteractive(false)
  
  self.regrowTimer = config.getParameter("regrowTimeOverwrite") or config.getParameter("regrowTime", 5)
  storage.triggered = (self.regrowTimer ~= 0)
end

function update(dt)
  self.regrowTimer = math.max(0, self.regrowTimer - dt)
  if self.regrowTimer == 0 then
	object.setInteractive(true)
	animator.setAnimationState("burstState", "intact")
	
	storage.triggered = false
  end
  
  world.debugText("Regrow Time: " .. self.regrowTimer, entity.position(), "yellow")
end

function onInteraction(args)
  if not storage.triggered then
    burstSack(false)
  end
end

function die(smash)
  if smash and not storage.triggered then
    burstSack(true)
	
    world.spawnProjectile("starforge-placeobject", object.position(), entity.id(), {object.direction(), 0}, false, {
		objectToSpawn = object.name(),
		objectDirection = object.direction(),
		timeToLive = 0,
		regrowTimeOverwrite = self.regrowTimer
	  }
	)
  elseif smash then
    world.spawnProjectile("starforge-placeobject", object.position(), entity.id(), {object.direction(), 0}, false, {
		objectToSpawn = object.name(),
		objectDirection = object.direction(),
		timeToLive = 0,
		regrowTimeOverwrite = self.regrowTimer
	  }
	)
  end
end

function burstSack(smashed)
  storage.triggered = true
  object.setInteractive(false)
  self.regrowTimer = config.getParameter("regrowTime", 5)

  animator.setAnimationState("burstState", "burst")
  animator.playSound("burst")
  animator.burstParticleEmitter("burst")
  
  local params = sb.jsonMerge(config.getParameter("burstProjectileParameters", {}), {})
  local projectileType = config.getParameter("burstProjectileType", "standardbullet")
  if type(projectileType) ~= "table" then
    projectileType = {projectileType}
  end
  
  for _, projectile in ipairs(projectileType) do
    projectileId = world.spawnProjectile(
        projectile,
        object.position(),
        entity.id(),
        {0, 0},
        false,
        params
      )
  end
end