unboundTankWave = {}

function unboundTankWave.enter()
  if not hasTarget() then return nil end
	
  return {
    preDelay = config.getParameter("unboundTankWave.preDelay", 0),
	postDelay = config.getParameter("unboundTankWave.postDelay", 0),
	hasFired = false,
    projectileType = config.getParameter("unboundTankWave.projectileType"),
    projectileParameters = config.getParameter("unboundTankWave.projectileParameters")
  }
end

function unboundTankWave.enteringState(stateData)
  monster.setActiveSkillName("unboundTankWave")
end

function unboundTankWave.update(dt, stateData)
  if not hasTarget() then return true end
  stateData.preDelay = math.max(0, stateData.preDelay - dt)
  
  if not stateData.hasFired and stateData.preDelay == 0 then
    unboundTankWave.spawnWave(stateData)
	stateData.hasFired = true
  end
  
  if stateData.hasFired then
	stateData.postDelay = math.max(0, stateData.postDelay - dt)
  end

  return (stateData.postDelay == 0 and stateData.hasFired)
end

function unboundTankWave.spawnWave(stateData)
  animator.playSound("fireWave")
  world.spawnProjectile(stateData.projectileType, vec2.add(mcontroller.position(), {0, -4}), entity.id(), {1, 0}, false, stateData.projectileParameters)
end

function unboundTankWave.leavingState(stateData)
end
