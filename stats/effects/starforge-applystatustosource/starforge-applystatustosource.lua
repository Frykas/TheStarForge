function init()
  self.statusEffects = config.getParameter("statusEffects", {})
end

function update(dt)
  local sourceEntity = effect.sourceEntity()
  if world.entityExists(sourceEntity) then
    for _, fx in ipairs(self.statusEffects) do
	  world.sendEntityMessage(sourceEntity, "applyStatusEffect", fx, config.getParameter("statusDurationOverwrite", effect.duration()), sourceEntity)
    end
    effect.expire()
  end
end