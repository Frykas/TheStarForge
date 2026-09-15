local baseHit = hit

function hit(entityId)
  if baseHit then baseHit(entityId) end
  
  local damage = math.ceil(projectile.power() * projectile.powerMultiplier())
  local effectiveness = config.getParameter("shieldPunchEffectiveness", 0.2)
  local intEffectiveness = math.floor(effectiveness * 1000 + 0.5)

  world.sendEntityMessage(entityId, "applyStatusEffect", config.getParameter("effectOverwrite", "starforge-shieldbreaker"), (damage * 10000) + intEffectiveness, projectile.sourceEntity())
end