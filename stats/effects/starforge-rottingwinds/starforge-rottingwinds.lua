function init()
  animator.setParticleEmitterOffsetRegion("decay", mcontroller.boundBox())
  animator.setParticleEmitterActive("decay", true)
  
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "starforge-witherdust", 5.0)

  self.statModifier = effect.addStatModifierGroup({
    {stat = "protection", effectiveMultiplier = 1},
  })
  
  self.timeToDrain = status.stat("protection") * config.getParameter("protectionModifier", 0.35)

  self.decayTimer = 0

  self.tickDamagePercentage = config.getParameter("tickDamagePercentage", 0.075)
  self.tickTime = config.getParameter("tickTime", 1)
  self.tickTimer = self.tickTime
  
  script.setUpdateDelta(1)
end

function update(dt)
  local decay = math.max(0, (1 - self.decayTimer / self.timeToDrain))

  effect.setStatModifierGroup(self.statModifier, {
    {stat = "protection", effectiveMultiplier = decay},
  })

  self.decayTimer = self.decayTimer + dt  
  if decay == 0 then
    self.tickTimer = self.tickTimer - dt  
    if self.tickTimer <= 0 then
      local tickDamage = math.min(math.floor(status.resourceMax("health") * self.tickDamagePercentage) + 1, 20)
    
      self.tickTimer = self.tickTime
      status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = tickDamage,
        damageSourceKind = "starforge-wither",
        sourceEntityId = entity.id()
      })
    end
  end

  animator.setParticleEmitterEmissionRate("decay", world.windLevel(mcontroller.position()) or 0)
  
  world.debugText("Current decay: %s = %s / %s", decay, self.decayTimer, self.timeToDrain, mcontroller.position(), "red")
end

function uninit()
  effect.removeStatModifierGroup(self.statModifier)
end