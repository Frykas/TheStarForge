require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/scripts/staticrandom.lua"
require "/items/buildscripts/abilities.lua"

require "/scripts/starforge-util.lua"
require "/scripts/cobra-partpicker.lua"

--[[
  Note from C0bra5:

  Here are the changes:
  - Names are computed in their own section in order to keep the code more self-contained
  - Rarity is computed in it's own function, isolated from any changes
  - Directly loads elemental types out of the part partParameters.
  - Directly loads the manufacturer out of the body part data.
  - Changed builderConfig.gunParts to builder.partLayerOrder in order to match the .activeitem
  - renamed builderConfig to archetypeConfig to better match the actual contents
  - removed the elementalType local variable out of the build function in order to reduce issues potential data desync issues
  - removed the attachmentOffset local variable from the build function as it's actually what it ends up being
  - removed the generationDirectory local variable as it's redundent from generationConfig.basePartDirectory
  - removed parameters.generatedDirectives as it is no longer needed.
]]

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


  -- initialise randomisation
  local randomSource;
  if seed or parameters.seed then
    seed = seed or parameters.seed;
    parameters.seed = seed;
  else
    randomSource = sb.makeRandomSource()
    seed = randomSource:randu32()
    parameters.seed = seed
  end
  -- make sure we have a random source
  randomSource = randomSource or sb.makeRandomSource(seed);
  randomSource:init(seed);
  -- seems to make it more random
  randomSource:addEntropy(randomSource:randu32());



  -- Here is a list of variables used to store the "seeds" that would be needed
  -- this prevents incinsistent behaviours due to randomSource not being called
  -- the right amount of times due to caching.
  local randomisedDirectivesSeed = randomSource:randu32();
  local generatePartSeed = randomSource:randu32();
  local randomSpriteSeed = randomSource:randu32();
  local archetypeSeed = randomSource:randu32();
  local randomAltAbilitySeed = randomSource:randu32();
  local randomPrimaryAbilitySeed = randomSource:randu32();



  -- load in the generic config for all multi-part weapons and pick a random color directive
  local multipartWeaponConfig = root.assetJson("/items/active/weapons/ranged/generated/starforge-multipartweapons.config");
  if not parameters.randomisedDirective then
    parameters.randomisedDirective = getRandomKeyWithSeed(multipartWeaponConfig.randomisedDirectives, randomisedDirectivesSeed);
  end

  -- Load and determine the weapon archetype and generation properties for the weapon
  if not configParameter("archetype") then
    parameters.archetype = determineArchetype(config.archetypes, archetypeSeed);
  end
  local archetypeConfig = config.archetypes[parameters.archetype];
  -- load the configs we need
  local generationConfig = root.assetJson(util.absolutePath(directory, archetypeConfig.generationConfig))

  -- make sure the parts exist
  -- it won't actually do anything if all the parts are pre-generated
  parameters.weaponParts = partPicker.generateParts(parameters.weaponParts, generationConfig, generatePartSeed)

  function getPartData(partType)
    local partId = parameters.weaponParts[partType].id;
    return generationConfig.partConfigs[partType].pool[partId];
  end

  -- make sure the name is selected
  config.shortdescription = generateNameFromPartList(parameters.weaponParts)


  -- determine the rarity, not cached as part rarity is not saved as a parameter
  config.rarity = determineRarity(parameters.weaponParts, generationConfig.partConfigs, multipartWeaponConfig.indexToRarity)

  -- determine the manufacturer and load the config for it
  parameters.manufacturer = generationConfig.partConfigs.body.pool[parameters.weaponParts.body.id].manufacturer;
  local manufacturerConfig = root.assetJson("/items/active/weapons/ranged/generated/starforge-manufacturer.config:" .. parameters.manufacturer);

  -- determine the elemental type
  parameters.elementalType = parameters.weaponParts.body.parameters.elementalType;



  -- load the cumulative part data
  local primaryAbilityData = {}
  local primaryAbilityMultipliers = {}
  parameters.attachmentOffset = {0, 0}
  for x, partName in pairs(generationConfig.partSequence) do
    local part = getPartData(partName);

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


    --Determine sprite to use for each part
    local chosenSprite = getRandomInListWithSeed(part.images, randomSpriteSeed)
    config.animationParts[partName] = util.absolutePath(string.gsub(generationConfig.basePartDirectory, "<partName>", partName), chosenSprite)
    --Find the same position in the array and use it to find the fullbright to use
    local spriteIndex = nebUtil.findIndex(part.images, chosenSprite)
    if spriteIndex and part.fullbrightImages then
        config.animationParts[partName .. "Fullbright"] = util.absolutePath(string.gsub(generationConfig.basePartDirectory, "<partName>", partName), part.fullbrightImages[spriteIndex])
    end

    --If specified, keep adding this
    if part.muzzleOffset then
      parameters.muzzleOffset = vec2.add((config.muzzleOffset or {0, 0}), part.muzzleOffset)
    end

    if part.attachmentOffset then
      parameters.attachmentOffset = vec2.add(parameters.attachmentOffset, part.attachmentOffset)
    end

    if part.altAbilityType then
      -- transfer the ability from the part to the config
      config.altAbilityType = part.altAbilityType;
      config.altAbility = part.altAbility;

      if config.altAbility.fireOffset then
        config.altAbility.fireOffset = vec2.add(config.altAbility.fireOffset, parameters.attachmentOffset)
      end
    end
  end


  --Apply the level if fixedLevel is false
  if level and not configParameter("fixedLevel", false) then
    parameters.level = level
  end


  --Select, load and merge abilities
  setupAbility(config, parameters, "primary", archetypeConfig, randomPrimaryAbilitySeed)
  setupAbility(config, parameters, "alt", archetypeConfig, randomAltAbilitySeed)

  --Apply elemental configs
  if archetypeConfig.elementalConfig then
    util.mergeTable(config, archetypeConfig.elementalConfig[parameters.elementalType])
  end
  if config.altAbility and config.altAbility.elementalConfig then
    util.mergeTable(config.altAbility, config.altAbility.elementalConfig[parameters.elementalType])
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

  config.primaryAbility = correctAbility(config, primaryAbilityMultipliers, seed)

  --Calculate damage level multiplier
  config.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", configParameter("level", 1))

  --Build palette swap directives
  config.paletteSwaps = ""
  if archetypeConfig.palette then
    local palette = root.assetJson(util.absolutePath(directory, archetypeConfig.palette))
    local selectedSwaps = randomFromList(palette.swaps, seed, "paletteSwaps")
    for k, v in pairs(selectedSwaps) do
      config.paletteSwaps = string.format("%s?replace=%s=%s", config.paletteSwaps, k, v)
    end
  end

  --Merge extra animationCustom
  if archetypeConfig.animationCustom then
    config.animationCustom = util.mergeTable(config.animationCustom or {}, archetypeConfig.animationCustom)
  end

  --Animation parts
  if archetypeConfig.animationParts then
    config.animationParts = config.animationParts or {}
    if parameters.animationPartVariants == nil then parameters.animationPartVariants = {} end
    for k, v in pairs(archetypeConfig.animationParts) do
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

  -- computes the color directives
  config.paletteSwaps =
    config.paletteSwaps ..
    multipartWeaponConfig.elementalDirectives[parameters.elementalType] ..
    manufacturerConfig.rarityDirectives[config.rarity:lower()] ..
    multipartWeaponConfig.randomisedDirectives[parameters.randomisedDirective]

  --Offset combat rifle parts
--[[  if archetypeConfig.partLayerOrder then
    construct(config, "animationCustom", "animatedParts", "parts")
    local imageOffset = {0, 0}
    local gunPartOffset = {0, 0}
    for _, part in ipairs(archetypeConfig.partLayerOrder) do
      local imageSize = root.imageSize(config.animationParts[part])
      construct(config.animationCustom.animatedParts.parts, part, "properties")

      imageOffset = vec2.add(imageOffset, {imageSize[1] / 2, 0})
      config.animationCustom.animatedParts.parts[part].properties.offset = {config.baseOffset[1] + imageOffset[1] / 8, config.baseOffset[2]}
      partImagePositions[part] = copy(imageOffset)
      imageOffset = vec2.add(imageOffset, {imageSize[1] / 2, 0})
    end
    config.muzzleOffset = vec2.add(config.baseOffset, vec2.add(config.muzzleOffset or {0,0}, vec2.div(imageOffset, 8)))
  end]]

  --Randomise fire sounds
  if config.fireSounds then
    construct(config, "animationCustom", "sounds", "fire")
    local sound = randomFromList(config.fireSounds, seed, "fireSound")
    config.animationCustom.sounds.fire = type(sound) == "table" and sound or { sound }
  end

  --Build the inventory icon
  local partOrder = archetypeConfig.iconParts or {}
  table.sort(partOrder, function(a, b)
    return getZLevelOfPart(a, config, config.animationCustom or {}) < getZLevelOfPart(b, config, config.animationCustom or {})
  end)
  
  if not config.inventoryIcon and config.animationParts then
    config.inventoryIcon = jarray()
    local parts = partOrder
    for _, partName in pairs(parts) do
      local offset = {0, 0}
      if partName == "attachment" then
        offset = vec2.add(vec2.mul(parameters.attachmentOffset, 10), {0, -1.25})
      end
      local drawable = {
        image = config.animationParts[partName] .. config.paletteSwaps,
        position = offset
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

    if parameters.elementalType ~= "physical" then
      config.tooltipFields.damageKindImage = "/interface/elements/" .. parameters.elementalType .. ".png"
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
  replacePatternInData(config, nil, "<manufacturer>", parameters.manufacturer or "")
  replacePatternInData(config, nil, "<manufacturerName>", manufacturerConfig and manufacturerConfig.name or parameters.manufacturer or "")
  replacePatternInData(config, nil, "<manufacturerNickname>", manufacturerConfig and manufacturerConfig.nickname or parameters.manufacturer or "")
  replacePatternInData(config, nil, "<elementalType>", parameters.elementalType)
  replacePatternInData(config, nil, "<elementalName>", parameters.elementalType:gsub("^%l", string.upper))

  replacePatternInData(parameters, nil, "<manufacturer>", parameters.manufacturer)
  replacePatternInData(parameters, nil, "<manufacturerName>", manufacturerConfig and manufacturerConfig.name or parameters.manufacturer or "")
  replacePatternInData(parameters, nil, "<manufacturerNickname>", manufacturerConfig and manufacturerConfig.nickname or parameters.manufacturer or "")
  replacePatternInData(parameters, nil, "<elementalType>", parameters.elementalType)
  replacePatternInData(parameters, nil, "<elementalName>", parameters.elementalType:gsub("^%l", string.upper))

  --Set price
  config.price = (config.price or 0) * root.evalFunction("itemLevelPriceMultiplier", configParameter("level", 1))

  return config, parameters
end

--animConfig needs to be config, is current animcustom fix that
function getZLevelOfPart(partName, config, animCustom)
  local animConfig = util.mergeTable(root.assetJson(config.animation).animatedParts.parts, animCustom)
  local zLevel = animConfig[partName].properties.zLevel or 0
  return zLevel
end

-- Generates the name of a weapon given a part list
-- this also removes the elements it takes the data from from the parameter list
-- in order to remove duplicated data.
function generateNameFromPartList(partList)
  local namePrefix = "";
  local nameRoot = "";
  local nameSuffix = "";

  for _, partInfo in pairs(partList) do
    if partInfo.parameters then

      -- prefix
      if partInfo.parameters.prefix then
        namePrefix = partInfo.parameters.prefix;
      end
      -- root
      if partInfo.parameters.root then
        nameRoot = partInfo.parameters.root;
      end
      -- suffix
      if partInfo.parameters.suffix then
        nameSuffix = partInfo.parameters.suffix;
      end

    end
  end

  local name = "";
  -- apply prefix
  if namePrefix ~= "" then
    name = name .. namePrefix;
    -- add space when prefix does not end with -
    local last = namePrefix:sub(-1);
    if last ~= "-" then
      name = name .. " ";
    end
  end

  -- apply root
  if nameRoot ~= "" then
    name = name .. nameRoot;
  end

  -- apply suffix
  if nameSuffix ~= "" then
    -- add space when string does not start with - or '
    local start = nameSuffix:sub(1,1);
    if start ~= "'" and start ~= "-" then
      name = name .. " ";
    end
    name = name .. nameSuffix;
  end

  return name;
end

-- looks at the list of parts and outputs the item rarity.
function determineRarity(partList, partConfigs, rarityConfig)
  local totalRarity = 0;
  local maxRarity = jsize(partList) * 10;

  for partType, partInfo in pairs(partList) do
    local partData = partConfigs[partType].pool[partInfo.id];
    totalRarity = totalRarity + partData.rarity or 1;
  end

  --Check the rarity against its factors
  if totalRarity <= maxRarity * rarityConfig["common"] then
    --If avgRarity <= 4 then it's common
    return "Common"
  elseif totalRarity <= maxRarity * rarityConfig["uncommon"] then
    --If avgRarity <= 0.55 and > 0.4 then it's uncommon
    return "Uncommon"
  elseif totalRarity <= maxRarity * rarityConfig["rare"] then
    --If avgRarity <= 7 and > 0.55 then it's rare
    return "Rare"
  else
    --Anything above 7 is legendary
    return "Legendary"
  end

end

-- picks an archetype for the weapon based on the provided seed
function determineArchetype(archetypes, seed)
  local usableArchetypes = {};
  for archetypeName, archetypeConfig in pairs(archetypes) do
    if not archetypeConfig.unique then
      table.insert(usableArchetypes, archetypeName);
    end
  end

  if #usableArchetypes <= 0 then
    error("No random archetypes declared.");
  end

  return usableArchetypes[(seed % #usableArchetypes) + 1];
end

function getRandomInListWithSeed(list, seed)
  return list[(seed % #list) + 1];
end

function getRandomKeyWithSeed(object, seed)
  local list = {};
  for key,v in pairs(object) do
    table.insert(list, key)
  end
  return getRandomInListWithSeed(list, seed);
end

--Adjust ability based on new stats
function correctAbility(config, primaryAbilityMultipliers, seed)
  --Adjust recoil and firetimes to match firerate
  local correctedAbility = nebUtil.multiplyTables(config.primaryAbility, primaryAbilityMultipliers)

  --Adjust durations to match firetime with some hold on the fire stance
  correctedAbility.stances.fire.duration = correctedAbility.fireTime * 0.02
  --correctedAbility.stances.cooldown.duration = correctedAbility.fireTime * 0.98

  --Determine the amount to adjust the rotations by
  local adjustFactor = ((correctedAbility.fireTime > 1) and math.max(1, (correctedAbility.fireTime - 1) * (correctedAbility.fireTime - 1) + 1) or correctedAbility.fireTime)

  --Allow rotation if gun is a burst gun
  correctedAbility.stances.fire.allowRotate = (correctedAbility.fireType == "burst")

  --Apply new rotations to the both fire and cooldown stances
  correctedAbility.stances.fire.weaponRotation = correctedAbility.stances.fire.weaponRotation * adjustFactor * ((correctedAbility.fireType == "burst") and 1.35 or 1)
  correctedAbility.stances.fire.armRotation = correctedAbility.stances.fire.weaponRotation * 0.5
  correctedAbility.stances.cooldown.weaponRotation = correctedAbility.stances.fire.weaponRotation
  correctedAbility.stances.cooldown.armRotation = correctedAbility.stances.fire.armRotation

  
  --local cooldownTime = correctedAbility.stances.cooldown.duration * (correctedAbility.burstCount or 1);
  --sb.logInfo(string.format("seed %10d | fireType %s | RoF %7.4f | cooldown %7.4f | weaponRotation %7.4f", seed, correctedAbility.fireType, 1 / correctedAbility.fireTime, cooldownTime, correctedAbility.stances.fire.weaponRotation));
  
  --Ensure we dont get lower than 1 projectile count
  correctedAbility.projectileCount = math.max(1, correctedAbility.projectileCount)
  if correctedAbility.projectileCount > 1 then
    correctedAbility.baseDps = correctedAbility.baseDps + (correctedAbility.projectileCount * 0.7)
  end

  --Make inaccuracy scale a bit with projectile count
  correctedAbility.inaccuracy = correctedAbility.projectileCount > 1 and (correctedAbility.inaccuracy + 0.01 * (1 + (correctedAbility.projectileCount - 1) * 0.2)) or correctedAbility.inaccuracy

  return correctedAbility
end

function scaleConfig(ratio, value)
  if type(value) == "table" then
    return util.lerp(ratio, value[1], value[2])
  else
    return value
  end
end
