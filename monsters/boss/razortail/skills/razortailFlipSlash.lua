razortailFlipSlash = {}

function razortailFlipSlash.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("razortailFlipSlash.windDownDuration", 0.7),

    teleportXOffset = config.getParameter("razortailFlipSlash.teleportXOffset", 10),
    windupTime = config.getParameter("razortailFlipSlash.windupTime", 0.2),

    rotations = config.getParameter("razortailFlipSlash.rotations", 3),
    rotationTime = config.getParameter("razortailFlipSlash.rotationTime", 0.4),

    lowJumpVelocity = config.getParameter("razortailFlipSlash.lowJumpVelocity", {75, 10}),
    highJumpVelocity = config.getParameter("razortailFlipSlash.highJumpVelocity", {35, 40}),
    highJumpHeight = config.getParameter("razortailFlipSlash.highJumpHeight", 4),
    jumpDuration = config.getParameter("razortailFlipSlash.jumpDuration", 0.2),

    damageConfig = config.getParameter("razortailFlipSlash.damageConfig")
  }
end

function razortailFlipSlash.enteringState(stateData)
  monster.setActiveSkillName("razortailFlipSlash")
  razortailFlipSlash.teleport(stateData)
  stateData.timer = stateData.timer * self.cooldownFactor
end

function razortailFlipSlash.update(dt, stateData)
  if stateData.timerActive then
    stateData.timer = math.max(0, stateData.timer - dt)
    
    if stateData.timer == 0 then
      return true
    end
  end
  return false
end

function razortailFlipSlash.teleport(stateData)
  directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  local teleportPosition = calculatePosition(self.targetPosition, {directionToPlayer * -stateData.teleportXOffset, 0}, true)

  if world.lineTileCollision(self.targetPosition, teleportPosition) then
    teleportPosition = calculatePosition(self.targetPosition, {directionToPlayer * stateData.teleportXOffset, 0}, true)
  end
  sanctusTeleport(
    teleportPosition,
    0,
    function()
      razortailFlipSlash.jump(stateData)
    end
  )
end

function razortailFlipSlash.jump(stateData)
  local directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  mcontroller.controlFace(-directionToPlayer)
  
  wait(
    stateData.windupTime * self.cooldownFactor,
    function(dt, timer)
      animator.setAnimationState("body", "flipslashWindup")
    end,
    function()
      animator.setAnimationState("body", "flipslash")
      stateData.flipTime = stateData.rotations * stateData.rotationTime

      local jumpVelocity = (self.targetPosition[2] - mcontroller.position()[2]) > stateData.highJumpHeight and stateData.highJumpVelocity or stateData.lowJumpVelocity
      wait(
        stateData.flipTime,
        function(dt, timer)
          if timer > (stateData.flipTime - stateData.jumpDuration) then
            mcontroller.setVelocity({jumpVelocity[1] * directionToPlayer, jumpVelocity[2]})
          else  
            if mcontroller.onGround() then
              return true
            end
          end

          animator.resetTransformationGroup("all")
          animator.rotateTransformationGroup("all", math.pi * 2 * (timer / stateData.rotationTime))

          local newConfig = sb.jsonMerge(stateData.damageConfig, {})
          newConfig.damage = scalePower(newConfig.damage)
          updateDamageSources(newConfig, true)
        end,
        function()
          updateDamageSources(nil)
          animator.resetTransformationGroup("all")
          animator.setAnimationState("body", "idle")
          stateData.timerActive = true
        end)
    end)
end

function razortailFlipSlash.leavingState(stateData)
end
