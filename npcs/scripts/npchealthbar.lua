---
--- Created by Lyrthras#7199.
--- DateTime: 6/26/2021 11:48 AM UTC+08
---
--- Edited by Nebulox#3969
--- DateTime: 9/27/2021 10:11 PM UTC+10
---

local companionMonsterName = "starforge-npchealthbar"

local oldInit = init or function() end
function init()
  if oldInit then oldInit() end

  self.companionId = spawnCompanion()

  self.companionSpawnAttempts = 0
end


local oldUpdate = update or function(dt) end
function update(dt)
  if oldUpdate then oldUpdate(dt) end

  if world.entityTypeName(self.companionId) ~= companionMonsterName then
    self.companionSpawnAttempts = self.companionSpawnAttempts + 1
    self.companionId = spawnCompanion()
    if not self.companionId or self.companionSpawnAttempts > 33 then    -- prevent spam
      error("Repeated failure in spawning companion monster, terminating...")
    end
  end
  
  if config.getParameter("nameTag") then
    npc.setDisplayNametag(config.getParameter("nameTag"))
  end

  world.callScriptedEntity(self.companionId, "status.setResourcePercentage", "health", status.resourcePercentage("health"))
  world.callScriptedEntity(self.companionId, "mcontroller.setPosition", mcontroller.position())
end


function spawnCompanion()
  return world.spawnMonster(companionMonsterName, entity.position(), {
    shortdescription = config.getParameter("bossName", npc.npcType()),
    trackingNpc = entity.id()
  })
end