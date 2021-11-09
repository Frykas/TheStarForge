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
  self.aimAngle = math.atan(self:firePosition()[2] - activeItem.ownerAimPosition()[2], self:firePosition()[1] - activeItem.ownerAimPosition()[1])
end

function StarForgeFloatingBeamFire:fire()
  self.weapon:setStance(self.stances.fire)

  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)
  animator.setLightActive("firingPulse", true)
  animator.setAnimationState("firing", "fire")

  local wasColliding = false
  local chargeTimer = 0
  local beamFireTimer = self.fireTime / 2
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
    local beamStart = self:firePosition()
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
    local beamLength = self.beamLength
	
	if chargeTimer == self.chargeTime then
      animator.setParticleEmitterActive("muzzleFlash", true)
	  animator.playSound("chargePing")
	else
	  chargeTimer = math.min(self.chargeTime, chargeTimer + self.dt)
	end
	
	beamFireTimer = math.max(0, beamFireTimer - self.dt)
	
	activeItem.emote(self.fireEmote)
	
    animator.setGlobalTag("firingDirectives", self.firingDirectives)
	
	local damageStart = vec2.add(self.currentCrystalOffset, self.weapon.muzzleOffset)
    local collidePoint = world.lineCollision(beamStart, beamEnd)
	
	if self.laserPiercing == false then
	  local targets = world.entityLineQuery(beamStart, beamEnd, {
		withoutEntityId = activeItem.ownerEntityId(),
		includedTypes = {"creature"},
		order = "nearest"
	  })
	  --Set the default distance to nearest target to max search distance
	  local nearestTargetDistance = beamLength
	  for _, target in ipairs(targets) do
		--Make sure we can damage the targeted entity
		if world.entityCanDamage(activeItem.ownerEntityId(), target) then
		  local targetPosition = world.entityPosition(target)
		  --Make sure we have line of sight on this entity
		  if not world.lineCollision(beamStart, targetPosition) then
			local targetDistance = world.magnitude(beamStart, targetPosition)
			--If the target currently being processed is closer than the nearest target found so far, make this target the nearest target
			if targetDistance < nearestTargetDistance then
			  nearestTargetDistance = targetDistance
			  local beamVector = vec2.mul(self:aimVector(0), nearestTargetDistance)
			  collidePoint = vec2.add(beamStart, beamVector)
			  beamIsColliding = true
			end
		  end
		end
	  end
	end
	
    if collidePoint then
      beamEnd = collidePoint

      beamLength = world.magnitude(beamStart, beamEnd)
	  
	  local translateEndPoint = vec2.add(vec2.add(beamEnd, vec2.mul(mcontroller.position(), -1)), vec2.mul({self.crystalPosition[1], 0}, {mcontroller.facingDirection(), 0}))
	  translateEndPoint[1] = translateEndPoint[1] * mcontroller.facingDirection()

      animator.setParticleEmitterActive("beamCollision", true)
      animator.resetTransformationGroup("beamEnd")
      animator.translateTransformationGroup("beamEnd", translateEndPoint)

      if self.impactSoundTimer == 0 then
        animator.setSoundPosition("beamImpact", translateEndPoint)
        animator.playSound("beamImpact")
        self.impactSoundTimer = self.fireTime
      end
    else
      animator.setParticleEmitterActive("beamCollision", false)
    end
	
	local damageEnd = vec2.add(beamEnd, vec2.mul(mcontroller.position(), -1))
	damageEnd[1] = damageEnd[1] * mcontroller.facingDirection()
	
	--if beamFireTimer == 0 then
	--  local randomX = math.random() * (damageEnd[1] - damageStart[1]) + damageStart[1]
	--  --local randomY = math.random() * (damageEnd[2] - damageStart[2]) + damageStart[2]
	--  
	--  local offset = math.sqrt(((damageEnd[1] - damageStart[1]) ^ 2) + ((damageEnd[2] - damageStart[2]) ^ 2)) + 0.75
	--  local gradient = (damageEnd[2] - damageStart[2]) / (damageEnd[1] - damageStart[1])
	--  
	--  --local finalX = gradient * randomY + offset
	--  local finalY = gradient * randomX + offset - 10
	--  local randomPoint = vec2.add({randomX, finalY}, mcontroller.position())
	--  
	--  world.debugText("Current Point: %s, Debug Point: %s", mcontroller.position(), randomPoint, vec2.add(mcontroller.position(), {0,2}), "yellow")
	--  
    --  self:fireProjectile(self.beamProjectileType, self.beamProjectileParameters, 0.015, randomPoint, 1, self.fireTime / 2, self.baseDps)
	--  
	--  beamFireTimer = self.fireTime / 2
	--end
	
	self.weapon:setDamage(self.damageConfig, {damageStart, damageEnd}, self.fireTime)
	
    self:drawBeam(beamEnd, didCollide)

    coroutine.yield()
  end
  
  if chargeTimer == self.chargeTime then
    self:fireProjectile(self.projectileType, self.projectileParameters, 0, vec2.add(mcontroller.position(), activeItem.handPosition(self.currentCrystalOffset)), self.projectileCount, self.chargeTime, self.baseDps * self.projectileCount * self.chargeTime, true)
  end
  
  animator.setParticleEmitterActive("muzzleFlash", false)
  animator.setAnimationState("firing", "off")
  animator.setLightActive("firingPulse", false)
  animator.setGlobalTag("firingDirectives", "")

  self:reset()
  animator.playSound("fireEnd")

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function StarForgeFloatingBeamFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount, fireTime, projectileDps, randomAngle)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot(fireTime, projectileCount, projectileDps)
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)
  
  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end
	
	local aimAngle = self:aimVector(inaccuracy or self.inaccuracy)
	if randomAngle then
	  aimAngle = self:aimVector((inaccuracy or self.inaccuracy) + (360 / (self.projectileCount + 1) * i) + math.random(360))
	end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        aimAngle,
        false,
        params
      )
  end
  return projectileId
end

function StarForgeFloatingBeamFire:damagePerShot(fireTime, projectileCount, projectileDps)
  return (projectileDps * fireTime) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / projectileCount
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
  
  local currentEndSegmentImage = didCollide and self.chain.endCollideSegmentImage or self.chain.endSegmentImage
  
  --Optionally animate the chain beam
  if self.animatedChain then
	self.chainAnimationTimer = math.min(self.chainAnimationTime, self.chainAnimationTimer + self.dt)
	if self.chainAnimationTimer == self.chainAnimationTime then
	  self.chainAnimationTimer = 0
	end
	
	local chainAnimationFrame = 1
	chainAnimationFrame = math.floor(self.chainAnimationTimer / self.chainAnimationTime * self.chainAnimationFrames)
	
	if newChain.startSegmentImage then
	  newChain.startSegmentImage = self.chain.startSegmentImage .. ":" .. chainAnimationFrame .. newChain.directives
	end
	newChain.segmentImage = self.chain.segmentImage .. ":" .. chainAnimationFrame
	if newChain.endSegmentImage then
	  newChain.endSegmentImage = currentEndSegmentImage .. ":" .. chainAnimationFrame
	end
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
  local aimVector = vec2.rotate({1, 0}, (self.aimAngle - math.pi) + sb.nrand(inaccuracy, 0))
  --aimVector[1] = aimVector[1] * -1 --mcontroller.facingDirection()
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
