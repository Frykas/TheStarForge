function init()
  local damage = effect.duration()
  
  status.applySelfDamageRequest({
    damageType = "IgnoresDef",
    damage = damage,
    damageSourceKind = config.getParameter("damageSourceKind", "default"),
    sourceEntityId = effect.sourceEntity()
  })
  effect.expire()
end