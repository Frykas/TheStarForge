if not nebArmourFunctions then
  nebArmourFunctions = {}

  function nebArmourFunctions.adaptColour()
    if armourName ~= nil then
	  local itemConfig = root.itemConfig(armourName).config
	  if itemConfig.applyFunction == "replace" then
	    newParams = armourName.parameters
	    newParams.playerPortrait = world.entityPortrait(entity.id(), "full")
	    player.setEquippedItem(armourType, {count = 1, name = armourName.name, parameters = newParams })
	  end
    end
  end
end