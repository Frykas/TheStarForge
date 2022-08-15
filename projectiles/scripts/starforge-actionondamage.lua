local baseHit = hit

function hit(entityId)
  if baseHit then baseHit(entityId) end
  
  for _, action in ipairs(config.getParameter("actionOnDamage", {})) do
    projectile.processAction(action)
  end
end

