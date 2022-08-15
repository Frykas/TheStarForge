--Made by Nebulox
require "/scripts/behavior.lua"
require "/scripts/pathing.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"
require "/scripts/drops.lua"
require "/scripts/status.lua"
require "/scripts/companions/capturable.lua"
require "/scripts/tenant.lua"
require "/scripts/actions/movement.lua"
require "/scripts/actions/animator.lua"
require "/scripts/messageutil.lua"

-- Engine callback - called on initialization of entity
function init()
  --Seting up the custom behaviour
  self.hoverTimer = 0
  self.hoverCycleLength = 1
  self.hoverCycleDuration = 0.75
  self.customState = "idle"
  
  self.hostileStatusEffect = config.getParameter("hostileStatusEffect", "burning")
  self.friendlyStatusEffect = config.getParameter("friendlyStatusEffect", "healing")
  
  self.scanRange = 15
  
  self.orbitRange = 3
  self.orbitTimer = 0
  self.orbitRate = 1
  
  self.parentEntity = config.getParameter("parentEntity")
  self.pathing = {}

  self.shouldDie = true
  self.notifications = {}
  storage.spawnTime = world.time()
  if storage.spawnPosition == nil or config.getParameter("wasRelocated", false) then
    local position = mcontroller.position()
    local groundSpawnPosition
    if mcontroller.baseParameters().gravityEnabled then
      groundSpawnPosition = findGroundPosition(position, -20, 3)
    end
    storage.spawnPosition = groundSpawnPosition or position
  end

  monster.setDamageOnTouch(false)
  
  self.behavior = behavior.behavior(config.getParameter("behavior"), sb.jsonMerge(config.getParameter("behaviorConfig", {}), skillBehaviorConfig()), _ENV)
  self.board = self.behavior:blackboard()
  self.board:setPosition("spawn", storage.spawnPosition)

  self.collisionPoly = mcontroller.collisionPoly()

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end
  if config.getParameter("deathParticles") then
    monster.setDeathParticleBurst(config.getParameter("deathParticles"))
  end

  script.setUpdateDelta(config.getParameter("initialScriptDelta", 5))
  mcontroller.setAutoClearControls(false)
  self.behaviorTickRate = config.getParameter("behaviorUpdateDelta", 2)
  self.behaviorTick = math.random(1, self.behaviorTickRate)

  animator.setGlobalTag("flipX", "")
  self.board:setNumber("facingDirection", mcontroller.facingDirection())

  capturable.init()

  -- Listen to damage taken
  self.damageTaken = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.healthLost > 0 then
        self.damaged = true
        self.board:setEntity("damageSource", notification.sourceEntityId)
      end
    end
  end)

  self.debug = true

  message.setHandler("notify", function(_,_,notification)
      return notify(notification)
    end)
  message.setHandler("despawn", function()
      monster.setDropPool(nil)
      monster.setDeathParticleBurst(nil)
      monster.setDeathSound(nil)
      self.deathBehavior = nil
      self.shouldDie = true
      status.addEphemeralEffect("monsterdespawn")
    end)

  local deathBehavior = config.getParameter("deathBehavior")
  if deathBehavior then
    self.deathBehavior = behavior.behavior(deathBehavior, config.getParameter("behaviorConfig", {}), _ENV, self.behavior:blackboard())
  end

  self.forceRegions = ControlMap:new(config.getParameter("forceRegions", {}))
  self.damageSources = ControlMap:new(config.getParameter("damageSources", {}))
  self.touchDamageEnabled = false

  if config.getParameter("elite", false) then
    status.setPersistentEffects("elite", {"elitemonster"})
  end

  if config.getParameter("damageBar") then
    monster.setDamageBar(config.getParameter("damageBar"));
  end

  monster.setInteractive(config.getParameter("interactive", false))

  monster.setAnimationParameter("chains", config.getParameter("chains"))
  
  message.setHandler("despawn", localHandler(despawn))
  message.setHandler("setParentSize", function(_, _, size) 
	  self.targetSize = size 
	end)
end

function despawn()
  self.despawning = true
  status.setResource("health", 0)
end

function shouldDie()
  return self.despawning or status.resource("health") <= 0
end

function update(dt)
  --Sine wave movement
  if self.isIdle then
    self.hoverTimer = self.hoverTimer + dt

    local hoverCycleProgress = math.sin(self.hoverTimer / self.hoverCycleDuration)
    mcontroller.setYVelocity(mcontroller.yVelocity() + hoverCycleProgress * self.hoverCycleLength)
  end
  
  --Check if we have our parent
  if not self.parentEntity then
    local target = findTarget()
	if target then
      self.parentEntity = target
	  world.sendEntityMessage(self.parentEntity, "applyStatusEffect", "starforge-findentitysize", 1, entity.id())
	end
  end
  
  if self.parentEntity and world.entityExists(self.parentEntity) then
    --Animation and status effects
	local friendly = isHostile(self.parentEntity)
	world.sendEntityMessage(self.parentEntity, "applyStatusEffect", friendly and self.friendlyStatusEffect or self.hostileStatusEffect, 1, entity.id())
	animator.setGlobalTag("hostilityTag", friendly and "friendly" or "hostile")
  
    --Following
    self.orbitTimer = self.orbitTimer + (dt * self.orbitRate)

	animator.resetTransformationGroup("body")
	local orbitRot = math.atan(mcontroller.position()[2] - world.entityPosition(self.parentEntity)[2], mcontroller.position()[1] - world.entityPosition(self.parentEntity)[1]) + (math.pi/2)
	animator.rotateTransformationGroup("body", orbitRot)
	
	local orbitOffset = (self.targetSize or 0) + self.orbitRange
	local targetOffset = vec2.rotate({orbitOffset, 0}, self.orbitTimer)
	local orbitPos = vec2.add(world.entityPosition(self.parentEntity), targetOffset)
	
	local mag = world.magnitude(orbitPos, mcontroller.position())
	local direction = vec2.norm(world.distance(orbitPos, mcontroller.position()))
	local vel = vec2.mul(direction, mag * 1.625)
	
	mcontroller.setVelocity(vec2.add(mcontroller.velocity(), vel), 100)
  elseif self.parentEntity and not world.entityExists(self.parentEntity) then
    self.parentEntity = nil
  end

  capturable.update(dt)
  self.damageTaken:update()

  if status.resourcePositive("stunned") then
    animator.setAnimationState("damage", "stunned")
    animator.setGlobalTag("hurt", "hurt")
    self.stunned = true
    mcontroller.clearControls()
    if self.damaged then
      self.suppressDamageTimer = config.getParameter("stunDamageSuppression", 0.5)
      monster.setDamageOnTouch(false)
    end
    return
  else
    animator.setGlobalTag("hurt", "")
    animator.setAnimationState("damage", "none")
  end

  -- Suppressing touch damage
  if self.suppressDamageTimer then
    monster.setDamageOnTouch(false)
    self.suppressDamageTimer = math.max(self.suppressDamageTimer - dt, 0)
    if self.suppressDamageTimer == 0 then
      self.suppressDamageTimer = nil
    end
  elseif status.statPositive("invulnerable") then
    monster.setDamageOnTouch(false)
  else
    monster.setDamageOnTouch(self.touchDamageEnabled)
  end

  if self.behaviorTick >= self.behaviorTickRate then
    self.behaviorTick = self.behaviorTick - self.behaviorTickRate
    mcontroller.clearControls()

    self.tradingEnabled = false
    self.setFacingDirection = false
    self.moving = false
    self.rotated = false
    self.forceRegions:clear()
    self.damageSources:clear()
    self.damageParts = {}
    clearAnimation()

    if self.behavior then
      local board = self.behavior:blackboard()
      board:setEntity("self", entity.id())
      board:setPosition("self", mcontroller.position())
      board:setNumber("dt", dt * self.behaviorTickRate)
      board:setNumber("facingDirection", self.facingDirection or mcontroller.facingDirection())

      self.behavior:run(dt * self.behaviorTickRate)
    end
    BGroup:updateGroups()

    updateAnimation()

    self.interacted = false
    self.damaged = false
    self.stunned = false
    self.notifications = {}

    setDamageSources()
    setPhysicsForces()
    monster.setDamageParts(self.damageParts)
    overrideCollisionPoly()
  end
  self.behaviorTick = self.behaviorTick + 1
  
  mcontroller.controlFace(1)
end

function isHostile(entityId)
  local isHostile = faklse
  if world.entityDamageTeam(entityId).type == world.entityDamageTeam(entity.id()) then
    isHostile = true
  end
  if world.entityAggressive(entityId) then
    isHostile = true
  end
  if not world.entityCanDamage(entityId, entity.id()) then
    isHostile = true
  end
  return isHostile
end

function findTarget()
  local nearEntities = world.entityQuery(mcontroller.position(), self.scanRange, {
    includedTypes = {"npc", "monster", "player"},
    order = "nearest"
  })
  nearEntities = util.filter(nearEntities, function(entityId)
    if world.lineTileCollision(mcontroller.position(), world.entityPosition(entityId)) then
      return false
    end

    if (world.entityDamageTeam(entityId).type == "passive") and (world.entityTypeName(entityId) ~= "punchy") then
      return false
    end
	
	if world.entityName(entityId) == world.entityName(entity.id()) then
	  return false
	end

    return true
  end)
  local targetId = nearEntities[1]
  if targetId then return targetId else return nil end
end

function skillBehaviorConfig()
  local skills = config.getParameter("skills", {})
  local skillConfig = {}

  for _,skillName in pairs(skills) do
    local skillHostileActions = root.monsterSkillParameter(skillName, "hostileActions")
    if skillHostileActions then
      construct(skillConfig, "hostileActions")
      util.appendLists(skillConfig.hostileActions, skillHostileActions)
    end
  end

  return skillConfig
end

function interact(args)
  self.interacted = true
  self.board:setEntity("interactionSource", args.sourceId)
end

function shouldDie()
  return (self.shouldDie and status.resource("health") <= 0) or capturable.justCaptured
end

function die()
  if not capturable.justCaptured then
    if self.deathBehavior then
      self.deathBehavior:run(script.updateDt())
    end
    capturable.die()
  end
  spawnDrops()
end

function uninit()
  BGroup:uninit()
end

function setDamageSources()
  local partSources = {}
  for part,ds in pairs(config.getParameter("damageParts", {})) do
    local damageArea = animator.partPoly(part, "damageArea")
    if damageArea then
      ds.poly = damageArea
      table.insert(partSources, ds)
    end
  end

  local damageSources = util.mergeLists(partSources, self.damageSources:values())
  damageSources = util.map(damageSources, function(ds)
    ds.damage = ds.damage * root.evalFunction("monsterLevelPowerMultiplier", monster.level()) * status.stat("powerMultiplier")
    if ds.knockback and type(ds.knockback) == "table" then
      ds.knockback[1] = ds.knockback[1] * mcontroller.facingDirection()
    end

    local team = entity.damageTeam()
    ds.team = { type = ds.damageTeamType or team.type, team = ds.damageTeam or team.team }

    return ds
  end)
  monster.setDamageSources(damageSources)
end

function setPhysicsForces()
  local regions = util.map(self.forceRegions:values(), function(region)
    if region.type == "RadialForceRegion" then
      region.center = vec2.add(mcontroller.position(), region.center)
    elseif region.type == "DirectionalForceRegion" then
      if region.rectRegion then
        region.rectRegion = rect.translate(region.rectRegion, mcontroller.position())
        util.debugRect(region.rectRegion, "blue")
      elseif region.polyRegion then
        region.polyRegion = poly.translate(region.polyRegion, mcontroller.position())
      end
    end

    return region
  end)

  monster.setPhysicsForces(regions)
end

function overrideCollisionPoly()
  local collisionParts = config.getParameter("collisionParts", {})

  for _,part in pairs(collisionParts) do
    local collisionPoly = animator.partPoly(part, "collisionPoly")
    if collisionPoly then
      -- Animator flips the polygon by default
      -- to have it unflipped we need to flip it again
      if not config.getParameter("flipPartPoly", true) and mcontroller.facingDirection() < 0 then
        collisionPoly = poly.flip(collisionPoly)
      end
      mcontroller.controlParameters({collisionPoly = collisionPoly, standingPoly = collisionPoly, crouchingPoly = collisionPoly})
      break
    end
  end
end

function setupTenant(...)
  require("/scripts/tenant.lua")
  tenant.setHome(...)
end
