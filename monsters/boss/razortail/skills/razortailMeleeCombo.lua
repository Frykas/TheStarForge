razortailMeleeCombo = {}

function razortailMeleeCombo.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("razortailMeleeCombo.windDownDuration", 0.5),

    teleportXOffset = config.getParameter("razortailTeleportTailStrike.teleportXOffset", 4),

    attackSequence = config.getParameter("razortailMeleeCombo.attackSequence", {"clawSlash", "tailWhip", "bite"}),
    randomSequence = config.getParameter("razortailMeleeCombo.randomSequence", false),
    sequenceStep = 1,
    attackDuration = config.getParameter("razortailMeleeCombo.sequenceBreackDistance", 0.5),
    attackMovement = config.getParameter("razortailMeleeCombo.attackMovement", 85),
    movementDelay = config.getParameter("razortailMeleeCombo.movementDelay", 0.4),
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

function razortailMeleeCombo.teleport(stateData, flipped)
  local directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  local teleportPosition = calculatePosition(self.targetPosition, {-directionToPlayer * (flipped and 1 or -1) * stateData.teleportXOffset, 0})

  if world.lineTileCollision(self.targetPosition, teleportPosition) then
    stateData.timerActive = true
    stateData.timer = 0
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
  mcontroller.controlFace(-directionToPlayer)

  local animation = stateData.attackSequence[stateData.randomSequence and math.random(#stateData.attackSequence) or stateData.sequenceStep]
  animator.setAnimationState("body", animation)

  stateData.momentumApplied = false
  wait(
    stateData.attackDuration,
    function(dt, timer)
      if not stateData.momentumApplied and timer > stateData.movementDelay then
        mcontroller.addMomentum({directionToPlayer * stateData.attackMovement, 0})
        stateData.momentumApplied = true
      end
      
      if not mcontroller.onGround() then
        mcontroller.addMomentum({directionToPlayer * stateData.attackMovement * 0.01, 0})
      end
      mcontroller.controlApproachXVelocity(0, 255)
    end,
    function()
      stateData.sequenceStep = stateData.sequenceStep + 1
      if razortailMeleeCombo.comboValid(stateData) then
        razortailMeleeCombo.teleport(stateData, stateData.sequenceStep % 2 == 0)
      else
        stateData.timerActive = true
      end
    end)
end

function razortailMeleeCombo.comboValid(stateData)
  local valid = true

  local dist = world.distance(self.targetPosition, mcontroller.position())
  if (stateData.sequenceStep > #stateData.attackSequence) then

    valid = false
  end

  return valid
end

function razortailMeleeCombo.leavingState(stateData)
end
