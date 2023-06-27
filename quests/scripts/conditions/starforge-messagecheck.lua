function buildStarforgeMessageCheckCondition(config)
  --Set up the damageType kill condition
  local starforgeMessageCheckCondition = {
    description = config.description or root.assetJson("/quests/quests.config:objectiveDescriptions.nebStarforgeMessageCheck")
  }
  
  --Set up the function for checking if the conditions were met
  function starforgeMessageCheckCondition:conditionMet()
    return storage.nebStarforgeMessageReceived == true
  end
  
  --Set up the function that will get called when we receive our target message
  function starforgeMessageCheckCondition:onMessageReceived(message, isLocal, objectName)
    storage.nebStarforgeMessageReceived = true
  end

  --Set up the function for performing actions upon quest complete
  --These get called in addition to the default quest complete actions, and so should only contain actions relative to the objective
  function starforgeMessageCheckCondition:onQuestComplete()
    --Nothing here!
  end

  --Set up the function for constructing the objective text
  function starforgeMessageCheckCondition:objectiveText()
    local objective = self.description
    return objective
  end

  --Remember if we have received a message
  storage.nebStarforgeMessageReceived = storage.nebStarforgeMessageReceived or 0
  
  --Set up a listener function that listens for the specified target message
  message.setHandler(config.targetMessage, function(...) starforgeMessageCheckCondition:onMessageReceived(...) end)
  
  return starforgeMessageCheckCondition
end
