function init()
  self.adaptiveFactor = 0
  self.adaptiveDecayRate = config.getParameter("adaptiveDecayRate", 0.08)
  self.adaptiveFactorPerHit = config.getParameter("adaptiveFactorPerHit", 0.1)
  self.adaptiveProtectionModifier = config.getParameter("adaptiveProtectionModifier", 1.6) - 1--Gives a 1.6x multiplier to protection when adaptiveFactor is at 1

  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep

  self.statModifier = effect.addStatModifierGroup({
    {stat = "protection", effectiveMultiplier = 1 + (self.adaptiveProtectionModifier * self.adaptiveFactor)}
  })
end

function update(dt)
  --Update our adaptive resistance
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  for _, notification in ipairs(damageNotifications) do
	if notification.healthLost > 1 then
	  self.adaptiveFactor = math.min(1, self.adaptiveFactor + self.adaptiveFactorPerHit)
	end
  end
  
  self.adaptiveFactor = math.max(0, self.adaptiveFactor - (self.adaptiveDecayRate * dt))
  
  --Apply the protection
  effect.setStatModifierGroup(self.statModifier, {
    {stat = "protection", effectiveMultiplier = 1 + (self.adaptiveProtectionModifier * self.adaptiveFactor)}
  })
  
  world.debugText("protection %s", status.stat("protection"), mcontroller.position(), "blue")
end