function init()
  script.setUpdateDelta(5)

  self.healingRate = 1.0 / config.getParameter("healTime", 60)
  self.regenRate = 1.0 / config.getParameter("energyRegenTime", 60)
  effect.addStatModifierGroup({{stat = "powerMultiplier", effectiveMultiplier = config.getParameter("powerMultiplier", 1)}})
end

function update(dt)
  status.modifyResourcePercentage("health", self.healingRate * dt)
  status.modifyResourcePercentage("energy", self.regenRate * dt)
end

function uninit()
  
end
