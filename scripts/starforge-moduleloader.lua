--Thanks to C0bra5 for making this

if not nebModuleLoader then
  nebModuleLoader = {
    debug = false,
    modules = {},
    overrides = {
      init = init,
      update = update,
      uninit = uninit,
      build = build,
      createTooltip = createTooltip,
      activate = activate,
      apply = apply,
      onInteraction = onInteraction,
      hit = hit,
      die = die,
      containerCallback = containerCallback
    }
  }

  -- Registers a module for global event hooking.
  -- param: module - SFModule - The module to register
  -- param: [name] - string - The name of the module
  function nebModuleLoader.register(module, name)
    module.name = name or module.name
    module.failed = false
    table.insert(nebModuleLoader.modules, module)
  end
  
  function containerCallback(...)
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "preContainerCallback", ...)
    end
    
    if nebModuleLoader.overrides.init then
      nebModuleLoader.overrides.containerCallback(...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "containerCallback", ...)
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "postContainerCallback", ...)
    end
  end
  
  function die(...)
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "preDie", ...)
    end
    
    if nebModuleLoader.overrides.init then
      nebModuleLoader.overrides.die(...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "die", ...)
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "postDie", ...)
    end
  end
  
  function init(...)
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "prePreInit", ...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "preInit", ...)
    end
    
    if nebModuleLoader.overrides.init then
      nebModuleLoader.overrides.init(...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "init", ...)
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "postInit", ...)
    end
  end
  
  function activate(...)
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "preActivate", ...)
    end
    
    if nebModuleLoader.overrides.activate then
      nebModuleLoader.overrides.activate(...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "activate", ...)
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "postActivate", ...)
    end
  end
  
  function update(...)
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "preUpdate", ...)
    end
    
    if nebModuleLoader.overrides.update then
      nebModuleLoader.overrides.update(...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "update", ...)
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "postUpdate", ...)
    end
  end
  
  function hit(...)
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "preHit", ...)
    end
    
    if nebModuleLoader.overrides.hit then
      nebModuleLoader.overrides.hit(...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "hit", ...)
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "postHit", ...)
    end
  end
  
  function uninit(...)
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "preUninit", ...)
    end
    
    if nebModuleLoader.overrides.uninit then
      nebModuleLoader.overrides.uninit(...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "uninit", ...)
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "postUninit", ...)
    end
  end
  
  function onInteraction(...)
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "preUpdate", ...)
    end
    
    if nebModuleLoader.overrides.onInteraction then
      nebModuleLoader.overrides.onInteraction(...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "update", ...)
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      nebModuleLoader.doCall(module, "postUpdate", ...)
    end
  end
  
  function build(directory, config, parameters, ...)
    for _, module in ipairs(nebModuleLoader.modules) do
      config, parameters = nebModuleLoader.doCallWithReturn(module, "preBuild", {sb.jsonMerge({}, config), sb.jsonMerge({}, parameters)}, directory, config, parameters, ...)
    end
    
    if nebModuleLoader.overrides.build then
      config, parameters = nebModuleLoader.overrides.build(directory, config, parameters, ...)
    end
    
    for _, module in ipairs(nebModuleLoader.modules) do
      config, parameters = nebModuleLoader.doCallWithReturn(module, "build", {sb.jsonMerge({}, config), sb.jsonMerge({}, parameters)}, directory, config, parameters, ...)
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      config, parameters = nebModuleLoader.doCallWithReturn(module, "postBuild", {sb.jsonMerge({}, config), sb.jsonMerge({}, parameters)}, directory, config, parameters, ...)
    end

    return config, parameters
  end

  function apply(input, ...)
    for _, module in ipairs(nebModuleLoader.modules) do
      local result = nebModuleLoader.doCallWithReturn(module, "preApply", {sb.jsonMerge({}, input)}, input, ...)
      if result ~= nil then
        input = result
      end
    end

    if nebModuleLoader.overrides.build then
      local result = nebModuleLoader.overrides.apply(input, ...)
      if result ~= nil then
        input = result
      end
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      local result = nebModuleLoader.doCallWithReturn(module, "apply", {sb.jsonMerge({}, input)}, input, ...)
      if result ~= nil then
        input = result
      end
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      local result = nebModuleLoader.doCallWithReturn(module, "postApply", {sb.jsonMerge({}, input)}, input, ...)
      if result ~= nil then
        input = result
      end
    end

    return input
  end
  
  function createTooltip(...)
    local output = nil

    for _, module in ipairs(nebModuleLoader.modules) do
      local result = nebModuleLoader.doCallWithReturn(module, "preApply", {nil}, ...)
      if result ~= nil then
        output = (output or "") .. result
      end
    end

    if nebModuleLoader.overrides.build then
      local result = nebModuleLoader.overrides.apply(input, ...)
      if result ~= nil then
        output = (output or "") .. result
      end
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      local result = nebModuleLoader.doCallWithReturn(module, "apply", {nil}, ...)
      if result ~= nil then
        output = (output or "") .. result
      end
    end

    for _, module in ipairs(nebModuleLoader.modules) do
      local result = nebModuleLoader.doCallWithReturn(module, "postApply", {nil}, ...)
      if result ~= nil then
        output = (output or "") .. result
      end
    end

    return input
  end
  
  -- PCalls a function of a given name within a module.
  -- If the function being called has return values use doCallWithReturn
  -- param: module - SFModule - The module in which the module resides.
  -- param: funcName - String - The name of the function to be called.
  function nebModuleLoader.doCall(module, funcName, ...)
    if not module[funcName] then
      return
    end
    -- skip the pcalls if the project is in debug mode.
    if nebModuleLoader.debug then
      module[funcName](...)
    elseif not module.failed then
      local success, err = pcall(module[funcName], ...)
      if not success then
        module.failed = true
        pcall(module["onError"], err)
        sb.logInfo("[nebModuleLoader.doCall] A runtime error occured while executing a module's \"%s\"'s function. The error will follow.")
        sb.logInfo("%s", err)
      end
    end
  end
  
  -- PCalls a function of a given module and returns it's returned value.
  -- param: module - SFModule - The module in which the module resides.
  -- param: funcName - String - The name of the function to be called.
  -- param: errorDefault - Array - An array of values (because multiple return is a thing) which are retured when the module function errors out.
  -- return: any or multiple any - depends on what the function returns
  function nebModuleLoader.doCallWithReturn(module, funcName, errorDefault, ...)
    if not module[funcName] then
      return table.unpack(errorDefault)
    end
    -- skip the pcalls if the project is in debug mode.
    if nebModuleLoader.debug then
      return module[funcName](...)
    elseif not module.failed then
      local returnValues = table.pack(pcall(module[funcName], ...))
      if not returnValues[1] then
        module.failed = true
        pcall(module["onError"], err)
        sb.logInfo("[nebModuleLoader.doCallWithReturn] A runtime error occured while executing a module's \"%s\"'s function. The error will follow.")
        sb.logInfo("%s", returnValues[2])
        return table.unpack(errorDefault)
      else
        -- remove the success value from the pcall
        table.remove(returnValues,1)
        -- remove the n value from the table.pack
        returnValues.n = nil
        return table.unpack(returnValues)
      end
    else
      return table.unpack(errorDefault)
    end
  end
end
