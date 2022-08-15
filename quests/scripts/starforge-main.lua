--Adds some quest conditions for more fun during a quest

require "/quests/scripts/main.lua"
require('/quests/scripts/conditions/neb-starforgedamageTypeKills.lua')
require('/quests/scripts/conditions/neb-starforgekillmonsterwithweapon.lua')
require('/quests/scripts/conditions/neb-starforgemessagecheck.lua')

function buildConditions()
  local conditions = {}
  local conditionConfig = config.getParameter("conditions", {})

  for _, config in pairs(conditionConfig) do
    local newCondition
    if config.type == "gatherItem" then
      newCondition = buildGatherItemCondition(config)
    elseif config.type == "gatherTag" then
      newCondition = buildGatherTagCondition(config)
    elseif config.type == "shipLevel" then
      newCondition = buildShipLevelCondition(config)
    elseif config.type == "scanObjects" then
      newCondition = buildScanObjectsCondition(config)
    elseif config.type == "killMonsters" then
      newCondition = buildMonsterKillCondition(config)
    elseif config.type == "completeCollection" then
      newCondition = buildCompleteCollectionCondition(config)
	
	--Starforge conditions
    elseif config.type == "damageTypeKills" then
      newCondition = buildDamageTypeKillCondition(config)
    elseif config.type == "killMonstersWithWeapon" then
      newCondition = buildKillMonsterWithWeapon(config)
    elseif config.type == "checkForMessage" then
      newCondition = buildMessageCheckCondition(config)
    end

    table.insert(conditions, newCondition)
  end

  return conditions
end