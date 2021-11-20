function update(dt)
  status.applySelfDamageRequest({
    damageType = "IgnoresDef",
    damage = status.resourceMax("health") * 1000,
    damageSourceKind = "hidden",
    sourceEntityId = entity.id()
  })
end
