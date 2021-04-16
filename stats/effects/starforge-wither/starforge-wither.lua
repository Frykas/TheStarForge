function init()
  
  animator.setParticleEmitterOffsetRegion("decay", mcontroller.boundBox())
  animator.setParticleEmitterActive("decay", true)

  self.decayRate = config.getParameter("decayRate", 0.15)
  self.decayTimer = 0
  
  self.setDamageSourceKind = "direct"
  
  self.currentDamageIncrease = 0
  
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep

  script.setUpdateDelta(1)
  
  self.canMultiplyDamage = false
end

function update(dt)
  self.decayTimer = self.decayTimer + dt
  self.currentDamageIncrease = self.currentDamageIncrease + self.decayRate / (self.decayTimer + 1)
  
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  if self.canMultiplyDamage then
	for _, notification in ipairs(damageNotifications) do
	  if notification.healthLost > 1 and self.currentDamageIncrease > 0 and notification.damageSourceKind ~= self.setDamageSourceKind then
		local damageRequest = {}
		damageRequest.damageType = "IgnoresDef"
		damageRequest.damage = notification.damageDealt * self.currentDamageIncrease / 10
		damageRequest.damageSourceKind = self.setDamageSourceKind
		damageRequest.sourceEntityId = notification.sourceEntityId
		status.applySelfDamageRequest(damageRequest)
	  end
	end
  end
  
  effect.setParentDirectives(string.format(config.getParameter("directive", "fade=3B4235=%.1f"), math.min(0.5, self.decayTimer * 0.4)))
  animator.setParticleEmitterEmissionRate("decay", self.decayTimer * 10)
  
  world.debugText("Damage Increase = %s", self.currentDamageIncrease / 10, mcontroller.position(), "red")
  
  self.canMultiplyDamage = true
end

function uninit()
end