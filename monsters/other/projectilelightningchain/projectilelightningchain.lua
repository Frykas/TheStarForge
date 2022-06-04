require "/scripts/starforge-util.lua"
require "/scripts/vec2.lua"

function init()
  self.hostProjectile = config.getParameter("hostProjectile")
  self.hostVelocity = config.getParameter("hostVelocity")
  self.hostEntity = config.getParameter("hostEntity")
  self.lightningConfig = config.getParameter("lightningConfig")
  self.chainLightningRadius = config.getParameter("chainLightningRadius")
  
  self.tickRate = config.getParameter("tickRate")
  self.tickTimer = 0
  self.power = config.getParameter("power") * self.tickRate
  self.damageKind = config.getParameter("damageKind")
  self.statusEffects = config.getParameter("statusEffects", {})
  
  self.defaultBoltConfig = {
	displacement = 1.5,
	minDisplacement = 0.5,
	forks = 0.5,
	forkAngleRange = 0.1,
	width = 1,
	color = {96, 184, 234, 200}
  }
end

function update(dt)
  if self.hostProjectile and world.entityExists(self.hostProjectile) then
    mcontroller.setPosition(vec2.add(world.entityPosition(self.hostProjectile), vec2.mul(self.hostVelocity, dt)))
    updateChainLightning(dt)
  else
    status.setResource("health", 0)
  end
end

function updateChainLightning(dt)
  self.tickTimer = math.max(0, self.tickTimer - dt)
  
  local nearbyEnemies = world.entityQuery(
	mcontroller.position(),
	self.chainLightningRadius,
	{
	  withoutEntityId = entity.id(),
      includedTypes = {"creature"},
      order = "nearest"
    }
  )
  castBoltMultiple(nearbyEnemies, self.lightningConfig)
end

function castBoltMultiple(targets, lightning)
  if self.tickTimer == 0 then
    for i, target in ipairs(targets) do
	  if entity.entityInSight(target) and world.entityCanDamage(self.hostEntity, target) and world.entityExists(target) then		
	    --Deal damage
	    local damageRequest = {
		  damageType = "Damage",
		  damage = self.power,
		  damageSourceKind = self.damageKind,
		  sourceEntityId = self.hostEntity
	    }
	    world.callScriptedEntity(target, "status.applySelfDamageRequest", damageRequest)
		for _, effect in ipairs(self.statusEffects) do
		  world.sendEntityMessage(target, "applyStatusEffect", effect)
	    end
	    self.tickTimer = self.tickRate
	  end
    end
  end

  self.lightningBolts = {}
  for i, target in ipairs(targets) do
	if entity.entityInSight(target) and world.entityCanDamage(self.hostEntity, target) and world.entityExists(target) then		
	  --Draw lightning
      local bolt = nebUtil.copyTable(lightning or self.defaultBoltConfig, 1)
      bolt.worldStartPosition = mcontroller.position()
      bolt.worldEndPosition = world.entityPosition(target)
      table.insert(self.lightningBolts, bolt)
      table.insert(self.lightningBolts, bolt)
	end
  end

  monster.setAnimationParameter("lightning", self.lightningBolts)
  monster.setAnimationParameter("lightningSeed", math.floor((os.time() + (os.clock() % 1)) * 1000))
end

function uninit()
end

