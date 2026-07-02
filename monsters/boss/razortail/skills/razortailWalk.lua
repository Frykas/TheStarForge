razortailWalk = {}

function razortailWalk.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("razortailWalk.skillDuration"),
    walkSpeed = config.getParameter("razortailWalk.walkSpeed", 10),
    targetDistance = config.getParameter("razortailWalk.targetDistance", 10)
  }
end

function razortailWalk.enteringState(stateData)
  monster.setActiveSkillName("razortailWalk")
  stateData.timer = stateData.timer * self.cooldownFactor
end

function razortailWalk.update(dt, stateData)  
  stateData.timer = math.max(0, stateData.timer - dt)
  
  if self.targetPosition and self.onGround then
    local dist = world.distance(mcontroller.position(), self.targetPosition)
    local direction = util.toDirection(dist[1])
    if vec2.mag(dist) < stateData.targetDistance then
      return razortailWalk.endState()
    end
    mcontroller.controlFace(direction)
    mcontroller.setXVelocity(stateData.walkSpeed * -direction)
    if not stateData.animationPlayed then
      animator.setAnimationState("body", "walk")
      stateData.animationPlayed = true
    end
  end

  if stateData.timer == 0 then
    return razortailWalk.endState()
  end
  return false
end

function razortailWalk.endState()
  mcontroller.setXVelocity(0)
  animator.setAnimationState("body", "idle")
  return true
end

function razortailWalk.leavingState(stateData)
end
