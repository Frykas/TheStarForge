function init()
  animator.setAnimationState("blink", "blinkout")
  effect.setParentDirectives("?multiply=ffffff00")
  animator.playSound("activate")
  animator.setParticleEmitterOffsetRegion("teleport", mcontroller.boundBox())
  animator.burstParticleEmitter("teleport")
  effect.addStatModifierGroup({{stat = "activeMovementAbilities", amount = 1}})
  
  effect.addStatModifierGroup({{stat = "invulnerable", amount = 1}})
end

function update(dt)
  if effect.duration() < 0.25 and animator.animationState("blink") == "none" then
    teleport()
  end
end

function teleport()
  effect.setParentDirectives("")
  animator.playSound("deactivate")
  animator.burstParticleEmitter("teleport")
  animator.setAnimationState("blink", "blinkin")
end

function onExpire()
end
