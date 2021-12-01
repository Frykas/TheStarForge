function build(directory, config, parameters, level, seed, ...)
  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
	  return parameters[keyName]
   elseif config[keyName] ~= nil then
	  return config[keyName]
    else
	  return defaultValue
    end
  end

  if type(config.inventoryIcon) == "string" then
    config.inventoryIcon = config.inventoryIcon
  end
  local invIcon = config.inventoryIcon 
  --SCALE IT ACCORDING TO THE SIZE OF THE ICON
  local itemBorder = configParameter("itemBackground", "/interface/inventory/starforge-exalted.png")
  if itemBorder then
    config.itemBorder = itemBorder
    local itemBorderSize = root.imageSize(config.itemBorder)
    local iconSize = root.imageSize(invIcon)
    iconSize[1] = iconSize[1] / 4
    local difference = iconSize[2]
    if iconSize[1] > iconSize[2] then
	  difference = iconSize[1]
    end
    --FIND HIGHEST VALUE X OR Y THEN FIND DIFFERENCE
    local scaleAmount = difference / itemBorderSize[1]
    config.itemBorder = config.itemBorder .. "?scalenearest=" .. scaleAmount
    config.inventoryIcon = {
  	  { image = config.itemBorder },
	  { image = config.inventoryIcon }
    }
  end
  
  for i, drawable in ipairs(config.inventoryIcon) do
    if drawable.image then drawable.image = drawable.image end
  end

  return config, parameters;
end
