require "/scripts/util.lua"
require "/scripts/starforge-util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/scripts/staticrandom.lua"
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

  if level and not configParameter("fixedLevel", false) then
    parameters.level = level
  end

  --Initialize randomization
  if seed then
    parameters.seed = seed
  else
    seed = configParameter("seed")
    if not seed then
      math.randomseed(util.seedTime())
      seed = math.random(1, 4294967295)
      parameters.seed = seed
    end
  end

  --Determine generation profile
  local builderConfig = {}
  if config.builderConfig then
    builderConfig = randomFromList(config.builderConfig, seed, "builderConfig")
  end

  --Build the combat rifle
  local generationConfig
  if builderConfig.buildConfig then
	generationConfig = root.assetJson(util.absolutePath(directory, builderConfig.buildConfig))
	local parts = generationConfig.parts
	local generationDirectory = generationConfig.basePartDirectory
	
	config.animationParts = {}
	
	--Default the names
	local namePrefix = ""
	local nameRoot = ""
	local nameSuffix = ""
	local rarityFactor = 0
	local size = 0
	
	parameters.primaryAbilityData = {}
	parameters.primaryAbilityMultipliers = {}
	
	parameters.partList = util.mergeTable(config.partList or {}, parameters.partList or {})
	for k, v in pairs(parts) do
	  size = size + 1

	  local chosenPart = parameters.partList[k]
	  if not chosenPart then
	    chosenPart = generatePart(k, v, seed, parameters)
  	    parameters.partList[k] = chosenPart
	  end

	  rarityFactor = rarityFactor + chosenPart.rarity
	  
	  if chosenPart.baseStats then
		parameters.primaryAbilityData = util.mergeTable(parameters.primaryAbilityData, chosenPart.baseStats)
	  end
	  if chosenPart.multipliers then
	    for y, x in pairs(chosenPart.multipliers) do
		  if not parameters.primaryAbilityMultipliers[y] then
		    parameters.primaryAbilityMultipliers[y] = x
		  elseif parameters.primaryAbilityMultipliers[y] then
		    parameters.primaryAbilityMultipliers[y] = parameters.primaryAbilityMultipliers[y] * x
		  end
		end
	  end
	  
	  if chosenPart.animationCustom then
	    config.animationCustom = util.mergeTable(config.animationCustom or {}, chosenPart.animationCustom)
	  end
	  
	  if k == "body" then
		--Determine basic parameters
		parameters.manufacturer = chosenPart.manufacturer
		parameters.elementalType = randomFromList(chosenPart.elementalTypes, seed, "chosenElement")
	  end
	  
	  --Set altfire in only attachment to avoid conflicts
	  if k == "attachment" then
	    builderConfig.altAbilities = {chosenPart.altAbility}
		config.altAbility = chosenPart.altAbilityConfig
	  end
	  
	  --Offset muzzle
	  if k == "barrel" then
	    config.muzzleOffset = chosenPart.muzzleOffset
	  end
	  
	  --Determine the name of the gun
	  if chosenPart.namePrefix then
		namePrefix = randomFromList(chosenPart.namePrefix, seed, "namePrefix")
	  end
	  if chosenPart.nameRoot then
		nameRoot = randomFromList(chosenPart.nameRoot, seed, "nameRoot")
	  end
	  if chosenPart.nameSuffix then
		nameSuffix = randomFromList(chosenPart.nameSuffix, seed, "nameSuffix")
	  end
	  
	  --Determine sprite to use for each part
	  local chosenSprite = randomFromList(chosenPart.images, seed, "chosen" .. k .. "Sprite")
	  config.animationParts[k] = util.absolutePath(string.gsub(generationDirectory, "<partName>", k), chosenSprite)
	  local spriteIndex = nebUtil.findIndex(chosenPart.images, chosenSprite)
	  if spriteIndex and chosenPart.fullbrightImages then
  	    config.animationParts[k .. "Fullbright"] = util.absolutePath(string.gsub(generationDirectory, "<partName>", k), chosenPart.fullbrightImages[spriteIndex])
	  end
	end
	
	config.rarity = determineRarity(generationConfig.indexToRarity, rarityFactor / size)
	
	--Apply the name
	local name = (namePrefix .. nameRoot .. nameSuffix)
	parameters.shortdescription = name
	
	--Apply directives
	local elementalDirectives = generationConfig.elementalDirectives[parameters.elementalType]
	local manufacturerDirectives = generationConfig.manufacturerConfigs[parameters.manufacturer].rarityDirectives[config.rarity:lower()]
	local randomisedDirectives = randomFromList(generationConfig.randomisedDirectives, seed, "randomisedDirectives")
	
	parameters.generatedDirectives = elementalDirectives .. manufacturerDirectives .. randomisedDirectives
  end
  local elementalType = parameters.elementalType
  
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
  util.mergeTable(config.primaryAbility, parameters.primaryAbilityData)
  
  --Preprocess shared primary attack config
  parameters.primaryAbility = parameters.primaryAbility or {}
  parameters.primaryAbility.fireTimeFactor = valueOrRandom(parameters.primaryAbility.fireTimeFactor, seed, "fireTimeFactor")
  parameters.primaryAbility.baseDpsFactor = valueOrRandom(parameters.primaryAbility.baseDpsFactor, seed, "baseDpsFactor")
  parameters.primaryAbility.energyUsageFactor = valueOrRandom(parameters.primaryAbility.energyUsageFactor, seed, "energyUsageFactor")

  config.primaryAbility.fireTime = scaleConfig(parameters.primaryAbility.fireTimeFactor, config.primaryAbility.fireTime)
  config.primaryAbility.baseDps = scaleConfig(parameters.primaryAbility.baseDpsFactor, config.primaryAbility.baseDps)
  config.primaryAbility.energyUsage = scaleConfig(parameters.primaryAbility.energyUsageFactor, config.primaryAbility.energyUsage) or 0

  -- preprocess melee primary attack config
  if config.primaryAbility.damageConfig and config.primaryAbility.damageConfig.knockbackRange then
    config.primaryAbility.damageConfig.knockback = scaleConfig(parameters.primaryAbility.fireTimeFactor, config.primaryAbility.damageConfig.knockbackRange)
  end

  -- preprocess ranged primary attack config
  if config.primaryAbility.projectileParameters then
    --config.primaryAbility.projectileType = "unbound" .. elementalType .. "bullet"
    if config.primaryAbility.projectileParameters.knockbackRange then
      config.primaryAbility.projectileParameters.knockback = scaleConfig(parameters.primaryAbility.fireTimeFactor, config.primaryAbility.projectileParameters.knockbackRange)
    end
  end
  
  config.primaryAbility = correctAbility(config, parameters)
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
    local parts = builderConfig.weaponParts or {}
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
function determineRarity(config, index)
  local actualRarity = "legendary"
  for rarity, threshold in pairs(config) do
	if index < threshold then
	  actualRarity = rarity
	end
  end
  return actualRarity
end

--Adjust ability based on new stats
function correctAbility(config, parameters)
  --Adjust recoil and firetimes to match firerate
  local correctedAbility = nebUtil.multiplyTables(config.primaryAbility, parameters.primaryAbilityMultipliers)
  
  --Adjust durations to match firetime with some hold on the fire stance
  correctedAbility.stances.fire.duration = correctedAbility.fireTime * 0.02
  correctedAbility.stances.cooldown.duration = correctedAbility.fireTime * 0.98
  
  --Determine the amount to adjust the rotations by
  local adjustFactor = ((correctedAbility.fireTime > 1) and math.max(1, (correctedAbility.fireTime - 1) * (correctedAbility.fireTime - 1) + 1) or correctedAbility.fireTime)
  
  --Allow rotation if gun is a burst gun
  correctedAbility.stances.fire.allowRotation = (correctedAbility.fireType == "burst")
  
  --Apply new rotations to the both fire and cooldown stances
  correctedAbility.stances.fire.weaponRotation = correctedAbility.stances.fire.weaponRotation * adjustFactor
  correctedAbility.stances.fire.armRotation = correctedAbility.stances.fire.weaponRotation * 0.5
  correctedAbility.stances.cooldown.weaponRotation = correctedAbility.stances.cooldown.weaponRotation * adjustFactor
  correctedAbility.stances.cooldown.armRotation = correctedAbility.stances.cooldown.weaponRotation * 0.5
  
  --Make inaccuracy scale a bit with projectile count
  correctedAbility.inaccuracy = correctedAbility.projectileCount > 1 and (correctedAbility.inaccuracy * (1 + (correctedAbility.projectileCount - 1) * 0.1)) or correctedAbility.inaccuracy
  
  return correctedAbility
end

--Generate the part for use
function generatePart(k, v, newSeed, parameters)
  local chosenPart 
  repeat
    chosenPart = randomFromList(v, newSeed, "chosen" .. k)
    newSeed = newSeed + 1
  until (isPartValid(chosenPart, parameters))
  
  return chosenPart
end

--Determine if the part is one we can use
function isPartValid(part, parameters)
  local success = true
  if part.elementalTypes and parameters.elementalType then
    if not nebUtil.tableContains(part.elementalTypes, parameters.elementalType) then
      success = false
    end
  end
  return success
end

function scaleConfig(ratio, value)
  if type(value) == "table" then
    return util.lerp(ratio, value[1], value[2])
  else
    return value
  end
end