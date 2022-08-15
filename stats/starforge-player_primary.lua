preStarforge_applyDamageRequest = applyDamageRequest

function applyDamageRequest(damageRequest)
  if preStarforge_applyDamageRequest then
    preStarforge_applyDamageRequest(damageRequest)
  end

  --Calculate damageResistance
  if status.resource("starforgeDamageResistance") then
    damageRequest.damage = damageRequest.damage * (status.resource("starforgeDamageResistance") - 1)
  end
end