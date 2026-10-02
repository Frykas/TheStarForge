require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  message.setHandler("despawn", despawn)

  self.lightningConfig = config.getParameter("lightningConfig")

  self.allyStatusEffects = config.getParameter("allyStatusEffects", {})
  self.allyProximity = config.getParameter("allyProximity", 15)
  self.requireLineOfSight = config.getParameter("requireLineOfSight", true)

  self.zapInterval = config.getParameter("zapInterval", 0.4)
  self.zapDuration = config.getParameter("zapDuration", 0.1)
  self.maxZappedTargets = config.getParameter("maxZappedTargets", 3)

  self.flashTimer = 0
  self.activeZapTargets = {}
  self.nearbyAllies = {}

  monster.setDeathParticleBurst("deathPoof")
  monster.setDeathSound("deathPuff")

  self.state = FSM:new()
  self.state:set(idleState)
  
  monster.setDamageOnTouch(false)

  script.setUpdateDelta(5)
end

function update(dt)
  self.state:update()

  local myPos = mcontroller.position()
  local myTeam = entity.damageTeam()
  local myType = world.entityTypeName(entity.id())

  local targets = world.entityQuery(myPos, self.allyProximity, {
      includedTypes = {"creature"},
      order = "nearest",
      withoutEntityId = entity.id()
    })
    
  local filteredTargets = {}
  for _, target in ipairs(targets) do
    if world.entityExists(target) 
      and (not self.requireLineOfSight or entity.entityInSight(target)) 
      and (myTeam.type == world.entityDamageTeam(target).type and myTeam.team == world.entityDamageTeam(target).team)
      and world.entityTypeName(target) ~= myType 
      and vec2.mag(vec2.sub(myPos, world.entityPosition(target))) < self.allyProximity then
        
      table.insert(filteredTargets, target)
    end
  end
  
  self.nearbyAllies = filteredTargets
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  monster.setAnimationParameter("lightning", nil)
  status.addEphemeralEffect("monsterdespawn")
end

function die()
  if self.group then
    for _,entityId in pairs(self.group) do
      world.sendEntityMessage(entityId, "despawn")
    end
  end
end

function pickZapTargets()
  if #self.nearbyAllies == 0 then
    self.activeZapTargets = {}
    return
  end

  local pool = copy(self.nearbyAllies)
  local count = math.min(#pool, math.random(1, self.maxZappedTargets))
  self.activeZapTargets = {}

  for i = 1, count do
    local idx = math.random(1, #pool)
    table.insert(self.activeZapTargets, pool[idx])
    table.remove(pool, idx)
  end
end

function updateLightningVisuals()
  if #self.activeZapTargets == 0 or self.flashTimer <= 0 then
    monster.setAnimationParameter("lightning", nil)
    return
  end

  local myPos = entity.position()
  local lightning = {}
  local alpha = math.max(0, math.min(1, self.flashTimer / self.zapDuration))

  for _, ally in ipairs(self.activeZapTargets) do
    if world.entityExists(ally) then
      local targetPos = world.entityPosition(ally)
      local bolt = copy(self.lightningConfig)
      bolt.worldStartPosition = myPos
      bolt.worldEndPosition = targetPos
      bolt.displacement = vec2.mag(vec2.sub(myPos, targetPos)) / 5
      
      if bolt.color then
        local color = copy(bolt.color)
        if #color >= 4 then
          color[4] = math.floor(color[4] * alpha)
        else
          table.insert(color, math.floor(255 * alpha))
        end
        bolt.color = color
      else
        bolt.color = {255, 255, 255, math.floor(255 * alpha)}
      end

      table.insert(lightning, bolt)
    end
  end

  if #lightning > 0 then
    monster.setAnimationParameter("lightning", lightning)
  else
    monster.setAnimationParameter("lightning", nil)
  end
end

-- States

function idleState(targetId)
  if animator.animationState("body") == "active" or animator.animationState("body") == "activate" then
    animator.setAnimationState("body", "deactivate")
  end
  
  self.activeZapTargets = {}
  monster.setAnimationParameter("lightning", nil)

  while #self.nearbyAllies == 0 do
    coroutine.yield()
  end

  self.state:set(activeState)
end

function activeState(targetId)
  if animator.animationState("body") == "idle" or animator.animationState("body") == "deactivate" then
    animator.setAnimationState("body", "activate")
  end
  
  local stunned = false
  if status.isResource("stunned") and status.resource("stunned") ~= 0 then
    stunned = true
  end

  zapTimer = 0
  self.flashTimer = 0

  while #self.nearbyAllies > 0 do
    local dt = script.updateDt()

    if zapTimer > 0 then zapTimer = zapTimer - dt end
    if self.flashTimer > 0 then self.flashTimer = self.flashTimer - dt end

    if not stunned then
      for _, ally in ipairs(self.nearbyAllies) do
        for _, effect in ipairs(self.allyStatusEffects) do
          world.sendEntityMessage(ally, "applyStatusEffect", effect, nil, entity.id())
        end
      end

      if self.lightningConfig and zapTimer <= 0 then
        monster.setAnimationParameter("lightningSeed", math.random(1, 10000))
        pickZapTargets()
        zapTimer = self.zapInterval
        self.flashTimer = self.zapDuration
      end

      updateLightningVisuals()
    else
      monster.setAnimationParameter("lightning", nil)
    end

    coroutine.yield()
  end

  monster.setAnimationParameter("lightning", nil)
  self.state:set(idleState)
end