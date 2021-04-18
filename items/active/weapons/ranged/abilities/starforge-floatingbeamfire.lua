require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

StarForgeFloatingBeamFire = WeaponAbility:new()

function StarForgeFloatingBeamFire:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  self.impactSoundTimer = 0
  self.hoverTimer = 0

  self.chainAnimationTimer = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setDamage()
    activeItem.setScriptedAnimationParameter("chains", {})
    animator.setParticleEmitterActive("beamCollision", false)
    animator.stopAllSounds("fireLoop")
    self.weapon:setStance(self.stances.idle)
  end
end

function StarForgeFloatingBeamFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.impactSoundTimer = math.max(self.impactSoundTimer - self.dt, 0)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self:setState(self.fire)
  end
  
  self:updateTransformationGroup()
end

function StarForgeFloatingBeamFire:fire()
  self.weapon:setStance(self.stances.fire)

  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)

  local wasColliding = false
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
    local beamStart = self:firePosition()
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
    local beamLength = self.beamLength
	
	activeItem.emote(self.fireEmote)
	
    animator.setGlobalTag("firingDirectives", self.firingDirectives)

    local collidePoint = world.lineCollision(beamStart, beamEnd)
    if collidePoint then
      beamEnd = collidePoint

      beamLength = world.magnitude(beamStart, beamEnd)

      animator.setParticleEmitterActive("beamCollision", true)
      animator.resetTransformationGroup("beamEnd")
      animator.translateTransformationGroup("beamEnd", {beamLength, 0})

      if self.impactSoundTimer == 0 then
        animator.setSoundPosition("beamImpact", {beamLength, 0})
        animator.playSound("beamImpact")
        self.impactSoundTimer = self.fireTime
      end
    else
      animator.setParticleEmitterActive("beamCollision", false)
    end

	local damageStart = vec2.add(self.currentCrystalOffset, self.weapon.muzzleOffset)
	local damageEnd = vec2.add(beamEnd, vec2.mul(mcontroller.position(), -1))
	damageEnd[1] = damageEnd[1] * mcontroller.facingDirection()
	
	--Box collision type (uses beamWidth)
	if self.beamCollisionType == "box" then
	  local damagePoly = {
		vec2.add(damageStart, {0, self.beamWidth/2}),
		vec2.add(damageStart, {0, -self.beamWidth/2}),
		{damageEnd[1] + beamLength, damageEnd[2] - self.beamWidth/2},
		{damageEnd[1] + beamLength, damageEnd[2] + self.beamWidth/2}
	  }
	  self.weapon:setDamage(self.damageConfig, damagePoly, self.fireTime)
	
	--Taper collision type (uses beamWidth, tapers to a point)
	elseif self.beamCollisionType == "taper" then
	  local damagePoly = {
		vec2.add(damageStart, {0, self.beamWidth/2}),
		vec2.add(damageStart, {0, -self.beamWidth/2}),
		damageEnd
	  }
	  self.weapon:setDamage(self.damageConfig, damagePoly, self.fireTime)
	
	--Line collision type (default)
	elseif self.beamCollisionType == "line" or not self.beamCollisionType then
	  self.weapon:setDamage(self.damageConfig, {damageStart, damageEnd}, self.fireTime)
	end
	
    self:drawBeam(beamEnd, collidePoint)

    coroutine.yield()
  end
  
  animator.setGlobalTag("firingDirectives", "")

  self:reset()
  animator.playSound("fireEnd")

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function StarForgeFloatingBeamFire:updateTransformationGroup()
  self.hoverTimer = self.hoverTimer + self.dt
  local yOffset = self.hoverAmplitude * math.sin(self.hoverTimer / (self.hoverCycle / (2 * math.pi)))
  self.currentCrystalOffset = vec2.add(self.crystalPosition, {0, yOffset})

  animator.resetTransformationGroup("crystal")
  animator.translateTransformationGroup("crystal", self.currentCrystalOffset)
end

function StarForgeFloatingBeamFire:drawBeam(endPos, didCollide)
  local newChain = copy(self.chain)
  newChain.startOffset = vec2.add(self.currentCrystalOffset, self.weapon.muzzleOffset)
  newChain.endPosition = endPos
  
  --Optionally animate the chain beam
  if self.animatedChain then
	self.chainAnimationTimer = math.min(self.chainAnimationTime, self.chainAnimationTimer + self.dt)
	if self.chainAnimationTimer == self.chainAnimationTime then
	  self.chainAnimationTimer = 0
	end
	
	local chainAnimationFrame = 1
	chainAnimationFrame = math.floor(self.chainAnimationTimer / self.chainAnimationTime * self.chainAnimationFrames)
	
	newChain.startSegmentImage = self.chain.startSegmentImage .. ":" .. chainAnimationFrame
	newChain.segmentImage = self.chain.segmentImage .. ":" .. chainAnimationFrame
	newChain.endSegmentImage = self.chain.endSegmentImage .. ":" .. chainAnimationFrame
  end
  
  if didCollide then
    newChain.endSegmentImage = nil
  end

  activeItem.setScriptedAnimationParameter("chains", {newChain})
end

function StarForgeFloatingBeamFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  util.wait(self.stances.cooldown.duration, function()

  end)
end

function StarForgeFloatingBeamFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(vec2.add(self.currentCrystalOffset, self.weapon.muzzleOffset)))
end

function StarForgeFloatingBeamFire:aimVector(inaccuracy)
  local aimAngle, aimDirection = activeItem.aimAngleAndDirection(activeItem.handPosition(vec2.add(self.currentCrystalOffset, self.weapon.muzzleOffset))[2], activeItem.ownerAimPosition())
  
  local aimVector = vec2.rotate({1, 0}, aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function StarForgeFloatingBeamFire:uninit()
  self:reset()
end

function StarForgeFloatingBeamFire:reset()
  self.weapon:setDamage()
  activeItem.setScriptedAnimationParameter("chains", {})
  animator.setParticleEmitterActive("beamCollision", false)
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
end
