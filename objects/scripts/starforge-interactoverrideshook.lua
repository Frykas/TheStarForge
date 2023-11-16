starforge_oldInit = init or function() end
function init() starforge_oldInit()
  object.setInteractive(config.getParameter("interactData"))
end

--Thanks to Silver for the versatile workaround!
starforge_oldInteraction = onInteraction or function() end
function onInteraction(args) starforge_oldInteraction(args)
  return {config.getParameter("interactAction", "ScriptPane"), sb.jsonMerge(root.assetJson(config.getParameter("interactData")), config.getParameter("interactOverrides", {}))}
end