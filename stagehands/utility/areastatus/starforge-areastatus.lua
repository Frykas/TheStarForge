require "/scripts/stagehandutil.lua"

function init()
  self.entityWhitelist = config.getParameter("entityWhitelist", {"npc", "monster", "player"})
  self.statusEffects = config.getParameter("statusEffects", {})
end

function update(dt)
  --Find all entites in stagehand and apply an effect
  local whitelistedEntities = broadcastAreaQuery({
    includedTypes = self.entityWhitelist
  })
  for _, entity in pairs(whitelistedEntities) do
    for _, effect in pairs(self.statusEffects) do
	  world.sendEntityMessage(entity, "applyStatusEffect", effect)
    end
  end
end
