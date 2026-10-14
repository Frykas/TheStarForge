--------------------------------------------------------------------------------
dieState = {}

function dieState.enterWith(params)
  if not params.die then return nil end

  return {
    timer = config.getParameter("razortailPhaseShift.skillTime", 0),

    projectileType = config.getParameter("razortailPhaseShift.projectileType", "roar"),
    projectileConfig = config.getParameter("razortailPhaseShift.projectileConfig", {}),
    roarPosition = config.getParameter("razortailPhaseShift.roarPosition", {0, 0})
  }
end

function dieState.enteringState(stateData)
  clearCoroutines()
end

function dieState.update(dt, stateData)
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
    if stateData.timer <= 0 then
      self.dead = true
      local deathMessage = config.getParameter("deathMessage")
      if deathMessage then
        local players = world.playerQuery(entity.position(), config.getParameter("trackTargetDistance"))
        for _, player in ipairs(players) do
          if entity.entityInSight(player) then
            world.sendEntityMessage(player, deathMessage)
          end
        end
      end
      dieState.burstChunks()
    end
  end
end

function dieState.burstChunks()
  local params = sb.jsonMerge(config.getParameter("deathProjectileConfig", {}), {})
  params.power = 0
  params.powerMultiplier = 0
  params.damageType = "noDamage"

  local count = config.getParameter("deathProjectileCount", 1)
  local interval = (math.pi * 2) / count

  fireProjectile(config.getParameter("deathProjectileType", "standardbullet"), config.getParameter("deathProjectileConfig", {}), count, mcontroller.position(), interval)
end
