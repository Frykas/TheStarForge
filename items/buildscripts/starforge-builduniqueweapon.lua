require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/items/buildscripts/abilities.lua"

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

  setupAbility(config, parameters, "primary")
  setupAbility(config, parameters, "alt")

  -- elemental type and config (for alt ability)
  local elementalType = configParameter("elementalType", "physical")
  replacePatternInData(config, nil, "<elementalType>", elementalType)
  if config.altAbility and config.altAbility.elementalConfig then
    util.mergeTable(config.altAbility, config.altAbility.elementalConfig[elementalType])
  end

  -- load and merge combo finisher
  local comboFinisherSource = configParameter("comboFinisherSource")
  if comboFinisherSource then
    local comboFinisherConfig = root.assetJson(comboFinisherSource)
    util.mergeTable(config, comboFinisherConfig)
  end
  
  -- calculate damage level multiplier
  config.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", configParameter("level", 1))

  -- palette swaps
  config.paletteSwaps = ""
  if config.palette then
    local palette = root.assetJson(util.absolutePath(directory, config.palette))
    local selectedSwaps = palette.swaps[configParameter("colorIndex", 1)]
    for k, v in pairs(selectedSwaps) do
      config.paletteSwaps = string.format("%s?replace=%s=%s", config.paletteSwaps, k, v)
    end
  end
  if type(config.inventoryIcon) == "string" then
    config.inventoryIcon = config.inventoryIcon .. config.paletteSwaps
  else
    for i, drawable in ipairs(config.inventoryIcon) do
      if drawable.image then drawable.image = drawable.image .. config.paletteSwaps end
    end
  end

  -- gun offsets
  if config.baseOffset then
    construct(config, "animationCustom", "animatedParts", "parts", "middle", "properties")
    config.animationCustom.animatedParts.parts.middle.properties.offset = config.baseOffset
    if config.muzzleOffset then
      config.muzzleOffset = vec2.add(config.muzzleOffset, config.baseOffset)
    end
  end

  -- populate tooltip fields
  if config.tooltipKind ~= "base" then
    config.tooltipFields = {}
    config.tooltipFields.levelLabel = util.round(configParameter("level", 1), 1)
    config.tooltipFields.rarityLabel = configParameter("rarity", "Common")

    --Bows
    if config.primaryAbility.drawTime then
      config.tooltipFields.speedTitleLabel = "Draw Time:"
      config.tooltipFields.speedLabel = util.round(config.primaryAbility.drawTime - (config.altAbility and config.altAbility.drawTimeReduction or 0) or 0, 1)
      
      config.tooltipFields.damagePerShotTitleLabel = "Base Damage:"
      config.tooltipFields.damagePerShotLabel = util.round(config.primaryAbility.projectileParameters.power * config.primaryAbility.dynamicDamageMultiplier * config.damageLevelMultiplier, 1) or 0
      config.tooltipFields.energyPerShotLabel = config.primaryAbility.energyPerShot or 0

    --Other
    else
      --Beam weapons
      if config.primaryAbility.chain then
        config.tooltipFields.energyPerShotTitleLabel = "Energy Per Second:"
        config.tooltipFields.energyPerShotLabel = util.round((config.primaryAbility.energyUsage or 0), 1)

        config.tooltipFields.damagePerShotTitleLabel = "Damge Per Second:"
        config.tooltipFields.damagePerShotLabel = util.round((config.primaryAbility.baseDps or 0) * config.damageLevelMultiplier, 1)

        config.tooltipFields.speedTitleLabel = "Ticks Per Second:"
      else
        config.tooltipFields.damagePerShotLabel = util.round((config.primaryAbility.baseDamage or ((config.primaryAbility.baseDps or 0) * (config.primaryAbility.fireTime or 1.0))) * config.damageLevelMultiplier, 1)
        if config.primaryAbility.projectileCount and config.primaryAbility.projectileCount > 1 then
          config.tooltipFields.damagePerShotLabel = util.round((config.tooltipFields.damagePerShotLabel / config.primaryAbility.projectileCount), 1) .. "^gray;x" .. config.primaryAbility.projectileCount
        end
        config.tooltipFields.energyPerShotLabel = util.round((config.primaryAbility.energyUsage or 0) * (config.primaryAbility.fireTime or 1.0), 1)
        config.tooltipFields.dpsLabel = util.round((config.primaryAbility.baseDps or 0) * config.damageLevelMultiplier, 1)
      end

      if config.primaryAbility.tooltipDamageMultiplier then
        config.tooltipFields.damagePerShotLabel = config.tooltipFields.damagePerShotLabel * config.primaryAbility.tooltipDamageMultiplier
      end

      --Fire Rate things
      --Charge weapons
      if config.primaryAbility.chargeTime then
        config.tooltipFields.speedTitleLabel = "Charge Time:"
        config.tooltipFields.speedLabel = util.round(config.primaryAbility.chargeTime or 1, 1)
      else
        local cycleTime = (config.primaryAbility.fireTime or config.primaryAbility.cooldownTime or 1.0) + (config.primaryAbility.fireType == "burst" and (config.primaryAbility.burstTime * config.primaryAbility.burstCount) or 0)
        local rateOfFire = (config.primaryAbility.burstCount or 1) / (cycleTime * (config.primaryAbility.stanceSpeedFactor or 1))
        config.tooltipFields.speedLabel = util.round(rateOfFire, 1)
      end
    end
    --Diff energy types
    if config.primaryAbility.resourcetype == "health" then
      config.tooltipFields.energyPerShotTitleLabel = "Health Per Shot:"
    end
    
    if elementalType ~= "physical" then
      config.tooltipFields.damageKindImage = "/interface/elements/" .. elementalType .. ".png"
    end
    if config.primaryAbility then
      config.tooltipFields.primaryAbilityTitleLabel = "Primary:"
      config.tooltipFields.primaryAbilityLabel = config.primaryAbility.name or "Unspecified"
    end
    if config.comboFinisher then
      config.tooltipFields.altAbilityTitleLabel = "Finisher:"
      config.tooltipFields.altAbilityLabel = config.comboFinisher.name or "Unspecified"
    elseif config.altAbility then
      if config.primaryAbility.finisherHoldTime and not config.twoHanded then
        config.tooltipFields.altAbilityTitleLabel = "Finisher:"
      else
        config.tooltipFields.altAbilityTitleLabel = "Special:"
      end
      config.tooltipFields.altAbilityLabel = config.altAbility.name or "Unspecified"
    end

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

  -- set price
  -- TODO: should this be handled elsewhere?
  config.price = (config.price or 0) * root.evalFunction("itemLevelPriceMultiplier", configParameter("level", 1))

  return config, parameters
end
