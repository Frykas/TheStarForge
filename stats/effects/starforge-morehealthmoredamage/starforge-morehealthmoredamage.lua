function init()  
  self.damageFactor = config.getParameter("damageFactor", 1)

  script.setUpdateDelta(1)
end

function update(dt)
  --Listen for damage taken
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  --Multiply damage
  for _, notification in ipairs(damageNotifications) do
	if notification.healthLost > 1 and not self.damageMultiplied then
	  --Calculate Damage
	  local healthFactor = status.resource("health") / status.resourceMax("health")
	  local damageTaken = notification.damageDealt * self.damageFactor * healthFactor
  
	  local damageRequest = {}
	  damageRequest.damageType = "IgnoresDef"
	  damageRequest.damage = damageTaken
	  damageRequest.damageSourceKind = notification.damageSourceKind
	  damageRequest.sourceEntityId = notification.sourceEntityId
	  --Apply damage
	  status.applySelfDamageRequest(damageRequest)
		
	  --Kill the effect
	  sb.logInfo("Effect expired with %s damage taken!", damageTaken)
	  self.damageMultiplied = true
	  effect.expire()
	end
  end
end
