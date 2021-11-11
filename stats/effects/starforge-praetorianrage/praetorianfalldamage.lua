function init()
  effect.addStatModifierGroup({{stat = "fallDamageMultiplier", effectiveMultiplier = 0.6}})
  animator.setParticleEmitterOffsetRegion("feathers", mcontroller.boundBox())
  animator.setParticleEmitterActive("feathers", false)
end
