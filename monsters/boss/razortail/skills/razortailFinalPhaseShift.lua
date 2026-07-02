razortailFinalPhaseShift = {}

function razortailFinalPhaseShift.enterWith(args)
  if not args or not args.enteringPhase then return nil end

  return {
    timer = config.getParameter("razortailFinalPhaseShift.skillTime", 1),

    projectileType = config.getParameter("razortailFinalPhaseShift.projectileType", "roar"),
    projectileConfig = config.getParameter("razortailFinalPhaseShift.projectileConfig", {}),
    roarPosition = config.getParameter("razortailFinalPhaseShift.roarPosition", {0, 0}),

    bodyDirectives = config.getParameter("razortailFinalPhaseShift.bodyDirectives", "")
  }
end

function razortailFinalPhaseShift.enteringState(stateData)
end

function razortailFinalPhaseShift.update(dt, stateData)
  if animator.animationState("body") ~= "roar" and animator.animationState("body") ~= "roarHold" and not stateData.roarPlayed then
    animator.setAnimationState("body", "roar")
  end
  if animator.animationState("body") == "roarHold" and not stateData.roarPlayed then
    playSound("roar")
    
    local projectileConfig = stateData.projectileConfig
    projectileConfig.power = scalePower(stateData.projectileConfig.power or 10)
    world.spawnProjectile(stateData.projectileType, vec2.add(mcontroller.position(), {stateData.roarPosition[1] * -mcontroller.facingDirection(), stateData.roarPosition[2]}), entity.id(), {mcontroller.facingDirection(), 0}, true, projectileConfig)
    
    stateData.roarPlayed = true
    animator.setGlobalTag("bodyDirectives", stateData.bodyDirectives)
  end

  if stateData.roarPlayed then
    stateData.timer = stateData.timer - dt
  end

  if stateData.timer <= 0 then
    stateData.roarPlayed = false
    return true
  end
end

function razortailFinalPhaseShift.leavingState(stateData)
  stateData.roarPlayed = false
end
