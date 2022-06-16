function init()
  local elementalType = config.getParameter("elementalType", "tidalfrost") .. "Resistance"

  local elementalInfluences = config.getParameter("elementalInfluences", {})
  local totalFactor = config.getParameter("totalFactor", 0.5)

  local resistance = 0
  local averageFactor = 0
  local totalRes = 0
  for element, influence in pairs(elementalInfluences) do
	local elementRes = status.stat(element .. "Resistance")
	averageFactor = averageFactor + 1
	totalRes = totalRes + elementRes
	resistance = resistance + elementRes * influence
  end
  local newInfluence = (totalRes / averageFactor) * totalFactor
  
  local finalResistance = resistance + newInfluence
  effect.addStatModifierGroup({{stat = elementalType, amount = finalResistance}})

  script.setUpdateDelta(0)
end