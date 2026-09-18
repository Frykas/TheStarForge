require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  message.setHandler("despawn", despawn)

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
    if world.entityExists(target) and (not self.requireLineOfSight or entity.entityInSight(target)) and entity.damageTeam().type == world.entityDamageTeam(target).type and entity.damageTeam().team == world.entityDamageTeam(target).team then
      table.insert(filteredTargets, target)
    end
  end
  
  self.nearbyAllies = filteredTargets
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  monster.setAnimationParameter("targetId", nil)
  status.addEphemeralEffect("monsterdespawn")
end

function die()
  if self.group then
    for _,entityId in pairs(self.group) do
      world.sendEntityMessage(entityId, "despawn")
    end
  end
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
  
  while #self.nearbyAllies > 0 do
    for _, ally in ipairs(self.nearbyAllies) do
      for _, effect in ipairs(self.allyStatusEffects) do
        world.sendEntityMessage(ally, "applyStatusEffect", effect, nil, entity.id())
      end
    end
    
    coroutine.yield()
  end

  self.state:set(idleState)
end