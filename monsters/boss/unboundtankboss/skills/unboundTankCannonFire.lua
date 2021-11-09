unboundTankCannonFire = {}

function unboundTankCannonFire.enter()
  if not hasTarget() then return nil end
	
  rangedAttack.setConfig(config.getParameter("unboundTankCannonFire.projectileType"), config.getParameter("unboundTankCannonFire.projectileParameters"))
  
  self.targetingTime = config.getParameter("unboundTankCannonFire.targetingTime")
  self.fireDelay = config.getParameter("unboundTankCannonFire.fireDelay")
  self.rotationSpeed = 0
  
  self.rotatedMuzzle = {0, 0}
  self.newMuzzleOffset = {0, 0}
  self.toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(self.newMuzzleOffset)))

  return {
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
    self.targetingTime = math.max(0, self.targetingTime - dt)
	if self.targetingTime > 0 then
	  self.targetAngle = vec2.angle(vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(stateData.barrelOffset))))
	  if self.targetAngle > 0.6 and self.targetAngle < 5.8 then
		if self.targetAngle > 3.8 then
		  self.targetAngle = 5.8
		else
	   	  self.targetAngle = 0.6
	    end
	  end
	  self.aimAngle = unboundTankCannonFire.adjustAim(self.aimAngle or 0, self.targetAngle, dt, stateData)
	
	  self.rotatedMuzzle = vec2.rotate(stateData.barrelMuzzleOffset, -(self.aimAngle or 0) - math.pi)
	  self.newMuzzleOffset = vec2.add(stateData.barrelOffset, self.rotatedMuzzle)
	  self.toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(stateData.barrelOffset)))
	else
      self.fireDelay = math.max(0, self.fireDelay - dt)
	  if self.fireDelay == 0 then
	    unboundTankCannonFire.fireCannon(stateData, self.newMuzzleOffset, self.toTarget)
	  end
	end
  else
    return true
  end

  animator.resetTransformationGroup("barrel")
  animator.rotateTransformationGroup("barrel", self.aimAngle, stateData.barrelRotationCenter)

  return false
end

function unboundTankCannonFire.adjustAim(currentAngle, angleTo, dt, stateData)
  local angleDiff = util.angleDiff(currentAngle, angleTo)
  local diffSign = angleDiff > 0 and 1 or -1

  local targetSpeed = math.max(0.1, math.min(1, math.abs(angleDiff) / 0.5)) * stateData.controlRotation.maxSpeed
  local acceleration = diffSign * stateData.controlRotation.controlForce * dt
  self.rotationSpeed = math.max(-targetSpeed, math.min(targetSpeed, self.rotationSpeed + acceleration))
  self.rotationSpeed = self.rotationSpeed - self.rotationSpeed * stateData.controlRotation.friction * dt
  return currentAngle + self.rotationSpeed
end

function unboundTankCannonFire.fireCannon(stateData, offset, target)
  rangedAttack.aim(offset, target)
  rangedAttack.fireOnce()

  animator.setAnimationState("barrel", "fire")
  stateData.shots = stateData.shots - 1
  animator.playSound("fireCannon")
  self.rotationSpeed = 0

  if stateData.adjustAimAfterShot == true then
    self.targetingTime = stateData.targetingTime
  end
  self.fireDelay = stateData.fireDelay
end

function unboundTankCannonFire.leavingState(stateData)
  rangedAttack.stopFiring()
end
