unboundTankStop = {}

function unboundTankStop.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("unboundTankStop.skillDuration")
  }
end

function unboundTankStop.enteringState(stateData)
  monster.setActiveSkillName("unboundTankStop")
  animator.setParticleEmitterActive("smoking", true)
end

function unboundTankStop.update(dt, stateData)
  if not hasTarget() then return true end
  
  stateData.timer = math.max(0, stateData.timer - dt)
  
  mcontroller.setXVelocity(0)
  self.stopped = true
  
  if stateData.timer == 0 then
    status.removeEphemeralEffect("invulnerable")
    monster.setDamageOnTouch(false)
    animator.setParticleEmitterActive("smoking", false)
	self.stopped = false
    return true
  end
  return false
end

function unboundTankStop.leavingState(stateData)
end
