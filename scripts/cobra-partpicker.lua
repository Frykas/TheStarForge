if not partPicker then
  partPicker = {};
  partPicker.filters = {};
  partPicker.selectors = {};
  partPicker.version = 1;
  -- set to -1 to force all weapons to rebuild
  -- partPicker.version = -1;

  --- @class PartDescriptor # a descriptor for a part list
  --- @field id string # the id of the part
  --- @field elementalType string # **optional** the elemental type of the part
  --- @field namePrefix string # **optional** the id of the string
  --- @field nameRoot string # **optional** the id of the string
  --- @field nameSuffix string # **optional** the id of the string

  -- for when you add other kind of part pickers add and @field line to this block with the new type of part
  --- @class PartList # A list of parts and the parameters chosen for them.
  --- @field body PartDescriptor
  --- @field stock PartDescriptor
  --- @field barrel PartDescriptor
  --- @field magazine PartDescriptor
  --- @field attachment PartDescriptor

  --- @class PartParameters # The parameters passed onto the part picker.
  --- @field all PartDescriptor
  --- @field body PartDescriptor
  --- @field stock PartDescriptor
  --- @field barrel PartDescriptor
  --- @field magazine PartDescriptor
  --- @field attachment PartDescriptor

  --- @class PartGenerationConfiguration # the id of the string
  --- @field basePartDirectory string # This is the folder where the visual assets are stored for the parts described in this file.
  --- @field partSequence string[] # This is the order in which the parts are generated
  --- @field partConfigs table<string, PartGeneratorPartConfig> # the id of the string

  --- @class PartGeneratorPartConfig # The configuration for a specific part type.
  --- @field filters table<string, string|table> # The set of filters to apply when selecting a part.
  --- @field selectors string[] # The set of value selectors for each parts.
  --- @field pool table<string, table> # The list of part all indexed by their ids.



  --[[
    The returned object now looks like this in json
    {
      "body" : {
        "id" : "partId",
        "elementalType" : "fire"
      },
      "partType" : {
        "id" : "partId",
        "paramName" : "paramValue"
      },
      ...
    }
  ]]

  --[[ example of part params
  /spawnitem starforge-combatrifle 1 '
  {
    "partParams" : {
      "all" : {
        // all parts must either be from elpis or lack a manifacturer
        "manufacturer" : "elpisElements"
      },
      "body" : {
        // elemental type of the body will need to be fire-compatible and automatically set to fire element
        "elementalType" : "fire"
      },
      "barrel" : {
        // just use the vitrium 3 barrel, you can also force a unique part to show up this way
        "id" : "vitrium3",
        // some pre-selected values
        "suffix" : "of the edge";
      },
      // just use the grenade launcher 1 attachment but also generate the rest of the data naturally for it.
      // you can use this to specify a unique part
      "attachment" : "grenadeLauncher1"
    }
  }
  '
  ]]

  -- PPPPPP  AAAAAA  RRRRRR  TTTTTT          GGGGGG  EEEEEE  NN  NN  EEEEEE  RRRRRR  AAAAAA  TTTTTT  IIIIII  OOOOOO  NN  NN
  -- PP  PP  AA  AA  RR  RR    TT            GG      EE      NNN NN  EE      RR  RR  AA  AA    TT      II    OO  OO  NNN NN
  -- PPPPPP  AAAAAA  RRRRRR    TT            GG GGG  EEEEEE  NNNNNN  EEEEEE  RRRRRR  AAAAAA    TT      II    OO  OO  NNNNNN
  -- PP      AA  AA  RR RR     TT            GG  GG  EE      NN NNN  EE      RR RR   AA  AA    TT      II    OO  OO  NN NNN
  -- PP      AA  AA  RR  RR    TT            GGGGGG  EEEEEE  NN  NN  EEEEEE  RR  RR  AA  AA    TT    IIIIII  OOOOOO  NN  NN

  --- Generates a list of part specifications for use by a modular item.
  --- @param params PartParameters # Allows you to manually set parameters for a given part.
  --- @param generationConfig PartGenerationConfiguration # Allows you to specify filters that can be used to narrow the part selection process to specific parts.
  --- @param seed integer # The contents of the file that document every part that can be used to form a modular item.
  --- @return PartList, integer
  function partPicker.generateParts(params, generationConfig, seed)
    -- Start with a blank slate.
    params = params or {};
    local currentParts = {};

    -- Create the parts in the orider specified by the generation config's part sequence property.
    for _, partType in ipairs(generationConfig.partSequence) do

      -- create final filter
      local filters = {};
      mergeFilters(filters, generationConfig.partConfigs[partType].filters); -- <partList>.config
      mergeFilters(filters, params.all); -- partParams.all
      mergeFilters(filters, params[partType]); -- partParams.<partTypes>

      -- Generate the part descriptor.
      local partDescriptor = partPicker.pickPart(generationConfig, partType, filters, currentParts, seed);

      -- caching
      local partTypeConfig = generationConfig.partConfigs[partType];
      -- Get the list of selector functions for the the current part type from the generator config.
      local selectors = partTypeConfig.selectors;
      if selectors ~= nil then
        -- Get the config for the part
        local partConfig = partTypeConfig.pool[partDescriptor.id];
        -- run the selectors
        for _, selectorName in ipairs(selectors) do
          if type(partConfig[selectorName]) == 'table' then

            if (params[partType] or {})[selectorName] == nil then
              partDescriptor[selectorName] = partPicker.getRandomFromList(partConfig[selectorName], seed, selectorName) ;
            elseif params[partType][selectorName] ~= nil then
              partDescriptor[selectorName] = params[partType][selectorName];
            end
          end
        end
      end
      currentParts[partType] = partDescriptor;
    end

    -- return the picked parts
    return currentParts, partPicker.version
  end

  ---Merges filters on top of each other. Newer values override older values.
  ---@param filterList table # The current list of filters.
  ---@param newFilters table # The list of filters to overlay on top of the current ones.
  function mergeFilters(filterList, newFilters)
    newFilters = newFilters or {}; -- may not exist.
    if type(newFilters) == "string" then
      filterList.id = newFilters; -- for set parts
    else
      for k, v in pairs(newFilters) do
        filterList[k] = v; -- for procedural generation
      end
    end
  end

  --- creates a list of compatible part ids for a given part config
  --- @param generationConfig PartGenerationConfiguration
  --- @param partType string
  --- @param filters table<string, any>
  --- @param currentParts table<string, PartDescriptor>
  --- @param seed integer
  --- @return PartDescriptor 
  function partPicker.pickPart(generationConfig, partType, filters, currentParts, seed)
    -- if the filter has an id already set we don't need to do anything.
    if type(filters.id) == "string" then return filters; end
    -- Create a list of allowed parts
    local pickPool = {};

    

    -- we need to sort here because the loaded data doesn't have the same order everytime
    local partIds = {};
    for partId in pairs(generationConfig.partConfigs[partType].pool) do
      table.insert(partIds, partId);
    end
    table.sort(partIds, function (a,b) return a < b; end)

    for _, partId in ipairs(partIds) do
      local partConfig = generationConfig.partConfigs[partType].pool[partId];
      
      -- Unique parts will be set manually using the block above.
      if not partConfig.unique then
        -- All filters must pass
        if partPicker.runFilters(filters, partConfig, currentParts, generationConfig) then
          table.insert(pickPool, partId);
        end;
      end
    end
    -- pick a usable part
    if #pickPool <= 0 then
      sb.logError("[PartPicker] There were no viable parts for the following settings:");
      sb.logError("[PartPicker] partType: " .. sb.printJson(partType));
      sb.logError("[PartPicker] filters: " .. sb.printJson(filters));
      error("[PartPicker] There were no viable parts during the part selection process. See previous messages.")
    else
      return {
        id = partPicker.getRandomFromList(pickPool, seed, partType)
      };
    end
  end

  function partPicker.runFilters(filters, partConfig, currentParts, generationConfig)
    for filterName, filterConfig in pairs(filters or {}) do
      if not partPicker.filters[filterName](partConfig, filterConfig, currentParts, generationConfig) then
        return false;
      end
    end
    return true;
  end

  -- UU  UU  TTTTTT  IIIIII  LL      SSSSSS
  -- UU  UU    TT      II    LL      SS
  -- UU  UU    TT      II    LL      SSSSSS
  -- UU  UU    TT      II    LL          SS
  -- UUUUUU    TT    IIIIII  LLLLLL  SSSSSS

  -- Randomly pick a value from the a list
  -- @param: [Array] - list - A list of values.
  -- @param: [Any] - seed - A seed to generate a specific part.
  -- @param: [Any] - salt - Additional salt for the seed.
  -- @return: [bool]
  function partPicker.getRandomFromList(list, seed, salt)
    return list[sb.staticRandomI32Range(
      1, -- min inclusive
      #list, -- max inclusive
      seed, -- seed
      salt -- salt (the engine uses xxHash to generare the actual seed)
    )]
  end
  


  -- FFFFFF  IIIIII  LL      TTTTTT  EEEEEE  RRRRRR  SSSSSS
  -- FF        II    LL        TT    EE      RR  RR  SS
  -- FFFFFF    II    LL        TT    EEEEEE  RRRRRR  SSSSSS
  -- FF        II    LL        TT    EE      RR RR       SS
  -- FF      IIIIII  LLLLLL    TT    EEEEEE  RR  RR  SSSSSS

  --[[
    Notes from C0bra5:

    I moved the filters to their own section in order to prevent name collisions in the future.
  ]]


  -- Checks if a part matches a specific elementalType
  function partPicker.filters.elementalType(partConfig, params, currentParts, generationConfig)
    local targetType;

    if type(params) == 'string' then -- fetches the elemental type as the value of the parameter
      targetType = params;
    elseif params.fromPart ~= nil then -- fetches the elemental type from an other part
      targetType = currentParts[params.fromPart].elementalType; -- no need to default as we generate the data.
      -- if the part is physical and physical parts are accepted no matter the parent type; allow the part.
      if
        partConfig.elementalType == targetType or
        (params.isPhysicalOK and (partConfig.elementalType == nil or partConfig.elementalType == "physical"))
      then
        return true;
      end
    end
    if type(partConfig.elementalType) == 'string' then
      return partConfig.elementalType == targetType;
    elseif type(partConfig.elementalType) == 'table' then
      for _, partElementalType in ipairs(partConfig.elementalType) do
        -- if the part allows for the same elemental type as the parent; allow the part.
        if targetType == partElementalType then return true; end
      end
    end

    return false;
  end

  -- Checks if a part matches a specific manufacturer
  function partPicker.filters.manufacturer(partConfig, params, currentParts, generationConfig)
    -- Allow if no manufacturer specified in part data.
    return partConfig.manufacturer == nil or partConfig.manufacturer == params;
  end
end

