function init()
  effect.addStatModifierGroup({{stat = "fallDamageMultiplier", effectiveMultiplier = config.getParameter("durationIsMultiplier") and effect.duration() or config.getParameter("fallDamageMultiplier")}})
end

function update(dt)

end

function uninit()

end
