require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/scripts/staticrandom.lua"
require "/items/buildscripts/abilities.lua"

require "/scripts/starforge-util.lua"
require "/scripts/cobra-partpicker.lua"

--Made by Nebulox
--Thanks to C0bra5 for helping me with the development of a more streamlined generation system!
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
  
  --Initialise randomisation
  local randomSource
  if seed or parameters.seed then
    randomSource = sb.makeRandomSource(seed or parameters.seed)
    if not seed then
      seed = parameters.seed
    end
    if not parameters.seed then
      parameters.seed = seed
    end
  else
    randomSource = sb.makeRandomSource()
    seed = randomSource:randu32()
    parameters.seed = seed
    randomSource:init(seed)
  end

  --Determine generation profile
  local builderConfig = {}
  if config.builderConfig then
    builderConfig = partPicker.getRandomFromList(config.builderConfig, randomSource)
  end
  
  --Generate a list of parts for the weapon
  local generationConfig = root.assetJson(util.absolutePath(directory, builderConfig.buildConfig))
  
  local parts = generationConfig.partPools
  local partSequence = generationConfig.partSequence
  local generationDirectory = generationConfig.basePartDirectory
 
  partPicker.filters = {
    body = {},
    stock = {partPicker.isElementCompatible},
    magazine = {partPicker.isElementCompatible},
    barrel = {partPicker.isElementCompatible},
    attachment = {partPicker.isElementCompatible}
  }
  --Define what function is used to generate the part from the part pool, use those for apply stats when a stat can be in a range
  partPicker.processors = {
    body = partPicker.pickBody,
    stock = partPicker.pickPart,
    magazine = partPicker.pickPart,
    barrel = partPicker.pickPart,
    attachment = partPicker.pickPart
  }
  
  local weaponParts = parameters.weaponParts or partPicker.generateParts(parts, partSequence, randomSource)
  parameters.weaponParts = weaponParts
  
  --Apply stats and features of each part to the weapon
  --Ensure lack of name works
  local namePrefix = ""
  local nameRoot = ""
  local nameSuffix = ""
  
  --Setup rarity calculation
  local rarityFactor = 0
  
  local primaryAbilityData = {}
  local primaryAbilityMultipliers = {}
  
  local attachmentOffset = {0, 0}
  for x, part in ipairs(weaponParts) do
	local partName = partSequence[x]
	
	--If applicable, apply the stats
	if part.baseStats then
	  --Merge the stats we already have with the new stats from the part
	  primaryAbilityData = util.mergeTable(primaryAbilityData, part.baseStats)
	end
	
	--If applicable, apply the multipliers
	if part.multipliers then
	  for x, y in pairs(part.multipliers) do
		--Check if we already have the multiplier, if so multiply them together
		if primaryAbilityMultipliers[x] then
		  primaryAbilityMultipliers[x] = primaryAbilityMultipliers[x] * y
		--Otherwise just add the multiplier for the stat
		else
		  primaryAbilityMultipliers[x] = y
		end
	  end
	end
	
	--Apply and merge any animationCustoms the part might have
	if part.animationCustom then
	  config.animationCustom = util.mergeTable(config.animationCustom or {}, part.animationCustom)
	end
	
	--Update the rarity factor
	rarityFactor = rarityFactor + (part.rarity or 0)
	
	--Specify the prefix, root and suffix of the weapon name
	if not parameters.name then
	  if part.namePrefix then
	    namePrefix = partPicker.getRandomFromList(part.namePrefix, randomSource)
	  end
	  if part.nameRoot then
	    nameRoot = partPicker.getRandomFromList(part.nameRoot, randomSource)
	  end
	  if part.nameSuffix then
	    nameSuffix = partPicker.getRandomFromList(part.nameSuffix, randomSource)
	  end
	end
	
	--Determine sprite to use for each part
	local chosenSprite = partPicker.getRandomFromList(part.images, randomSource)
	config.animationParts[partName] = util.absolutePath(string.gsub(generationDirectory, "<partName>", partName), chosenSprite)
	--Find the same position in the array and use it to find the fullbright to use
	local spriteIndex = nebUtil.findIndex(part.images, chosenSprite)
	if spriteIndex and part.fullbrightImages then
  	  config.animationParts[partName .. "Fullbright"] = util.absolutePath(string.gsub(generationDirectory, "<partName>", partName), part.fullbrightImages[spriteIndex])
	end
	
	--While this should only apply to body, specify the manufacturer based on the parts manufacturer
	if part.currentManufacturer then
	  parameters.manufacturer = part.currentManufacturer
	end
	
	--While this should only apply to body, specify the elementalType based on the parts elementalType
	if part.elementalType then
	  parameters.elementalType = part.elementalType
	end
	
	--If specified, keep adding this
	if part.muzzleOffset then
	  parameters.muzzleOffset = vec2.add((config.muzzleOffset or {0, 0}), part.muzzleOffset)
    end
	
	if part.attachmentOffset then
	  attachmentOffset = vec2.add(attachmentOffset, part.attachmentOffset)
	end
	
	if part.altAbility then
	  builderConfig.altAbilities = {part.altAbility}
	  config.altAbility = part.altAbilityConfig
	  
	  if config.altAbility.fireOffset then
	    config.altAbility.fireOffset = vec2.add(config.altAbility.fireOffset, attachmentOffset)
	  end
    end
  end
  parameters.attachmentOffset = attachmentOffset
  
  local elementalType = parameters.elementalType

  --Apply the level if fixedLevel is false
  if level and not configParameter("fixedLevel", false) then
    parameters.level = level
  end
  
  --Determine the rarity based on rarity sum of all parts
  config.rarity = determineRarity(generationConfig.indexToRarity, rarityFactor, #partSequence)
  
  --Apply the name
  if not parameters.name then
    local name = (namePrefix .. nameRoot .. nameSuffix)
    parameters.name = name
  end
  parameters.shortdescription = parameters.name
	
  --Apply directives
  if not parameters.generatedDirectives then
    local elementalDirectives = generationConfig.elementalDirectives[parameters.elementalType]
    local manufacturerDirectives = generationConfig.manufacturerConfigs[parameters.manufacturer].rarityDirectives[config.rarity:lower()]
    local randomisedDirectives = partPicker.getRandomFromList(generationConfig.randomisedDirectives, randomSource)
    parameters.generatedDirectives = elementalDirectives .. manufacturerDirectives .. randomisedDirectives
  end
  
  --Select, load and merge abilities
  setupAbility(config, parameters, "primary", builderConfig, seed)
  setupAbility(config, parameters, "alt", builderConfig, seed)
  
  --Apply elemental configs
  if builderConfig.elementalConfig then
    util.mergeTable(config, builderConfig.elementalConfig[elementalType])
  end
  if config.altAbility and config.altAbility.elementalConfig then
    util.mergeTable(config.altAbility, config.altAbility.elementalConfig[elementalType])
  end

  --Update primary ability
  config.primaryAbility = util.mergeTable(config.primaryAbility, primaryAbilityData)
  
  --Preprocess shared primary attack config
  parameters.primaryAbility = parameters.primaryAbility or {}
  parameters.primaryAbility.fireTimeFactor = valueOrRandom(parameters.primaryAbility.fireTimeFactor, seed, "fireTimeFactor")
  parameters.primaryAbility.baseDpsFactor = valueOrRandom(parameters.primaryAbility.baseDpsFactor, seed, "baseDpsFactor")
  parameters.primaryAbility.energyUsageFactor = valueOrRandom(parameters.primaryAbility.energyUsageFactor, seed, "energyUsageFactor")

  config.primaryAbility.fireTime = scaleConfig(parameters.primaryAbility.fireTimeFactor, config.primaryAbility.fireTime)
  config.primaryAbility.baseDps = scaleConfig(parameters.primaryAbility.baseDpsFactor, config.primaryAbility.baseDps)
  config.primaryAbility.energyUsage = scaleConfig(parameters.primaryAbility.energyUsageFactor, config.primaryAbility.energyUsage) or 0

  --Preprocess melee primary attack config
  if config.primaryAbility.damageConfig and config.primaryAbility.damageConfig.knockbackRange then
    config.primaryAbility.damageConfig.knockback = scaleConfig(parameters.primaryAbility.fireTimeFactor, config.primaryAbility.damageConfig.knockbackRange)
  end

  --Preprocess ranged primary attack config
  if config.primaryAbility.projectileParameters then
    --config.primaryAbility.projectileType = "unbound" .. elementalType .. "bullet"
    if config.primaryAbility.projectileParameters.knockbackRange then
      config.primaryAbility.projectileParameters.knockback = scaleConfig(parameters.primaryAbility.fireTimeFactor, config.primaryAbility.projectileParameters.knockbackRange)
    end
  end
  
  config.primaryAbility = correctAbility(config, primaryAbilityMultipliers)
  config.primaryAbility.projectileCount = math.max(1, config.primaryAbility.projectileCount)

  --Calculate damage level multiplier
  config.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", configParameter("level", 1))

  --Build palette swap directives
  config.paletteSwaps = ""
  if builderConfig.palette then
    local palette = root.assetJson(util.absolutePath(directory, builderConfig.palette))
    local selectedSwaps = randomFromList(palette.swaps, seed, "paletteSwaps")
    for k, v in pairs(selectedSwaps) do
      config.paletteSwaps = string.format("%s?replace=%s=%s", config.paletteSwaps, k, v)
    end
  end

  --Merge extra animationCustom
  if builderConfig.animationCustom then
    util.mergeTable(config.animationCustom or {}, builderConfig.animationCustom)
  end

  --Animation parts
  if builderConfig.animationParts then
    config.animationParts = config.animationParts or {}
    if parameters.animationPartVariants == nil then parameters.animationPartVariants = {} end
    for k, v in pairs(builderConfig.animationParts) do
      if type(v) == "table" then
        if v.variants and (not parameters.animationPartVariants[k] or parameters.animationPartVariants[k] > v.variants) then
          parameters.animationPartVariants[k] = randomIntInRange({1, v.variants}, seed, "animationPart"..k)
        end
        config.animationParts[k] = util.absolutePath(directory, string.gsub(v.path, "<variant>", parameters.animationPartVariants[k] or ""))
        if v.paletteSwap then
          config.animationParts[k] = config.animationParts[k] .. config.paletteSwaps
        end
      else
        config.animationParts[k] = v
      end
    end
  end
  
  config.paletteSwaps = config.paletteSwaps .. parameters.generatedDirectives

  --Offset combat rifle parts
  local partImagePositions = {}
  if builderConfig.gunParts then
    construct(config, "animationCustom", "animatedParts", "parts")
    local imageOffset = {0,0}
    local gunPartOffset = {0,0}
    for _,part in ipairs(builderConfig.gunParts) do
      local imageSize = root.imageSize(config.animationParts[part])
      construct(config.animationCustom.animatedParts.parts, part, "properties")

      imageOffset = vec2.add(imageOffset, {imageSize[1] / 2, 0})
      config.animationCustom.animatedParts.parts[part].properties.offset = {config.baseOffset[1] + imageOffset[1] / 8, config.baseOffset[2]}
      partImagePositions[part] = copy(imageOffset)
      imageOffset = vec2.add(imageOffset, {imageSize[1] / 2, 0})
    end
    config.muzzleOffset = vec2.add(config.baseOffset, vec2.add(config.muzzleOffset or {0,0}, vec2.div(imageOffset, 8)))
  end

  --Randomise fire sounds
  if config.fireSounds then
    construct(config, "animationCustom", "sounds", "fire")
    local sound = randomFromList(config.fireSounds, seed, "fireSound")
    config.animationCustom.sounds.fire = type(sound) == "table" and sound or { sound }
  end

  --Build the inventory icon
  if not config.inventoryIcon and config.animationParts then
    config.inventoryIcon = jarray()
    local parts = builderConfig.partLayerOrder or {}
    for _, partName in pairs(parts) do
      local drawable = {
        image = config.animationParts[partName] .. config.paletteSwaps,
        position = partImagePositions[partName]
      }
      table.insert(config.inventoryIcon, drawable)
    end
  end

  --Populate tooltip fields
  if config.tooltipKind ~= "base" then
    config.tooltipFields = {}
    local fireTime = parameters.primaryAbility.fireTime or config.primaryAbility.fireTime or 1.0
    local baseDps = parameters.primaryAbility.baseDps or config.primaryAbility.baseDps or 0
    local energyUsage = parameters.primaryAbility.energyUsage or config.primaryAbility.energyUsage or 0
	
    config.tooltipFields.levelLabel = util.round(configParameter("level", 1), 1)
    config.tooltipFields.dpsLabel = util.round(baseDps * config.damageLevelMultiplier, 1)
    config.tooltipFields.speedLabel = util.round(1 / fireTime, 1)
    config.tooltipFields.damagePerShotLabel = util.round(baseDps * fireTime * config.damageLevelMultiplier, 1)
    config.tooltipFields.energyPerShotLabel = util.round(energyUsage * fireTime, 1)
    config.tooltipFields = sb.jsonMerge(config.tooltipFields, config.tooltipFieldsOverride or {})
	
    if elementalType ~= "physical" then
      config.tooltipFields.damageKindImage = "/interface/elements/" .. elementalType .. ".png"
    end
    if config.primaryAbility then
      config.tooltipFields.primaryAbilityTitleLabel = "Primary:"
      config.tooltipFields.primaryAbilityLabel = config.primaryAbility.name or "unknown"
    end
    if config.altAbility then
      config.tooltipFields.altAbilityTitleLabel = "Special:"
      config.tooltipFields.altAbilityLabel = config.altAbility.name or "unknown"
    end
	
    --Apply manufacturer icon
    config.tooltipFields.manufacturerIconImage = "/interface/sf-manufacturers/" .. parameters.manufacturer:lower() .. ".png"
  end
  
  --Replace some tags which are useful in the combat rifles
  replacePatternInData(config, nil, "<manufacturer>", parameters.manufacturer)
  replacePatternInData(config, nil, "<manufacturerName>", generationConfig and generationConfig.manufacturerConfigs[parameters.manufacturer].name or "")
  replacePatternInData(config, nil, "<manufacturerNickname>", generationConfig and generationConfig.manufacturerConfigs[parameters.manufacturer].nickname or "")
  replacePatternInData(config, nil, "<elementalType>", elementalType)
  replacePatternInData(config, nil, "<elementalName>", elementalType:gsub("^%l", string.upper))
  
  replacePatternInData(parameters, nil, "<manufacturer>", parameters.manufacturer)
  replacePatternInData(parameters, nil, "<manufacturerName>", generationConfig and generationConfig.manufacturerConfigs[parameters.manufacturer].name or "")
  replacePatternInData(parameters, nil, "<manufacturerNickname>", generationConfig and generationConfig.manufacturerConfigs[parameters.manufacturer].nickname or "")
  replacePatternInData(parameters, nil, "<elementalType>", elementalType)
  replacePatternInData(parameters, nil, "<elementalName>", elementalType:gsub("^%l", string.upper))

  --Set price
  config.price = (config.price or 0) * root.evalFunction("itemLevelPriceMultiplier", configParameter("level", 1))

  return config, parameters
end

--Determine the rarity to use
function determineRarity(config, itemRarity, size)
  local actualRarity
  --Determine the max rarity
  local maxRarity = size * 10
  
  --Check the rarity against its factors
  if itemRarity <= maxRarity * config["common"] then
    --If avgRarity <= 4 then it's a Common
    actualRarity = "Common"
  elseif itemRarity <= maxRarity * config["uncommon"] then
    --If avgRarity <= 0.55 and > 0.4 then it's a 
    actualRarity = "Uncommon"
  elseif itemRarity <= maxRarity * config["rare"] then
    --If avgRarity <= 7 and > 0.55 then rare 
    actualRarity = "Rare"
  else
    --Anything above 7 is legendary
    actualRarity = "Legendary"
  end
  
  return actualRarity
end

--Adjust ability based on new stats
function correctAbility(config, primaryAbilityMultipliers)
  --Adjust recoil and firetimes to match firerate
  local correctedAbility = nebUtil.multiplyTables(config.primaryAbility, primaryAbilityMultipliers)
  
  --Adjust durations to match firetime with some hold on the fire stance
  correctedAbility.stances.fire.duration = correctedAbility.fireTime * 0.02
  correctedAbility.stances.cooldown.duration = correctedAbility.fireTime * 0.98
  
  --Determine the amount to adjust the rotations by
  local adjustFactor = ((correctedAbility.fireTime > 1) and math.max(1, (correctedAbility.fireTime - 1) * (correctedAbility.fireTime - 1) + 1) or correctedAbility.fireTime)
  
  --Allow rotation if gun is a burst gun
  correctedAbility.stances.fire.allowRotate = (correctedAbility.fireType == "burst")
  
  --Apply new rotations to the both fire and cooldown stances
  correctedAbility.stances.fire.weaponRotation = correctedAbility.stances.fire.weaponRotation * adjustFactor
  correctedAbility.stances.fire.armRotation = correctedAbility.stances.fire.weaponRotation * 0.5
  correctedAbility.stances.cooldown.weaponRotation = correctedAbility.stances.cooldown.weaponRotation * adjustFactor
  correctedAbility.stances.cooldown.armRotation = correctedAbility.stances.cooldown.weaponRotation * 0.5
  
  --Make inaccuracy scale a bit with projectile count
  correctedAbility.inaccuracy = correctedAbility.projectileCount > 1 and (correctedAbility.inaccuracy * (1 + (correctedAbility.projectileCount - 1) * 0.1)) or correctedAbility.inaccuracy
  
  return correctedAbility
end

function scaleConfig(ratio, value)
  if type(value) == "table" then
    return util.lerp(ratio, value[1], value[2])
  else
    return value
  end
end