razortailDashExplosions = {}

function razortailDashExplosions.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("razortailDashExplosions.windDownDuration", 0.5),

    dashWindup = config.getParameter("razortailDashExplosions.dashWindup", 0.3),

    xCast = config.getParameter("razortailDashExplosions.xCast", 7),
    dashSpeed = config.getParameter("razortailDashExplosions.dashSpeed", 100),
    dashTime = config.getParameter("razortailDashExplosions.dashTime", 0.4),

    projectileType = config.getParameter("razortailDashExplosions.projectileType", "standardbullet"),
    projectileConfig = config.getParameter("razortailDashExplosions.projectileConfig", {}),
    projectileInterval = config.getParameter("razortailDashExplosions.projectileInterval", 0.1),
    projectileOffset = config.getParameter("razortailDashExplosions.projectileOffset", {0, 0}),

    damageConfig = config.getParameter("razortailDashExplosions.damageConfig")
  }
end

function razortailDashExplosions.enteringState(stateData)
  monster.setActiveSkillName("razortailDashExplosions")
  razortailDashExplosions.windup(stateData)
  stateData.timer = calculateCooldown(stateData.timer)
end

function razortailDashExplosions.update(dt, stateData)
  if stateData.timerActive then
    stateData.timer = math.max(0, stateData.timer - dt)
    
    if stateData.timer == 0 then
      return true
    end
  end
  return false
end

function razortailDashExplosions.windup(stateData)
  local directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  mcontroller.controlFace(-directionToPlayer)

  animator.setAnimationState("body", "dashWindup")

  wait(
    stateData.dashWindup,
    function(dt, timer)
      if timer > (stateData.dashWindup * 0.25) and not stateData.sparked then
        animator.burstParticleEmitter("eyeSparkDash")
        playSound("eyeSpark")
        stateData.sparked = true
      end
    end,
    function()
      razortailDashExplosions.dash(stateData)
    end)
end

function razortailDashExplosions.dash(stateData)
  local directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  mcontroller.controlFace(-directionToPlayer)

  animator.setAnimationState("body", "dash")

  local projectileTimer = stateData.projectileInterval
  local projectileConfig = stateData.projectileConfig
  projectileConfig.power = scalePower(stateData.projectileConfig.power or 10)
  wait(
    stateData.dashTime,
    function(dt, timer)
      mcontroller.setVelocity({directionToPlayer * stateData.dashSpeed, 0})
      if world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), {stateData.xCast * directionToPlayer, 0})) then
        return true
      end

      projectileTimer = projectileTimer - dt
      if projectileTimer <= 0 then
        projectileTimer = stateData.projectileInterval
        world.spawnProjectile(stateData.projectileType, vec2.add(mcontroller.position(), stateData.projectileOffset), entity.id(), {directionToPlayer, 0}, false, projectileConfig)
      end

      local newConfig = sb.jsonMerge(stateData.damageConfig, {})
      newConfig.damage = scalePower(newConfig.damage)
      updateDamageSources(newConfig, true)
    end,
    function()
      updateDamageSources(nil)
      animator.setAnimationState("body", "idle")
      stateData.timerActive = true
    end)
end

function razortailDashExplosions.leavingState(stateData)
end
