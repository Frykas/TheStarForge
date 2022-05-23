function init()
  local elementalType = config.getParameter("elementalType", "tidalfrost") .. "Resistance"

  local primaryElementalInfluence = config.getParameter("primaryElementalInfluence", "electrical")
  local secondaryElementalInfluence = config.getParameter("secondaryElementalInfluence", "physical")
  local dualElementFactor = config.getParameter("dualElementFactor", 0.5)
  
  local primaryElementFactor = config.getParameter("primaryElementFactor", 0.05)
  local secondaryElementFactor = config.getParameter("secondaryElementFactor", -0.1)
  
  local elementA = status.stat(primaryElementalInfluence .. "Resistance")
  local elementB = status.stat(secondaryElementalInfluence .. "Resistance")

  local resistance = ((elementA + elementB) * dualElementFactor) + (primaryElementFactor * elementA) + (secondaryElementFactor * elementB)
  effect.addStatModifierGroup({{stat = elementalType, amount = resistance}})

  script.setUpdateDelta(0)
end