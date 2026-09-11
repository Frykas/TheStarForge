function init()
  self.modifierId = effect.addStatModifierGroup({{stat = "starforge-tidalfrostStatusImmunity", amount = 1}})
end

function uninit()
  effect.removeStatModifierGroup(self.modifierId)
end