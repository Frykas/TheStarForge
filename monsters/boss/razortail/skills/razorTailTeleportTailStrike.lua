razortailTeleportTailStrike = {}

function razortailTeleportTailStrike.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("razortailTeleportTailStrike.winddownDuration", 0.5),
    projectileDelay = config.getParameter("razortailTeleportTailStrike.projectileDelay", 0.5),
    teleportXOffset = config.getParameter("razortailTeleportTailStrike.teleportXOffset", 7),
    tooCloseRange = config.getParameter("razortailTeleportTailStrike.tooCloseRange", 4),

    projectileType = config.getParameter("razortailTeleportTailStrike.projectileType", "standardBullet"),
    projectileConfig = config.getParameter("razortailTeleportTailStrike.projectileConfig", {}),
    projectileOffset = config.getParameter("razortailTeleportTailStrike.projectileOffset", {2, 0})
  }
end

function razortailTeleportTailStrike.enteringState(stateData)
  monster.setActiveSkillName("razortailTeleportTailStrike")
  razortailTeleportTailStrike.teleport(stateData)
end

function razortailTeleportTailStrike.update(dt, stateData) 
  if stateData.timerActive then
    stateData.timer = math.max(0, stateData.timer - dt)
    
    if stateData.timer == 0 then
      return true
    end
  end
  return false
end

function razortailTeleportTailStrike.teleport(stateData)
  local directionToPlayer = util.toDirection(world.distance(mcontroller.position(), self.targetPosition)[1])
  local teleportPosition = calculatePosition(self.targetPosition, {-directionToPlayer * stateData.teleportXOffset, 0})
  if world.magnitude(teleportPosition, mcontroller.position()) > stateData.tooCloseRange then
    sanctusTeleport(
      teleportPosition,
      0,
      function()
        razortailTeleportTailStrike.slashProjectile(stateData, directionToPlayer)
      end
    )
  else
    stateData.timer = 0
    stateData.timerActive = true
  end
end

function razortailTeleportTailStrike.slashProjectile(stateData, directionToPlayer)
  animator.setAnimationState("body", "tailStrike")
  wait(
    stateData.projectileDelay,
    function()
      mcontroller.setVelocity({0, 0})
    end,
    function()
      if animator.hasSound("tailStrike") then
        animator.playSound("tailStrike")
      end
      local projectileConfig = stateData.projectileConfig
      projectileConfig.power = scalePower(stateData.projectileConfig.power or 10)
      world.spawnProjectile(stateData.projectileType, vec2.add(mcontroller.position(), vec2.mul(stateData.projectileOffset, {directionToPlayer, 1})), entity.id(), {directionToPlayer, 0}, false, projectileConfig)
      stateData.timerActive = true
      mcontroller.setVelocity({-directionToPlayer * 15, 10})
      if not self.onGround then
        animator.setAnimationState("body", "falling")
      end
    end)
end

function razortailTeleportTailStrike.leavingState(stateData)
end
