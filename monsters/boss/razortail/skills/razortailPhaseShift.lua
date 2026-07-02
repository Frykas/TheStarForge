razortailPhaseShift = {}

function razortailPhaseShift.enterWith(args)
  if not args or not args.enteringPhase then return nil end

  return {
    timer = config.getParameter("razortailPhaseShift.skillTime", 1),

    projectileType = config.getParameter("razortailPhaseShift.projectileType", "roar"),
    projectileConfig = config.getParameter("razortailPhaseShift.projectileConfig", {}),
    roarPosition = config.getParameter("razortailPhaseShift.roarPosition", {0, 0})
  }
end

function razortailPhaseShift.enteringState(stateData)
end

function razortailPhaseShift.update(dt, stateData)
  if animator.animationState("body") ~= "roar" and animator.animationState("body") ~= "roarHold" and not stateData.roarPlayed then
    animator.setAnimationState("body", "roar")
  end
  if animator.animationState("body") == "roarHold" and not stateData.roarPlayed then
    playSound("roar")
    
    local projectileConfig = stateData.projectileConfig
    projectileConfig.power = scalePower(stateData.projectileConfig.power or 10)
    world.spawnProjectile(stateData.projectileType, vec2.add(mcontroller.position(), {stateData.roarPosition[1] * -mcontroller.facingDirection(), stateData.roarPosition[2]}), entity.id(), {mcontroller.facingDirection(), 0}, true, projectileConfig)
    
    stateData.roarPlayed = true
  end

  if stateData.roarPlayed then
    stateData.timer = stateData.timer - dt
  end

  if stateData.timer <= 0 then
    return true
  end
end

function razortailPhaseShift.leavingState(stateData)
end
