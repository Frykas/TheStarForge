razortailTeleportDropStrike = {}

function razortailTeleportDropStrike.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("razortailTeleportDropStrike.winddownDuration", 0.5),

    jumpTime = config.getParameter("razortailTeleportDropStrike.jumpTime", 0.25),
    teleportOffset = config.getParameter("razortailTeleportDropStrike.teleportOffset", {-2, 25}),
    tooCloseRange = config.getParameter("razortailTeleportDropStrike.tooCloseRange", 4),

    landingDelay = config.getParameter("razortailTeleportDropStrike.landingDelay", 0.65),
    leapVelocity = config.getParameter("razortailTeleportDropStrike.leapVelocity", {125, 55}),
    leapDuration = config.getParameter("razortailTeleportDropStrike.leapDuration", 1),
    xRaycastLength = config.getParameter("razortailTeleportDropStrike.xRaycastLength", 10),

    fallTime = config.getParameter("razortailTeleportDropStrike.fallTime", 2),
    teleportXOffset = config.getParameter("razortailTeleportDropStrike.teleportXOffset", 5), 
    projectileType = config.getParameter("razortailTeleportDropStrike.projectileType", "standardBullet"),
    projectileConfig = config.getParameter("razortailTeleportDropStrike.projectileConfig", {}),
    projectileOffset = config.getParameter("razortailTeleportDropStrike.projectileOffset", {2, 0})
  }
end

function razortailTeleportDropStrike.enteringState(stateData)
  monster.setActiveSkillName("razortailTeleportDropStrike")
  razortailTeleportDropStrike.jump(stateData)
  stateData.timer = calculateCooldown(stateData.timer)
end

function razortailTeleportDropStrike.update(dt, stateData) 
  if stateData.timerActive then
    stateData.timer = math.max(0, stateData.timer - dt)
    
    if stateData.timer == 0 then
      return true
    end
  end
  return false
end

function razortailTeleportDropStrike.jump(stateData)
  mcontroller.setVelocity({0, 35})
  wait(
    calculateCooldown(stateData.jumpTime),
    nil,
    function()
      razortailTeleportDropStrike.teleport(stateData)
    end
  )
end

function razortailTeleportDropStrike.teleport(stateData)
  local directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  local teleportPosition = calculatePosition(self.targetPosition, {directionToPlayer * stateData.teleportOffset[1], stateData.teleportOffset[2]})
  if world.magnitude(teleportPosition, mcontroller.position()) > stateData.tooCloseRange then
    sanctusTeleport(
      teleportPosition,
      0,
      function()
        wait(
          0.1,
          nil,
          function()
            razortailTeleportDropStrike.flipslash(stateData, directionToPlayer)
          end
        )
      end
    )
  else
    stateData.timer = 0
    stateData.timerActive = true
  end
end

function razortailTeleportDropStrike.flipslash(stateData, directionToPlayer)
  animator.setAnimationState("body", "flipslash")
  wait(
    stateData.fallTime,
    function()
      mcontroller.setVelocity({directionToPlayer * 5, -125})
      if mcontroller.onGround() then
        return true
      end
    end,
    function()
      animator.setAnimationState("body", "idle")
      razortailTeleportDropStrike.explode(stateData, {0, 1})
      razortailTeleportDropStrike.leap(stateData, directionToPlayer)
    end)
end

function razortailTeleportDropStrike.leap(stateData, directionToPlayer)
  wait(
    calculateCooldown(stateData.landingDelay),
    nil,
    function()
      animator.setAnimationState("body", "jumping")
      mcontroller.setVelocity({stateData.leapVelocity[1] * directionToPlayer, stateData.leapVelocity[2]})
      wait(
        stateData.leapDuration,
        function()
          local collided = world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), {directionToPlayer * stateData.xRaycastLength, 0}))
          return collided
        end,
        function()
          razortailTeleportDropStrike.explode(stateData, {-mcontroller.xVelocity(), 0})
          razortailTeleportDropStrike.teleportBesidePlayer(stateData, directionToPlayer)
        end
      )
    end)
end

function razortailTeleportDropStrike.teleportBesidePlayer(stateData)
  local directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  local teleportPosition = calculatePosition(self.targetPosition, {-directionToPlayer * stateData.teleportXOffset, 0})
    sanctusTeleport(
      teleportPosition,
      0,
      function()
        stateData.timer = 0
        stateData.timerActive = true
      end
    )
end

function razortailTeleportDropStrike.explode(stateData, vector)
  local projectileConfig = stateData.projectileConfig
  projectileConfig.power = scalePower(stateData.projectileConfig.power or 10)
  world.spawnProjectile(stateData.projectileType, vec2.add(mcontroller.position(), stateData.projectileOffset), entity.id(), vector or {0, 1}, false, projectileConfig)
end

function razortailTeleportDropStrike.leavingState(stateData)
end
