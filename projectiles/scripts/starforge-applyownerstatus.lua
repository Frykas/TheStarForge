function init()
  self.statusEffects = config.getParameter("ownerStatusEffects", {})
end

function update(dt)
  if projectile.sourceEntity() then
    for _, statusEffect in pairs(self.statusEffects) do
      world.sendEntityMessage(projectile.sourceEntity(), "applyStatusEffect", statusEffect)
    end
	projectile.die()
  end
end