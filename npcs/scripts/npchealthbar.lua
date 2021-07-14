---
--- Created by Lyrthras#7199.
--- DateTime: 6/26/2021 11:48 AM UTC+08
---

local companionMonsterName = "starforge-npchealthbar"


local oInit = init or function() end
function init()
  oInit()

  self.companionId = spawnCompanion()

  self.companionSpawnAttempts = 0
end


local oUpdate = update or function(dt) end
function update(dt)
  oUpdate(dt)

  if world.entityTypeName(self.companionId) ~= companionMonsterName then
    self.companionSpawnAttempts = self.companionSpawnAttempts + 1
    self.companionId = spawnCompanion()
    if not self.companionId or self.companionSpawnAttempts > 30 then    -- prevent spam
      error("Failing to spawn companion monster, dying...")
    end
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