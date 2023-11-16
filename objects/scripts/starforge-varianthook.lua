variantHookInit = init or function() end
function init() variantHookInit()
  storage.variant = storage.variant or math.random(1, config.getParameter("variants", 2))

  animator.setGlobalTag("variant", storage.variant)
end