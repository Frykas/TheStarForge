require "/scripts/util.lua"

function build(directory, config, parameters, level, seed)
  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
      return parameters[keyName]
    elseif config[keyName] ~= nil then
      return config[keyName]
    else
      return defaultValue
    end
  end

  if level and not configParameter("fixedLevel", true) then
    parameters.level = level
  end

  -- set price
  config.price = configParameter("price", 0) * root.evalFunction("itemLevelPriceMultiplier", configParameter("level", 1))

  -- tooltip fields
  if config.tooltipKind ~= "base" then
    config.tooltipFields = {}
    config.tooltipFields.levelLabel = util.round(configParameter("level", 1), 1)
    config.tooltipFields.rarityLabel = configParameter("rarity", "Common")
    
    config.tooltipFields.healthLabel = util.round(configParameter("baseShieldHealth", 0) * root.evalFunction("shieldLevelMultiplier", configParameter("level", 1)), 0)
    config.tooltipFields.cooldownLabel = parameters.cooldownTime or config.cooldownTime
    
    --Apply manufacturer icon
    if config.manufacturer and config.manufacturer ~= "" then
      config.tooltipFields.manufacturerIconImage = "/interface/sf-manufacturers/" .. config.manufacturer:lower() .. ".png"
    end
    
    if (config.rarity == "Essential" or config.rarity == "essential") and (config.tooltipKind == "starforge-uniquesword" or config.tooltipKind == "starforge-uniquegun") then
      config.tooltipKind = config.tooltipKind .. "-shiny"
    end
    
    -- Lets you customise tooltip from the weapon... EXTREMELY useful I think!
    config.tooltipFields = sb.jsonMerge(config.tooltipFields, config.tooltipFieldsOverride or {})
  end

  return config, parameters
end
