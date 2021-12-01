--Huge thanks to C0bra5 for making this framework

if not c5ModuleLoader then
  c5ModuleLoader = {
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
  function c5ModuleLoader.register(module, name)
    module.name = name or module.name
    module.failed = false
    table.insert(c5ModuleLoader.modules, module)
  end
  
  function containerCallback(...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "preContainerCallback", ...)
    end
    
    if c5ModuleLoader.overrides.init then
      c5ModuleLoader.overrides.containerCallback(...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "containerCallback", ...)
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "postContainerCallback", ...)
    end
  end
  
  function die(...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "preDie", ...)
    end
    
    if c5ModuleLoader.overrides.init then
      c5ModuleLoader.overrides.die(...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "die", ...)
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "postDie", ...)
    end
  end
  
  function init(...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "prePreInit", ...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "preInit", ...)
    end
    
    if c5ModuleLoader.overrides.init then
      c5ModuleLoader.overrides.init(...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "init", ...)
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "postInit", ...)
    end
  end
  
  function activate(...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "preActivate", ...)
    end
    
    if c5ModuleLoader.overrides.activate then
      c5ModuleLoader.overrides.activate(...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "activate", ...)
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "postActivate", ...)
    end
  end
  
  function update(...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "preUpdate", ...)
    end
    
    if c5ModuleLoader.overrides.update then
      c5ModuleLoader.overrides.update(...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "update", ...)
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "postUpdate", ...)
    end
  end
  
  function hit(...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "preHit", ...)
    end
    
    if c5ModuleLoader.overrides.hit then
      c5ModuleLoader.overrides.hit(...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "hit", ...)
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "postHit", ...)
    end
  end
  
  function uninit(...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "preUninit", ...)
    end
    
    if c5ModuleLoader.overrides.uninit then
      c5ModuleLoader.overrides.uninit(...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "uninit", ...)
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "postUninit", ...)
    end
  end
  
  function onInteraction(...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "preUpdate", ...)
    end
    
    if c5ModuleLoader.overrides.onInteraction then
      c5ModuleLoader.overrides.onInteraction(...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "update", ...)
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      c5ModuleLoader.doCall(module, "postUpdate", ...)
    end
  end
  
  function build(directory, config, parameters, ...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      config, parameters = c5ModuleLoader.doCallWithReturn(module, "preBuild", {sb.jsonMerge({}, config), sb.jsonMerge({}, parameters)}, directory, config, parameters, ...)
    end
    
    if c5ModuleLoader.overrides.build then
      config, parameters = c5ModuleLoader.overrides.build(directory, config, parameters, ...)
    end
    
    for _, module in ipairs(c5ModuleLoader.modules) do
      config, parameters = c5ModuleLoader.doCallWithReturn(module, "build", {sb.jsonMerge({}, config), sb.jsonMerge({}, parameters)}, directory, config, parameters, ...)
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      config, parameters = c5ModuleLoader.doCallWithReturn(module, "postBuild", {sb.jsonMerge({}, config), sb.jsonMerge({}, parameters)}, directory, config, parameters, ...)
    end

    return config, parameters
  end

  function apply(input, ...)
    for _, module in ipairs(c5ModuleLoader.modules) do
      local result = c5ModuleLoader.doCallWithReturn(module, "preApply", {sb.jsonMerge({}, input)}, input, ...)
      if result ~= nil then
        input = result
      end
    end

    if c5ModuleLoader.overrides.build then
      local result = c5ModuleLoader.overrides.apply(input, ...)
      if result ~= nil then
        input = result
      end
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      local result = c5ModuleLoader.doCallWithReturn(module, "apply", {sb.jsonMerge({}, input)}, input, ...)
      if result ~= nil then
        input = result
      end
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      local result = c5ModuleLoader.doCallWithReturn(module, "postApply", {sb.jsonMerge({}, input)}, input, ...)
      if result ~= nil then
        input = result
      end
    end

    return input
  end
  
  function createTooltip(...)
    local output = nil

    for _, module in ipairs(c5ModuleLoader.modules) do
      local result = c5ModuleLoader.doCallWithReturn(module, "preApply", {nil}, ...)
      if result ~= nil then
        output = (output or "") .. result
      end
    end

    if c5ModuleLoader.overrides.build then
      local result = c5ModuleLoader.overrides.apply(input, ...)
      if result ~= nil then
        output = (output or "") .. result
      end
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      local result = c5ModuleLoader.doCallWithReturn(module, "apply", {nil}, ...)
      if result ~= nil then
        output = (output or "") .. result
      end
    end

    for _, module in ipairs(c5ModuleLoader.modules) do
      local result = c5ModuleLoader.doCallWithReturn(module, "postApply", {nil}, ...)
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
  function c5ModuleLoader.doCall(module, funcName, ...)
    if not module[funcName] then
      return
    end
    -- skip the pcalls if the project is in debug mode.
    if c5ModuleLoader.debug then
      module[funcName](...)
    elseif not module.failed then
      local success, err = pcall(module[funcName], ...)
      if not success then
        module.failed = true
        pcall(module["onError"], err)
        sb.logInfo("[c5ModuleLoader.doCall] A runtime error occured while executing a module's \"%s\"'s function. The error will follow.")
        sb.logInfo("%s", err)
      end
    end
  end
  
  -- PCalls a function of a given module and returns it's returned value.
  -- param: module - SFModule - The module in which the module resides.
  -- param: funcName - String - The name of the function to be called.
  -- param: errorDefault - Array - An array of values (because multiple return is a thing) which are retured when the module function errors out.
  -- return: any or multiple any - depends on what the function returns
  function c5ModuleLoader.doCallWithReturn(module, funcName, errorDefault, ...)
    if not module[funcName] then
      return table.unpack(errorDefault)
    end
    -- skip the pcalls if the project is in debug mode.
    if c5ModuleLoader.debug then
      return module[funcName](...)
    elseif not module.failed then
      local returnValues = table.pack(pcall(module[funcName], ...))
      if not returnValues[1] then
        module.failed = true
        pcall(module["onError"], err)
        sb.logInfo("[c5ModuleLoader.doCallWithReturn] A runtime error occured while executing a module's \"%s\"'s function. The error will follow.")
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
