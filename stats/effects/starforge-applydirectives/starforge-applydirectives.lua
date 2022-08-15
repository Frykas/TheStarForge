function init()
  effect.setParentDirectives(config.getParameter("directive"))
end

function uninit()
  effect.setParentDirectives()
end