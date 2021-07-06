function init()
  animator.setAnimationState("blink", "blinkout")
  effect.setParentDirectives("?multiply=ffffff00")
  animator.playSound("activate")
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
  animator.burstParticleEmitter("translocate")
  animator.setAnimationState("blink", "blinkin")
end

function onExpire()
end
