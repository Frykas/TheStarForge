function init()
  effect.addStatModifierGroup({
    {stat = "powerMultiplier", effectiveMultiplier = config.getParameter("powerModifier", 1.0)},
    {stat = "protection", effectiveMultiplier = config.getParameter("protection", 1.0)},
    {stat = "grit", effectiveMultiplier = config.getParameter("grit", 1.0)}
  })
end

function update(dt)
  
end

function uninit()

end
