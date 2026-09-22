require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  message.setHandler("despawn", despawn)

  self.lightningConfig = config.getParameter("lightningConfig")

  self.allyStatusEffects = config.getParameter("allyStatusEffects", {})
  self.allyProximity = config.getParameter("allyProximity", 15)
  self.requireLineOfSight = config.getParameter("requireLineOfSight", true)

  self.nearbyAllies = {}

  monster.setDeathParticleBurst("deathPoof")
  monster.setDeathSound("deathPuff")

  self.state = FSM:new()
  self.state:set(idleState)
  
  monster.setDamageOnTouch(false)
end

function update(dt)
  self.state:update()

  local targets = world.entityQuery(mcontroller.position(), self.allyProximity, {
      includedTypes = {"creature"},
      order = "nearest",
      withoutEntityId = entity.id()
    })
    
  local filteredTargets = {}
  for _, target in ipairs(targets) do
    if world.entityExists(target) 
      and (not self.requireLineOfSight or entity.entityInSight(target)) 
      and (entity.damageTeam().type == world.entityDamageTeam(target).type and entity.damageTeam().team == world.entityDamageTeam(target).team)
      and world.entityTypeName(target) ~= world.entityTypeName(entity.id()) then
        
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

function determineLightning()
  self.bolts = {}
  for i, ally in ipairs(self.nearbyAllies) do
    if world.entityExists(ally) and (not self.requireLineOfSight or entity.entityInSight(ally)) then
      table.insert(self.bolts, {entity.position(), world.entityPosition(ally)})
    end
  end

  lightning = {}
  for i, segment in ipairs(self.bolts) do
    local bolt = copy(self.lightningConfig)
    bolt.worldStartPosition = segment[1]
    bolt.worldEndPosition = segment[2]
    bolt.displacement = vec2.mag(vec2.sub(segment[1], segment[2])) / 5
    table.insert(lightning, bolt)
  end
  
  monster.setAnimationParameter("lightningSeed", math.floor((os.time() + (os.clock() % 1)) * 1000))
  monster.setAnimationParameter("lightning", lightning)
end

-- States

function idleState(targetId)
  if animator.animationState("body") == "active" or animator.animationState("body") == "activate" then
    animator.setAnimationState("body", "deactivate")
  end
  
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
  if status.isResource("stunned") and status.resource("stunned") > 0.5 then
	  stunned = true
  end
  while #self.nearbyAllies > 0 do
    if not stunned then
      for _, ally in ipairs(self.nearbyAllies) do
        for _, effect in ipairs(self.allyStatusEffects) do
          world.sendEntityMessage(ally, "applyStatusEffect", effect, nil, entity.id())
        end
      end
      if self.lightningConfig then
        determineLightning()
      end
    end

    coroutine.yield()
  end
  monster.setAnimationParameter("lightning", nil)

  self.state:set(idleState)
end