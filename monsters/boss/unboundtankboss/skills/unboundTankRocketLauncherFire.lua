unboundTankRocketLauncherFire = {}

function unboundTankRocketLauncherFire.enter()
  if not hasTarget() then return nil end
	
  rangedAttack.setConfig(config.getParameter("unboundTankRocketLauncherFire.projectileType"), config.getParameter("unboundTankRocketLauncherFire.projectileParameters"))
  
  return {
    fireDelay = config.getParameter("unboundTankRocketLauncherFire.fireDelay") + 1,
    rotationSpeed = 0,
    rotatedMuzzle = {0, 0},
    newMuzzleOffset = {0, 0},
    toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition({0, 0}))),
    basePosition = self.spawnPosition,
    shots = config.getParameter("unboundTankRocketLauncherFire.shots"),
    adjustAimAfterShot = config.getParameter("unboundTankRocketLauncherFire.adjustAimAfterShot"),
    launcherMuzzles = config.getParameter("unboundTankRocketLauncherFire.launcherMuzzles"),
    launcherOffset = config.getParameter("unboundTankRocketLauncherFire.launcherOffset"),
    launcherRotationCenter = config.getParameter("unboundTankRocketLauncherFire.launcherRotationCenter"),
    controlRotation = config.getParameter("unboundTankRocketLauncherFire.controlRotation")
  }
end

function unboundTankRocketLauncherFire.enteringState(stateData)
  monster.setActiveSkillName("unboundTankRocketLauncherFire")
end

function unboundTankRocketLauncherFire.update(dt, stateData)
  if not hasTarget() then return true end
  
  if stateData.shots > 0 then
	stateData.targetAngle = vec2.angle(vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(stateData.launcherOffset))))
	stateData.aimAngle = unboundTankRocketLauncherFire.adjustAim(stateData.aimAngle or 0, stateData.targetAngle, dt, stateData)
	if animator.animationState("rocketLauncher") == "loaded" or animator.animationState("rocketLauncher") == "fire" then
      stateData.fireDelay = math.max(0, stateData.fireDelay - dt)
	  if stateData.fireDelay == 0 then
	    unboundTankRocketLauncherFire.burstFire(stateData)
	  end
	end
  else
    return true
  end

  stateData.rotatedMuzzle = vec2.rotate(stateData.launcherMuzzles[math.min(config.getParameter("unboundTankRocketLauncherFire.shots"), config.getParameter("unboundTankRocketLauncherFire.shots") - stateData.shots + 1)], -(stateData.aimAngle or 0) - math.pi)
  stateData.newMuzzleOffset = vec2.add(stateData.launcherOffset, stateData.rotatedMuzzle)
  stateData.toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(stateData.launcherOffset)))

  animator.resetTransformationGroup("rocketlauncher")
  animator.rotateTransformationGroup("rocketlauncher", stateData.aimAngle, stateData.launcherRotationCenter)
  
  return false
end

function unboundTankRocketLauncherFire.burstFire(stateData)
  unboundTankRocketLauncherFire.fireLauncher(stateData, stateData.newMuzzleOffset, stateData.toTarget, stateData.shots)
  stateData.shots = stateData.shots - 1

  stateData.fireDelay = config.getParameter("unboundTankRocketLauncherFire.fireDelay")
	
  if stateData.shots == 0 then
    animator.setAnimationState("rocketLauncher", "recover")
  end
end

function unboundTankRocketLauncherFire.adjustAim(currentAngle, angleTo, dt, stateData)
  local angleDiff = util.angleDiff(currentAngle, angleTo)
  local diffSign = angleDiff > 0 and 1 or -1

  local targetSpeed = math.max(0.1, math.min(1, math.abs(angleDiff) / 0.5)) * stateData.controlRotation.maxSpeed
  local acceleration = diffSign * stateData.controlRotation.controlForce * dt
  stateData.rotationSpeed = math.max(-targetSpeed, math.min(targetSpeed, stateData.rotationSpeed + acceleration))
  stateData.rotationSpeed = stateData.rotationSpeed - stateData.rotationSpeed * stateData.controlRotation.friction * dt
  return currentAngle + stateData.rotationSpeed
end

function unboundTankRocketLauncherFire.fireLauncher(stateData, offset, target, shot)
  rangedAttack.aim(offset, target)
  rangedAttack.fireOnce()

  animator.setGlobalTag("shotFrame", math.min(config.getParameter("unboundTankRocketLauncherFire.shots"), config.getParameter("unboundTankRocketLauncherFire.shots") - stateData.shots + 1))
  animator.setAnimationState("rocketLauncher", "fire")
  animator.playSound("fireLauncher")
  stateData.rotationSpeed = 0
  
  stateData.fireDelay = config.getParameter("unboundTankRocketLauncherFire.fireDelay")
end

function unboundTankRocketLauncherFire.leavingState(stateData)
  animator.setAnimationState("rocketLauncher", "loaded")
  rangedAttack.stopFiring()
end

