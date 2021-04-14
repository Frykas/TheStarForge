function buildKillMonsterWithWeapon(config)
  --Set up the monster kill condition
  local killMonsterWithWeapon = {
    description = config.description or root.assetJson("/quests/quests.config:objectiveDescriptions.nebStarforgeKillMonsterWithWeapon"),
    monsterName = config.displayMonsterName,
    targetMonster = config.targetMonster,
    itemName = config.itemName,
	displayedItemName = config.displayedItemName,
    count = config.count or 1
  }
  
  --Set up the function for checking if the conditions were met
  function killMonsterWithWeapon:conditionMet()
    return storage.nebKillMonsterWithWeaponCount >= self.count
  end

  --Set up the function for performing actions upon quest complete
  --These get called in addition to the default quest complete actions, and so should only contain actions relative to the objective
  function killMonsterWithWeapon:onQuestComplete()
    --Nothing here!
  end

  --Set up the function for constructing the objective text
  function killMonsterWithWeapon:objectiveText()
    local objective = self.description
    objective = objective:gsub("<monsterName>", self.monsterName and (" " .. self.monsterName) or "")
    objective = objective:gsub("<required>", self.count)
    objective = objective:gsub("<current>", storage.nebKillMonsterWithWeaponCount or 0)
    objective = objective:gsub("<itemName>", self.monsterName and (self.displayedItemName and " with " .. self.displayedItemName or "") or (self.displayedItemName and "s with " .. self.displayedItemName or ""))
	return objective
  end
  
  function killMonsterWithWeapon:onUpdate()
    --Check for inflicted hits and add a to the count on kill
    local damageNotifications, nextStep = status.inflictedDamageSince(self.queryDamageSince or 0)
    self.queryDamageSince = nextStep
  
    for _, notification in ipairs(damageNotifications) do
	  if notification.targetEntityId then
	    if notification.hitType == "Kill" and world.entityCanDamage(notification.targetEntityId, player.id()) then
		  if ((world.entityTypeName(notification.targetEntityId) == self.targetMonster) or (not self.targetMonster)) and notification.targetEntityId ~= self.lastEntity then
		    --sb.logInfo("%s", player.primaryHandItem().name)
			local primaryHeldItem = player.primaryHandItem() or {}
			local altHeldItem = player.altHandItem() or {}
		    if ((primaryHeldItem.name == self.itemName) or (altHeldItem.name == self.itemName) or (not self.itemName)) then
		      storage.nebKillMonsterWithWeaponCount = storage.nebKillMonsterWithWeaponCount + 1
			  
			  self.lastEntity = notification.targetEntityId 
		    end 
	      end
		end
	  end
    end
  end

  --Remember how many messages we have already received
  storage.nebKillMonsterWithWeaponCount = storage.nebKillMonsterWithWeaponCount or 0
  
  return killMonsterWithWeapon
end
