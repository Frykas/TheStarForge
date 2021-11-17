unboundTankCharge = {}

function unboundTankCharge.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("unboundTankCharge.skillDuration"),
    speedMultiplier = config.getParameter("unboundTankCharge.speedMultiplier")
  }
end

function unboundTankCharge.enteringState(stateData)
  status.addEphemeralEffect("invulnerable", config.getParameter("unboundTankCharge.skillDuration"))
  monster.setDamageOnTouch(true)
  monster.setActiveSkillName("unboundTankCharge")
  animator.setParticleEmitterActive("smoking", true)
end

function unboundTankCharge.update(dt, stateData)
  if not hasTarget() then return true end
  
  stateData.timer = math.max(0, stateData.timer - dt)
  
  mcontroller.setXVelocity(mcontroller.xVelocity() * stateData.speedMultiplier)
  
  if stateData.timer == 0 then
    status.removeEphemeralEffect("invulnerable")
    monster.setDamageOnTouch(false)
    animator.setParticleEmitterActive("smoking", false)
    return true
  end
  return false
end

function unboundTankCharge.leavingState(stateData)
  status.removeEphemeralEffect("invulnerable")
  monster.setDamageOnTouch(false)
end
