if not partPicker then
  partPicker = {};

  --[[ Note from C0bra5
    I changed the behaviour of the part generator in order to make it easier
    to work with in the future and more logical in it's approach.

    Instead of repeatedly trying to find a compatible parts for an item;
    I create a list of items filtered part ids that are compatible and pick
    randomly from that filtered list. I also throw an error when there are no
    compatible parts as this condition should never occur and would likely
    cause unknown behaviours down the line if it were to occure.

    I also decoupled the processor code from the picking code itself; This
    should help with making this framework more re-usable in the future.

    I also made it so that the seed is passed to the generator function. This
    allows the other uses of the random source to be more consistent across
    multiple runs of the build script since this part may not be ran and therefore
    causing calls to the random source to differ past the first run of the buildscript.

    The returned object now looks like this in json
    {
      "partType" : {
        "id" : "partId",
        "parameters" : {
          "paramName" : "paramValue"
        }
      },
      "partType" : {
        "id" : "partId",
        "parameters" : {
          "paramName" : "paramValue"
        }
      },
      ...
    }
  ]]

  -- PPPPPP  AAAAAA  RRRRRR  TTTTTT          GGGGGG  EEEEEE  NN  NN  EEEEEE  RRRRRR  AAAAAA  TTTTTT  IIIIII  OOOOOO  NN  NN
  -- PP  PP  AA  AA  RR  RR    TT            GG      EE      NNN NN  EE      RR  RR  AA  AA    TT      II    OO  OO  NNN NN
  -- PPPPPP  AAAAAA  RRRRRR    TT            GG GGG  EEEEEE  NNNNNN  EEEEEE  RRRRRR  AAAAAA    TT      II    OO  OO  NNNNNN
  -- PP      AA  AA  RR RR     TT            GG  GG  EE      NN NNN  EE      RR RR   AA  AA    TT      II    OO  OO  NN NNN
  -- PP      AA  AA  RR  RR    TT            GGGGGG  EEEEEE  NN  NN  EEEEEE  RR  RR  AA  AA    TT    IIIIII  OOOOOO  NN  NN

  --Generate the parts to use for the gun
  function partPicker.generateParts(currentParts, generatorConfig, seed)
    -- default the stuff just in case
    currentParts = currentParts or {};
    -- create a random source unique to this so that the generation is more consistent
    local randomSource = sb.makeRandomSource(seed);
    -- seems to make it more random
    randomSource:addEntropy(randomSource:randu32());
    -- create the parts in order using the part sequence
    for _, partType in ipairs(generatorConfig.partSequence) do
      -- random seed so that the number or random calls stays the same
      local pickSeed = randomSource:randu32();
      -- get the config for the current part type
      local partConfig = generatorConfig.partConfigs[partType];

      -- pick the part if it's not already specified
      if not currentParts[partType] then
        -- create a list of the usable part ids
        local usablePool = partPicker.createPickPool(partConfig, currentParts);
        -- if no parts were compatible throw out an error to stop the script in order to prevent further damage
        if #usablePool <= 0 then
          error(string.format("Could not find compatible %s\n Current parts:\n%s", partType, sb.printJson(currentParts, 1)));
        end
        -- get id of the generated part
        local partId = partPicker.getRandomFromList(usablePool, pickSeed);
        -- save it to the current parts
        currentParts[partType] = {
          id = partId
        }
      end

      -- if there are processors, add the parameters object
      if partConfig.processors and #partConfig.processors > 0 then
        -- create the parameters object
        local partParameters = currentParts[partType].parameters or {};
        -- save it to the current parts
        currentParts[partType].parameters = partParameters;
        -- load the part data for the processors to use
        local partData = partConfig.pool[currentParts[partType].id];
        -- run the processors
        for _, processorName in ipairs(partConfig.processors) do
          partPicker.processors[processorName](partData, partParameters, randomSource:randu32());
        end
      end
    end

    -- return the picked parts
    return currentParts;
  end

  -- creates a list of compatible part ids for a given part config
  function partPicker.createPickPool(partConfig, currentParts)
    -- a list of compatible part IDs
    local pickPool = {};

    if not partConfig.filters or #partConfig.filters <= 0 then
      -- if we don't need to filter don't filter
      for partId, partData in pairs(partConfig.pool) do
        -- prevent parts marked as unique from being generated automatically
        if not partData.unique then
          table.insert(pickPool, partId);
        end
      end
    else
      -- look for parts that pass the filters
      for partId, partData in pairs(partConfig.pool) do
        -- prevent parts marked as unique from being generated automatically
        if not partData.unique then
          local success = true;
          for _, filterName in ipairs(partConfig.filters) do
            -- check if part passes filter
            if not partPicker.filters[filterName](partData, currentParts) then
              success = false;
              break;
            end
          end

          -- add part id to pool if the part passed inspection
          if success then
            table.insert(pickPool, partId);
          end
        end
      end
    end

    -- return all parts that passed the filter.
    return pickPool;
  end



  -- UU  UU  TTTTTT  IIIIII  LL      SSSSSS
  -- UU  UU    TT      II    LL      SS
  -- UU  UU    TT      II    LL      SSSSSS
  -- UU  UU    TT      II    LL          SS
  -- UUUUUU    TT    IIIIII  LLLLLL  SSSSSS

  -- Randomly pick a value from the a list
  function partPicker.getRandomFromList(list, seed)
    local rand = (seed % #list) + 1
    return list[rand]
  end




  -- FFFFFF  IIIIII  LL      TTTTTT  EEEEEE  RRRRRR  SSSSSS
  -- FF        II    LL        TT    EE      RR  RR  SS
  -- FFFFFF    II    LL        TT    EEEEEE  RRRRRR  SSSSSS
  -- FF        II    LL        TT    EE      RR RR       SS
  -- FF      IIIIII  LLLLLL    TT    EEEEEE  RR  RR  SSSSSS

  --[[
    Notes from C0bra5:

    I moved the filters to their own section inorder to prevent name collisions in the future.
  ]]
  partPicker.filters = {};

  -- Returns true if the part allows the elemental type of the part list
  function partPicker.filters.isCompatibleWithBodyElementalType(partData, currentParts)
    -- If no elements are provided, it works with anything
    if not partData.elementalTypes then
      return true;
    end

    -- Get the element of the current parts
    local bodyElementalType = currentParts.body.parameters.elementalType;
    for _, partElementalType in ipairs(partData.elementalTypes, currentParts) do
      if bodyElementalType == partElementalType then
        return true
      end
    end
    -- return false the body element type isn't available in this part
    return false;
  end



  -- PPPPPP  RRRRRR  OOOOOO  CCCCCC  EEEEEE  SSSSSS  SSSSSS  OOOOOO  RRRRRR  SSSSSS
  -- PP  PP  RR  RR  OO  OO  CC      EE      SS      SS      OO  OO  RR  RR  SS
  -- PPPPPP  RRRRRR  OO  OO  CC      EEEEEE  SSSSSS  SSSSSS  OO  OO  RRRRRR  SSSSSS
  -- PP      RR RR   OO  OO  CC      EE          SS      SS  OO  OO  RR RR       SS
  -- PP      RR  RR  OOOOOO  CCCCCC  EEEEEE  SSSSSS  SSSSSS  OOOOOO  RR  RR  SSSSSS

  --[[
    Notes from C0bra5:

    I moved the processors to their own section inorder to prevent name collisions in the future
  ]]
  partPicker.processors = {};

  -- Picks an elemental type when a part declares many.
  function partPicker.processors.pickElementalType(partData, partParameters, seed)
    partParameters.elementalType = partParameters.elementalType or (partData.elementalTypes and partPicker.getRandomFromList(partData.elementalTypes, seed)) or "physical";
  end

  -- Picks a name prefix when a part declares many
  function partPicker.processors.pickNamePrefix(partData, partParameters, seed)
    partParameters.prefix = partParameters.prefix or partPicker.getRandomFromList(partData.namePrefix, seed);
  end

  -- Picks a name root when a part declares many
  function partPicker.processors.pickNameRoot(partData, partParameters, seed)
    partParameters.root = partParameters.root or partPicker.getRandomFromList(partData.nameRoot, seed);
  end

  -- Picks a name suffix when a part declares many
  function partPicker.processors.pickNameSuffix(partData, partParameters, seed)
    partParameters.suffix = partParameters.suffix or partPicker.getRandomFromList(partData.nameSuffix, seed);
  end

end
