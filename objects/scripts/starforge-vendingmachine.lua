require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  if not storage.seed then
    storage.seed = getSeed()
  end
  self.guiConfig = config.getParameter("guiConfig")
  object.setInteractive(true)
end

function onInteraction(args)
  self.guiConfig.seed = storage.seed
  
  --TODO Reroll seed every 30 mins
  if (storage.lastTime + (config.getParameter("resetInterval", 30) * 60)) < os.time() then
    storage.seed = getSeed()
  end

  return {"ScriptPane", self.guiConfig}
end

function getSeed()
  math.randomseed(util.seedTime())
  storage.lastTime = os.time()
  return math.random(1, 4294967295)
end