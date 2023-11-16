require "/scripts/starforge-util.lua"

function buildStarforgeKillEnemies(config)
  --Set up the monster kill condition
  local starforgeKillEnemies = {
    description = config.description or root.assetJson("/quests/quests.config:objectiveDescriptions.nebStarforgeKillEnemies"),
    
    targetMonsters = config.targetMonsters or {},
    monsterName = config.displayMonsterName,
    
    damageTypes = config.damageTypes or {},
    damageTypeName = config.displayDamageTypeName,
    
    itemNames = config.itemNames or {},
    displayedItemName = config.displayedItemName,
    
    count = config.count or 1
  }
  
  --Set up the function for checking if the conditions were met
  function starforgeKillEnemies:conditionMet()
    return storage.starforgeKillCount >= self.count
  end

  --Set up the function for performing actions upon quest complete
  --These get called in addition to the default quest complete actions, and so should only contain actions relative to the objective
  function starforgeKillEnemies:onQuestComplete()
    --Nothing here!
  end

  --Set up the function for constructing the objective text
  function starforgeKillEnemies:objectiveText()
    local objective = self.description
    objective = objective:gsub("<current>", storage.starforgeKillCount or 0)
    objective = objective:gsub("<required>", self.count)
    
    local monsterTag = self.monsterName and (" " .. self.monsterName) or ""
    monsterTag = self.monsterName and monsterTag or (storage.starforgeKillCount == 1 and " enemy" or " enemies")
    
    local damageTypeTag = self.damageTypeName and (" with" .. self.damageTypeName) or ""
    
    local itemTag = self.displayDamageTypeName and (self.damageTypeName and " from " or "") or ""
    itemTag = itemTag .. (self.displayDamageTypeName or "")
    
    objective = objective:gsub("<monsterName>", monsterTag)
    objective = objective:gsub("<damageType>", damageTypeTag)
    objective = objective:gsub("<itemName>", itemTag)
    
    return objective
  end
  
  function starforgeKillEnemies:onUpdate()
    --Check for inflicted hits and add a to the count on kill
    local damageNotifications, nextStep = status.inflictedDamageSince(self.queryDamageSince or 0)
    self.queryDamageSince = nextStep
  
    for _, notification in ipairs(damageNotifications) do
      if notification.targetEntityId then
        --If kill
        if notification.hitType == "Kill" and world.entityCanDamage(notification.targetEntityId, player.id()) then
          --Check if the monster is valid
          local monsterValid = (#self.targetMonsters == 0) and true or 
            nebUtil.tableContains(self.targetMonsters, world.entityTypeName(notification.targetEntityId))
          
          --Check if damage is valid
          local damageValid = (#self.damageTypes == 0) and true or 
            nebUtil.tableContains(self.damageTypes, notification.damageSourceKind)
          
          --Check if item is valid
          local primaryHeldItem = player.primaryHandItem() or {}
          local altHeldItem = player.altHandItem() or {}
          local itemValid = (#self.itemNames == 0) and true or 
            nebUtil.tableContains(self.itemNames, primaryHeldItem) or
            nebUtil.tableContains(self.itemNames, altHeldItem)
          
          --Ensure its not the same enemy
          if notification.targetEntityId ~= self.lastEntityId and monsterValid and damageValid and itemValid then
            storage.starforgeKillCount = storage.starforgeKillCount + 1
            
            self.lastEntityId = notification.targetEntityId 
          end
        end
      end
    end
  end

  --Remember how many kills we already have
  storage.starforgeKillCount = storage.starforgeKillCount or 0
  
  return starforgeKillEnemies
end
