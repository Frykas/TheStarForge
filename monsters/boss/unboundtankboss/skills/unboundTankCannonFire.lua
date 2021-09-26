unboundTankCannonFire = {}

function unboundTankCannonFire.enter()
  if not hasTarget() then return nil end
	
  rangedAttack.setConfig(config.getParameter("unboundTankCannonFire.projectileType"), config.getParameter("unboundTankCannonFire.projectileParameters"))
  
  self.targetingTime = config.getParameter("unboundTankCannonFire.targetingTime")
  self.fireDelay = config.getParameter("unboundTankCannonFire.fireDelay")
  self.aimAngle = 0
	  
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
    rotationBounds = config.getParameter("unboundTankCannonFire.rotationBounds")
  }
end

function unboundTankCannonFire.enteringState(stateData)
  monster.setActiveSkillName("unboundTankCannonFire")
end

function unboundTankCannonFire.update(dt, stateData)
  if not hasTarget() then return true end
	
  animator.resetTransformationGroup("barrel")
  animator.rotateTransformationGroup("barrel", self.aimAngle)
  
  if stateData.shots > 0 then
    self.targetingTime = math.max(0, self.targetingTime - dt)
	if self.targetingTime > 0 then
	  self.aimAngle = vec2.angle(vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(self.newMuzzleOffset))))
	
	  self.rotatedMuzzle = vec2.rotate(stateData.barrelMuzzleOffset, self.aimAngle - math.pi)
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

  return false
end

function unboundTankCannonFire.fireCannon(stateData, offset, target)
  rangedAttack.aim(offset, target)
  rangedAttack.fireOnce()

  animator.setAnimationState("barrel", "fire")
  stateData.shots = stateData.shots - 1
  animator.playSound("fireCannon")

  if stateData.adjustAimAfterShot == true then
    self.targetingTime = stateData.targetingTime
  end
  self.fireDelay = stateData.fireDelay
end

function unboundTankCannonFire.leavingState(stateData)
  rangedAttack.stopFiring()
end
