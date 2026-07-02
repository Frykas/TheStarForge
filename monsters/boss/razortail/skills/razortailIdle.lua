razortailIdle = {}

function razortailIdle.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("razortailIdle.skillDuration")
  }
end

function razortailIdle.enteringState(stateData)
  --monster.setActiveSkillName("razortailIdle")
  stateData.timer = stateData.timer * self.cooldownFactor
end

function razortailIdle.update(dt, stateData)  
  stateData.timer = math.max(0, stateData.timer - dt)
  
  if stateData.timer == 0 then
    return true
  end
  return false
end

function razortailIdle.leavingState(stateData)
end
