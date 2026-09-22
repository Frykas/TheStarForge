function init()
  effect.setParentDirectives("?multiply=ffffff00")
  animator.setAnimationState("telegraph", "active")
  animator.setParticleEmitterOffsetRegion("teleport", mcontroller.boundBox())
  animator.setParticleEmitterActive("teleport", true)

  effect.addStatModifierGroup({{stat = "activeMovementAbilities", amount = 1}})
  effect.addStatModifierGroup({{stat = "invulnerable", amount = 1}})
  
  local timeToActivate = config.getParameter("timeToActivate", {effect.duration() * 0.75, effect.duration() * 1.25})
  local newTime = math.random() * (timeToActivate[2] - timeToActivate[1]) + timeToActivate[1]
  effect.modifyDuration(-effect.duration() + newTime)

  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  end

  effect.addStatModifierGroup({
      {stat = "arrested", amount = 1},
      {stat = "invulnerable", amount = 1},
      {stat = "fireStatusImmunity", amount = 1},
      {stat = "iceStatusImmunity", amount = 1},
      {stat = "electricStatusImmunity", amount = 1},
      {stat = "poisonStatusImmunity", amount = 1},
      {stat = "powerMultiplier", effectiveMultiplier = 0},
      {stat = "specialStatusImmunity", amount = 1}
    })
end

function update(dt)
  --Prevent the target from moving
  mcontroller.controlModifiers({
    facingSuppressed = true,
    movementSuppressed = true
  })
  
  if not status.resourcePositive("health") then
	  effect.expire()
  end
end

function onExpire()
  if status.isResource("stunned") then
	  status.setResource("stunned", 0)
  end
  for _, effect in ipairs(config.getParameter("appearEffects", { "starforge-teleporteffect" })) do
    status.addEphemeralEffect(effect)
  end
  animator.setParticleEmitterActive("teleport", false)
  effect.setParentDirectives("")
  animator.setAnimationState("telegraph", "inactive")
end

