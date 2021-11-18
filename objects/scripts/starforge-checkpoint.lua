require "/scripts/rect.lua"
require "/scripts/util.lua"

function init()
  self.queryArea = config.getParameter("queryArea")
  self.queryArea = rect.translate(self.queryArea, entity.position())

  self.spawnOffset = config.getParameter("spawnOffset", {0, 0})

  self.query = util.interval(config.getParameter("queryInterval", 1.0), function()
    local players = world.entityQuery(rect.ll(self.queryArea), rect.ur(self.queryArea), { includedTypes = { "player" } })
    if #players > 0 then
      activate()
    end
  end)

  animator.setAnimationState("checkpoint", storage.activated and "active" or "inactive")
  if not storage.activated then
    if not (config.getParameter("alwaysLit")) then object.setLightColor({0, 0, 0, 0}) end
    object.setSoundEffectEnabled(false)
  end
end

function activate()
  animator.setAnimationState("checkpoint", "activate")
  if not (config.getParameter("alwaysLit")) then object.setLightColor(config.getParameter("lightColor", {0, 0, 0, 0})) end
  object.setSoundEffectEnabled(true)
  world.setPlayerStart(vec2.add(entity.position(), self.spawnOffset), true)
  storage.activated = true
end

function update(dt)
  if not storage.activated then
    self.query(dt)
  end
end
