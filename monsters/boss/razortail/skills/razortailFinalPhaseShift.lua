razortailFinalPhaseShift = {}

function razortailFinalPhaseShift.enterWith(args)
  if not args or not args.enteringPhase then return nil end

  return {
    timer = config.getParameter("razortailFinalPhaseShift.skillTime", 1),
    roarWindupTime = config.getParameter("razortailFinalPhaseShift.roarWindupTime", 0.4),

    initialVelocity = config.getParameter("razortailFinalPhaseShift.initialVelocity", {-5, 100}),
    jumpTime = config.getParameter("razortailFinalPhaseShift.jumpTime", 0.4),

    diveVelocity = config.getParameter("razortailFinalPhaseShift.diveVelocity", {0, -75}),
    diveTime = config.getParameter("razortailFinalPhaseShift.diveTime", 4),

    diveProjectileType = config.getParameter("razortailFinalPhaseShift.diveProjectileType", "standardBullet"),
    diveProjectileConfig = config.getParameter("razortailFinalPhaseShift.diveProjectileConfig", {}),
    diveProjectileOffset = config.getParameter("razortailFinalPhaseShift.diveProjectileOffset", {2, 0}),

    leapVelocity = config.getParameter("razortailFinalPhaseShift.leapVelocity", {5, 75}),

    geyserProjectileType = config.getParameter("razortailFinalPhaseShift.geyserProjectileType", 0.4),
    geyserProjectileConfig = config.getParameter("razortailFinalPhaseShift.geyserProjectileConfig", 0.4),
    geyserProjectileOffset = config.getParameter("razortailFinalPhaseShift.geyserProjectileOffset", {2, 0}),
    
    swimTime = config.getParameter("razortailFinalPhaseShift.swimTime", 4.5),
    swimOvershootDistance = config.getParameter("razortailFinalPhaseShift.swimOvershootDistance", 8),
    moveDir = 1,

    projectileType = config.getParameter("razortailFinalPhaseShift.projectileType", "roar"),
    projectileConfig = config.getParameter("razortailFinalPhaseShift.projectileConfig", {}),
    roarPosition = config.getParameter("razortailFinalPhaseShift.roarPosition", {0, 0}),

    bodyDirectives = config.getParameter("razortailFinalPhaseShift.bodyDirectives", "")
  }
end

function razortailFinalPhaseShift.enteringState(stateData)
  clearCoroutines()
  animator.resetTransformationGroup("all")
  animator.setAnimationState("body", "idle")
  status.addPersistentEffect("starforge-razortailPhaseShift", "maxprotection")
  razortailFinalPhaseShift.readyDive(stateData)
end

function razortailFinalPhaseShift.update(dt, stateData)
  if stateData.roarPlayed then
    stateData.timer = stateData.timer - dt
    mcontroller.controlApproachVelocity({0, 0}, 100)
    if stateData.timer <= 0 then
      status.clearPersistentEffects("starforge-razortailPhaseShift")
      return true
    end
  end
end

function razortailFinalPhaseShift.readyDive(stateData)
  mcontroller.setVelocity(stateData.initialVelocity)
  wait(
    stateData.jumpTime,
    nil,
    function()
      razortailFinalPhaseShift.dive(stateData)
    end)
end

function razortailFinalPhaseShift.dive(stateData)
  animator.setAnimationState("body", "flipslash")
  mcontroller.setVelocity(stateData.diveVelocity)
  wait(
    stateData.diveTime,
    function()
      if mcontroller.onGround() then
        return true
      end
    end,
    function()
      playSound("slam")
      animator.setAnimationState("body", "invisible")
      razortailFinalPhaseShift.explode(stateData, {0, 1})
      razortailFinalPhaseShift.swim(stateData)
    end)
end

function razortailFinalPhaseShift.swim(stateData)
  status.addPersistentEffect("starforge-razortailSwimming", "invulnerable")
  animator.setParticleEmitterActive("swimming", true)
  updateDamageSources(nil, true)
  wait(
    stateData.swimTime,
    function()
      local dx = self.targetPosition[1] - mcontroller.position()[1]

      if stateData.moveDir == 1 and dx < -stateData.swimOvershootDistance then
        stateData.moveDir = -1
      elseif stateData.moveDir == -1 and dx > stateData.swimOvershootDistance then
        stateData.moveDir = 1
      end

      local maxSpeed = 25
      local targetVx = stateData.moveDir * maxSpeed

      mcontroller.setXVelocity(targetVx, 150)
    end,
    function()
      animator.setParticleEmitterActive("swimming", false)
      razortailFinalPhaseShift.geyser(stateData, {0, 1})
      razortailFinalPhaseShift.leaveSwim(stateData)
    end)
end

function razortailFinalPhaseShift.leaveSwim(stateData)
  local directionToPlayer = util.toDirection(world.distance(mcontroller.position(), self.targetPosition)[1])
  animator.setAnimationState("body", "idle")
  updateDamageSources()
  status.clearPersistentEffects("starforge-razortailSwimming")
  mcontroller.setVelocity(stateData.leapVelocity)
  playSound("erupt")
  wait(
    stateData.jumpTime,
    function()
      mcontroller.controlFace(directionToPlayer)
    end,
    function()
      razortailFinalPhaseShift.roar(stateData)
    end)
end

function razortailFinalPhaseShift.roar(stateData)
  animator.setAnimationState("body", "roar")
  wait(
    stateData.roarWindupTime,
    function()
      mcontroller.controlApproachVelocity({0, 0}, 155)
    end,
    function()
      playSound("roar")
      
      local projectileConfig = stateData.projectileConfig
      projectileConfig.power = scalePower(stateData.projectileConfig.power or 10)
      world.spawnProjectile(stateData.projectileType, vec2.add(mcontroller.position(), {stateData.roarPosition[1] * -mcontroller.facingDirection(), stateData.roarPosition[2]}), entity.id(), {mcontroller.facingDirection(), 0}, true, projectileConfig)
      
      stateData.roarPlayed = true
      animator.setGlobalTag("bodyDirectives", stateData.bodyDirectives)
    end)
end

function razortailFinalPhaseShift.explode(stateData, vector)
  local projectileConfig = stateData.diveProjectileConfig
  projectileConfig.power = scalePower(stateData.diveProjectileConfig.power or 10)
  world.spawnProjectile(stateData.diveProjectileType, vec2.add(mcontroller.position(), stateData.diveProjectileOffset), entity.id(), vector or {0, 1}, false, projectileConfig)
end

function razortailFinalPhaseShift.geyser(stateData, vector)
  local projectileConfig = stateData.geyserProjectileConfig
  projectileConfig.power = scalePower(stateData.geyserProjectileConfig.power or 10)
  world.spawnProjectile(stateData.geyserProjectileType, vec2.add(mcontroller.position(), stateData.geyserProjectileOffset), entity.id(), vector or {0, 1}, false, projectileConfig)
end

function razortailFinalPhaseShift.leavingState(stateData)
  stateData.roarPlayed = false
end
