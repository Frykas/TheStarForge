unboundTankCannonFire = {}

function unboundTankCannonFire.enter()
  if not hasTarget() then return nil end
	
  rangedAttack.setConfig(config.getParameter("unboundTankCannonFire.projectileType"), config.getParameter("unboundTankCannonFire.projectileParameters"))

  return {
    targetingTime = config.getParameter("unboundTankCannonFire.targetingTime"),
    rotationSpeed = 0,
    rotatedMuzzle = {0, 0},
    newMuzzleOffset = {0, 0},
    toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition({0, 0}))),
    basePosition = self.spawnPosition,
    targetingTime = config.getParameter("unboundTankCannonFire.targetingTime"),
    fireDelay = config.getParameter("unboundTankCannonFire.fireDelay"),
    shots = config.getParameter("unboundTankCannonFire.shots"),
    adjustAimAfterShot = config.getParameter("unboundTankCannonFire.adjustAimAfterShot"),
    barrelMuzzleOffset = config.getParameter("unboundTankCannonFire.barrelMuzzleOffset"),
    barrelOffset = config.getParameter("unboundTankCannonFire.barrelOffset"),
    barrelRotationCenter = config.getParameter("unboundTankCannonFire.barrelRotationCenter"),
    controlRotation = config.getParameter("unboundTankCannonFire.controlRotation")
  }
end

function unboundTankCannonFire.enteringState(stateData)
  monster.setActiveSkillName("unboundTankCannonFire")
end

function unboundTankCannonFire.update(dt, stateData)
  if not hasTarget() then return true end
  
  if stateData.shots > 0 then
    stateData.targetingTime = math.max(0, stateData.targetingTime - dt)
	if stateData.targetingTime > 0 then
	  stateData.targetAngle = vec2.angle(vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(stateData.barrelOffset))))
	  if stateData.targetAngle > 0.6 and stateData.targetAngle < 5.8 then
		if stateData.targetAngle > 3.8 then
		  stateData.targetAngle = 5.8
		else
	   	  stateData.targetAngle = 0.6
	    end
	  end
	  stateData.aimAngle = unboundTankCannonFire.adjustAim(stateData.aimAngle or 0, stateData.targetAngle, dt, stateData)
	
	  stateData.rotatedMuzzle = vec2.rotate(stateData.barrelMuzzleOffset, -(stateData.aimAngle or 0) - math.pi)
	  stateData.newMuzzleOffset = vec2.add(stateData.barrelOffset, stateData.rotatedMuzzle)
	  stateData.toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(stateData.barrelOffset)))
	else
      stateData.fireDelay = math.max(0, stateData.fireDelay - dt)
	  if stateData.fireDelay == 0 then
	    unboundTankCannonFire.fireCannon(stateData, stateData.newMuzzleOffset, stateData.toTarget)
	  end
	end
  else
    return true
  end

  animator.resetTransformationGroup("barrel")
  animator.rotateTransformationGroup("barrel", stateData.aimAngle, stateData.barrelRotationCenter)

  return false
end

function unboundTankCannonFire.adjustAim(currentAngle, angleTo, dt, stateData)
  local angleDiff = util.angleDiff(currentAngle, angleTo)
  local diffSign = angleDiff > 0 and 1 or -1

  local targetSpeed = math.max(0.1, math.min(1, math.abs(angleDiff) / 0.5)) * stateData.controlRotation.maxSpeed
  local acceleration = diffSign * stateData.controlRotation.controlForce * dt
  stateData.rotationSpeed = math.max(-targetSpeed, math.min(targetSpeed, stateData.rotationSpeed + acceleration))
  stateData.rotationSpeed = stateData.rotationSpeed - stateData.rotationSpeed * stateData.controlRotation.friction * dt
  return currentAngle + stateData.rotationSpeed
end

function unboundTankCannonFire.fireCannon(stateData, offset, target)
  rangedAttack.aim(offset, target)
  rangedAttack.fireOnce()

  animator.setAnimationState("barrel", "fire")
  stateData.shots = stateData.shots - 1
  animator.playSound("fireCannon")
  stateData.rotationSpeed = 0

  if stateData.adjustAimAfterShot == true then
    unboundTankRocketLauncherFire.targetingTime = stateData.targetingTime
  end
  unboundTankRocketLauncherFire.fireDelay = config.getParameter("unboundTankCannonFire.fireDelay")
end

function unboundTankCannonFire.leavingState(stateData)  
  rangedAttack.stopFiring()
end
