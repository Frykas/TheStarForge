function init()
  self.baseTime = effect.duration()
  status.addPersistentEffect("nebsbasement", "invulnerable")
end

function update(dt)
  mcontroller.setVelocity({0, 0})
  effect.setParentDirectives(string.format("scale=%f;%f", (effect.duration()) / self.baseTime, (effect.duration()) / self.baseTime))
end

function onExpire()
  mcontroller.setPosition({0, 0})
  status.modifyResource("health", -status.resourceMax("health") * 1000)
end