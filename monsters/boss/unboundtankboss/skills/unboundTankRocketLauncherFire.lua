unboundTankRocketLauncherFire = {}

function unboundTankRocketLauncherFire.enter()
  if not hasTarget() then return nil end
	
  rangedAttack.setConfig(config.getParameter("unboundTankRocketLauncherFire.projectileType"), config.getParameter("unboundTankRocketLauncherFire.projectileParameters"))
  
  self.fireDelay = 0
  self.rotationSpeed = 0
  self.shots = config.getParameter("unboundTankRocketLauncherFire.shots")
  
  self.rotatedMuzzle = {0, 0}
  self.newMuzzleOffset = {0, 0}
  self.toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(self.newMuzzleOffset)))

  return {
    basePosition = self.spawnPosition,
    fireDelay = config.getParameter("unboundTankRocketLauncherFire.fireDelay"),
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
  
  if self.shots > 0 then
	self.targetAngle = vec2.angle(vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(stateData.launcherOffset))))
	self.aimAngle = unboundTankRocketLauncherFire.adjustAim(self.aimAngle or 0, self.targetAngle, dt, stateData)
	if animator.animationState("rocketLauncher") == "loaded" or animator.animationState("rocketLauncher") == "fire" then
      self.fireDelay = math.max(0, self.fireDelay - dt)
	  if self.fireDelay == 0 then
	    unboundTankRocketLauncherFire.burstFire(stateData)
	  end
	end
  else
    return true
  end

  self.rotatedMuzzle = vec2.rotate(stateData.launcherMuzzles[math.min(stateData.shots, stateData.shots - self.shots + 1)], -(self.aimAngle or 0) - math.pi)
  self.newMuzzleOffset = vec2.add(stateData.launcherOffset, self.rotatedMuzzle)
  self.toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(stateData.launcherOffset)))

  animator.resetTransformationGroup("rocketlauncher")
  animator.rotateTransformationGroup("rocketlauncher", self.aimAngle, stateData.launcherRotationCenter)
  
  return false
end

function unboundTankRocketLauncherFire.burstFire(stateData)
  unboundTankRocketLauncherFire.fireLauncher(stateData, self.newMuzzleOffset, self.toTarget, self.shots)
  self.shots = self.shots - 1

  self.fireDelay = stateData.fireDelay
	
  if self.shots == 0 then
    animator.setAnimationState("rocketLauncher", "recover")
  end
end

function unboundTankRocketLauncherFire.adjustAim(currentAngle, angleTo, dt, stateData)
  local angleDiff = util.angleDiff(currentAngle, angleTo)
  local diffSign = angleDiff > 0 and 1 or -1

  local targetSpeed = math.max(0.1, math.min(1, math.abs(angleDiff) / 0.5)) * stateData.controlRotation.maxSpeed
  local acceleration = diffSign * stateData.controlRotation.controlForce * dt
  self.rotationSpeed = math.max(-targetSpeed, math.min(targetSpeed, self.rotationSpeed + acceleration))
  self.rotationSpeed = self.rotationSpeed - self.rotationSpeed * stateData.controlRotation.friction * dt
  return currentAngle + self.rotationSpeed
end

function unboundTankRocketLauncherFire.fireLauncher(stateData, offset, target, shot)
  rangedAttack.aim(offset, target)
  rangedAttack.fireOnce()

  animator.setGlobalTag("shotFrame", math.min(stateData.shots, stateData.shots - self.shots + 1))
  animator.setAnimationState("rocketLauncher", "fire")
  animator.playSound("fireLauncher")
  self.rotationSpeed = 0
  
  self.fireDelay = stateData.fireDelay
end

function unboundTankRocketLauncherFire.leavingState(stateData)
  rangedAttack.stopFiring()
end
