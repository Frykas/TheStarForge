function init()
  effect.addStatModifierGroup({
    {stat = "protection", amount = config.getParameter("protectionAmount", 10)}, --Adds the specified value to protection stat
    {stat = "protection", effectiveMultiplier = config.getParameter("protectionModifier", 2.0)} --Multiplies protection stat by the specified value
  })
  
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)

  self.healingRate = 1.0 / config.getParameter("healTime", 60)
  
  script.setUpdateDelta(5)
end

function update(dt)
  status.modifyResourcePercentage("health", self.healingRate * dt)
  
  effect.setParentDirectives(config.getParameter("directives", ""))
  
  world.debugText(status.stat("protection"), mcontroller.position(), "blue")
end

function uninit()
  
end
