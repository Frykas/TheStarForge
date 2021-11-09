require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  if storage.triggered then
    animator.setAnimationState("burstState", "open")
  end
  object.setInteractive(not storage.triggered)
end

function onInteraction(args)
  if not storage.triggered then
    openObject(false)
  end
end

function die(smash)
  if config.getParameter("explodeOnSmash") and smash then
    world.spawnProjectile(config.getParameter("explosionProjectile"), vec2.add(object.position(), config.getParameter("explosionOffset", {0,0})), entity.id(), {0,0})
  elseif smash and not storage.triggered then
    openObject(true)
  end
  
  if config.getParameter("brokenObjectName") and smash then
    world.spawnProjectile("starforge-brokenobjectdelay", object.position(), entity.id(), {object.direction(), 0}, false, {
		objectToSpawn = config.getParameter("brokenObjectName"),
		objectDirection = object.direction(),
		timeToLive = 0
	  }
	)
  end
end

function openObject(smashed)
  storage.triggered = true
  object.setInteractive(false)

  animator.setAnimationState("burstState", "burst")
  animator.playSound("burst")
  animator.burstParticleEmitter("burst")

  local burstIntangibleTimeRange = config.getParameter("burstIntangibleTimeRange", {0, 0})
  local burstVelocityRange = config.getParameter("burstItemVelocityRange", {20, 40})
  if not smashed then
    burstVelocityRange[1] = burstVelocityRange[1] * 0.75
    burstVelocityRange[2] = burstVelocityRange[2] * 0.75
  end
  
  local burstAngleVariance = config.getParameter("burstItemAngleVariance", 0.5)
  local burstOffset = config.getParameter("burstOffset", {0, 0})
  burstOffset[1] = burstOffset[1] * object.direction()
  local burstPosition = vec2.add(entity.position(), burstOffset)
  local burstTreasure = root.createTreasure(config.getParameter("burstTreasurePool"), world.threatLevel())
  for _, item in ipairs(burstTreasure) do
    local velocity = vec2.withAngle(sb.nrand(burstAngleVariance, math.pi / 2), util.randomInRange(burstVelocityRange))
    world.spawnItem(item, burstPosition, 1, nil, velocity, util.randomInRange(burstIntangibleTimeRange))
  end
end