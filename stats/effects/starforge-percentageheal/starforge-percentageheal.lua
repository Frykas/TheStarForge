function init()
  animator.setParticleEmitterOffsetRegion("healing", mcontroller.boundBox())
  animator.setParticleEmitterEmissionRate("healing", 10)
  animator.setParticleEmitterActive("healing", true)

  script.setUpdateDelta(5)
  refresh(effect.duration())
end

function update(dt)
  if effect.duration() > self.trueDuration then
    refresh(effect.duration())
  end
  if status.resource("health") > 1 then
    status.modifyResourcePercentage("health", self.healingRate * dt)
  end
end

function refresh(inputDuration)
  self.trueDuration = math.floor(inputDuration) / 100
  effect.modifyDuration(self.trueDuration - inputDuration)
  self.healingRate = inputDuration - math.floor(inputDuration)
  if self.healingRate == 0 then
    self.healingRate = 1
  end
end

function uninit()
  
end
