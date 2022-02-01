if not partPicker then
  partPicker = {}
  
  --Randomly pick a value from the a list
  function partPicker.getRandomFromList(list, randomSource)
    randomSource:addEntropy()
    local rand = (randomSource:randu32() % #list) + 1
	return list[rand]
  end
  
  --Finds the elemental type from a part list
  function partPicker.getElementalType(partList)
    for _, part in ipairs(partList) do
      if part.type == "body" then
        return part.elementalType
      end
    end
    error("Tried to get elemental type of a part list that does not contain part list without a body")
  end
  
  --Returns true if the part allows the elemental type of the part list
  function partPicker.isElementCompatible(part, currentParts)
    -- Get the element of the current parts
    local currentElement = partPicker.getElementalType(currentParts)
    --Check if the current element is compatible with the elemental types of the picked parts
	if part.elementalTypes then
      for _, element in ipairs(part.elementalTypes) do
        if element == currentElement then
          return true
        end
	  end
	else
	  return true
	end
    return false
  end
  
  --Return a part that is compatible with the current part list
  function partPicker.pickPart(partPool, currentParts, filters, randomSource)
    local part
    local success
    repeat
      success = true
      --Pick a random part from the part pool
      part = partPicker.getRandomFromList(partPool, randomSource)
      --Make sure it's compatible
      for _, filter in ipairs(filters) do
        if not filter(part, currentParts) then
          success = false
          break
        end
      end
    until (success)
    return part
  end
  
  --Used to apply the elemental type to the picked part
  function partPicker.pickBody(partPool, currentParts, filters, randomSource)
    --Pick a part as per usual
    local part = partPicker.pickPart(partPool, currentParts, filters, randomSource)
    --Decide what element it's going to be and save that
    part.elementalType = partPicker.getRandomFromList(part.elementalTypes or {"physical"}, randomSource)
    part.currentManufacturer = part.manufacturer
    --Return the processed part
    return part
  end
  
  --Generate the parts to use for the gun
  function partPicker.generateParts(partPools, partSequence, randomSource)
    randomSource:addEntropy()
    local currentParts = {}
    for _, partType in ipairs(partSequence) do
      --Pass it the current part list so it can pick compatible parts
      local part = partPicker.processors[partType](partPools[partType], currentParts, partPicker.filters[partType], randomSource)
      --Manually name every part in case you need to reference them later on
      part.type = partType
      --Add the picked part to the list of current parts
      table.insert(currentParts, part)
    end
    --Return the picked parts
    return currentParts
  end
end