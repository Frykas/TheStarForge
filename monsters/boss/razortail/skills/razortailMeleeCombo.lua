razortailMeleeCombo = {}

function razortailMeleeCombo.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("razortailMeleeCombo.windDownDuration", 1),

    teleportXOffset = config.getParameter("razortailTeleportTailStrike.teleportXOffset", 7),

    attackSequence = config.getParameter("razortailMeleeCombo.attackSequence", {"clawSlash", "tailWhip", "bite"}),
    randomSequence = config.getParameter("razortailMeleeCombo.randomSequence", false),
    sequenceStep = 1,
    attackDuration = config.getParameter("razortailMeleeCombo.sequenceBreackDistance", 1),
    attackMovement = config.getParameter("razortailMeleeCombo.attackMovement", 1),
    sequenceBreackDistance = config.getParameter("razortailMeleeCombo.sequenceBreackDistance", {15, 9})
  }
end

function razortailMeleeCombo.enteringState(stateData)
  monster.setActiveSkillName("razortailMeleeCombo")
  razortailMeleeCombo.teleport(stateData)
end

function razortailMeleeCombo.update(dt, stateData)
  if stateData.timerActive then
    stateData.timer = math.max(0, stateData.timer - dt)
    
    if stateData.timer == 0 then
      return true
    end
  end
  return false
end

function razortailMeleeCombo.teleport(stateData)
  local directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  local teleportPosition = calculatePosition(self.targetPosition, {-directionToPlayer * stateData.teleportXOffset, 0})

  if razortailMeleeCombo.comboValid(stateData) then
    razortailMeleeCombo.attack(stateData)
  else
    sanctusTeleport(
      teleportPosition,
      0,
      function()
        razortailMeleeCombo.attack(stateData)
      end
    )
  end
end

function razortailMeleeCombo.attack(stateData)
  local directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  mcontroller.controlFace(directionToPlayer)

  local animation = stateData.attackSequence[stateData.randomSequence and math.random(#stateData.attackSequence) or stateData.sequenceStep]
  animator.setAnimationState("body", animation)
  mcontroller.setVelocity({directionToPlayer * stateData.attackMovement, 0})

  wait(
    stateData.attackDuration,
    function()
      if not mcontroller.onGround() then
        mcontroller.controlApproachVelocity({0, 0}, 500)
      end
    end,
    function()
      stateData.sequenceStep = stateData.sequenceStep + 1
      if razortailMeleeCombo.comboValid(stateData) then
        razortailMeleeCombo.attack(stateData)
      else
        stateData.timer = 0
        stateData.timerActive = true
      end
    end)
end

function razortailMeleeCombo.comboValid(stateData)
  local valid = true

  local dist = world.distance(self.targetPosition, mcontroller.position())
  if (stateData.sequenceStep > #stateData.attackSequence) or 
     (math.abs(dist[1]) < stateData.sequenceBreackDistance[1]) or 
     (math.abs(dist[2]) < stateData.sequenceBreackDistance[2]) then

    valid = false
  end

  return valid
end

function razortailMeleeCombo.leavingState(stateData)
end
