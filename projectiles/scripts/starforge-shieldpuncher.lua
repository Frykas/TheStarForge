local baseHit = hit

function hit(entityId)
  if baseHit then baseHit(entityId) end
  
  world.sendEntityMessage(entityId, "applyStatusEffect", config.getParameter("effectOverwrite", "starforge-shieldbreaker"), projectile.power() * 0.2, projectile.sourceEntity() or entity.id())
end

