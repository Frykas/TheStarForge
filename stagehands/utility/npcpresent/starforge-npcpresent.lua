require "/scripts/stagehandutil.lua"
require "/scripts/starforge-util.lua"

function init()
  self.entityWhitelist = config.getParameter("entityWhitelist", {"npc"})
  self.targetEntityName = config.getParameter("targetEntityName", "Esther")
  self.playerSearchRadius = config.getParameter("playerSearchRadius", 100)
  self.lastFoundEntities = {}
end

function update(dt)
  local foundEntities = broadcastAreaQuery({
    includedTypes = self.entityWhitelist
  })
  
  if not nebUtil.tablesAreSame(foundEntities, self.lastFoundEntities) then
    local nearbyPlayers = world.playerQuery(stagehand.position(), self.playerSearchRadius)
    if containsName(foundEntities, self.targetEntityName) then
	  callPlayers(nearbyPlayers, "starforge-entityEntered")
	else
	  callPlayers(nearbyPlayers, "starforge-entityExited")
	end
  end
  
  self.lastFoundEntities = foundEntities
end

function callPlayers(players, message)
  for _, player in ipairs(players) do
    world.sendEntityMessage(player, message)
  end
end

function containsName(table, key)
  for _, v in ipairs(table) do
    if world.entityName(v) == key then
      return true
    end
  end
  return false
end