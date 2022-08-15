require "/scripts/util.lua"
require "/scripts/starforge-util.lua"
require "/items/active/weapons/weapon.lua"

StarforgeChainsawAlt = WeaponAbility:new()

function StarforgeChainsawAlt:init()
  self:reset()
  self.energyUsage = self.energyUsage or 0
end

function StarforgeChainsawAlt:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  animator.setParticleEmitterActive("miningSparks", self.damagingTiles)

  if self.weapon.currentAbility == nil
      and self.fireMode == (self.activatingFireMode or self.abilitySlot)
      and not status.resourceLocked("energy") then

    self:setState(self.charge)
  end
end

function StarforgeChainsawAlt:charge()
  self.weapon:setStance(self.stances.fireHold)
  self.weapon:updateAim()

  animator.setAnimationState("chainsaw", "active")

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", self.energyUsage * self.dt) do
    self.weapon:updateAim()
	
	if not self.holdLoopPlaying then
	  if animator.hasSound("holdLoop") then
		animator.playSound("holdLoop", -1)
		self.holdLoopPlaying = true
	  end
	  if animator.hasSound("damageLoop") then
		animator.playSound("damageLoop", -1)
		self.holdLoopPlaying = true
	  end
	else
	  if animator.hasSound("holdLoop") then
		if self.damagingTiles and animator.hasSound("damageLoop") then
		  animator.setSoundVolume("holdLoop", 0, 0)
		  animator.setSoundVolume("damageLoop", 1, 0)
		else
		  animator.setSoundVolume("holdLoop", 1, 0)
		  if animator.hasSound("damageLoop") then
			animator.setSoundVolume("damageLoop", 0, 0)
		  end
		end
	  end
	end

    local damageArea = partDamageArea("chainsaw")
    self.weapon:setDamage(self.damageConfig, damageArea, self.damageTimeout)
    if self.canCut then
      self:damageTiles(damageArea)
    end

    coroutine.yield()
  end

  animator.setParticleEmitterActive("chainsawActive", false)

  animator.playSound("winddown")
end

function StarforgeChainsawAlt:damageTiles(damageArea)
  local miningPositions = nebUtil.findPointsInPoly(damageArea)
  --Calculate tile damage per frame
  local levelMultiplier = 1
  if self.considerLevel then 
    levelMultiplier = config.getParameter("level", 1)
  end
  local tileDamage = levelMultiplier * self.tileDamagePerSecond * self.dt
  
  for _, x in ipairs(miningPositions) do
    world.debugPoint(x, "red")
  end
  
  --Reset damageTiles at the start of every frame
  self.damagingTiles = false
  
  --Optionally damage foreground tiles
  if self.damageForeground and tileDamage > 0 and self.tileDamagePerSecond > 0 then
	if world.damageTiles(miningPositions, "foreground", mcontroller.position(), self.tileDamageType, tileDamage, 99) then
	  self.damagingTiles = true
	end
  end
  
  --Optionally damage background tiles
  if self.damageBackground and tileDamage > 0 and self.tileDamagePerSecond > 0 then
	if world.damageTiles(miningPositions, "background", mcontroller.position(), self.tileDamageType, tileDamage, 99) then
	  self.damagingTiles = true
	end
  end
end

function StarforgeChainsawAlt:reset()
  self.weapon:setDamage()
  
  animator.setAnimationState("chainsaw", "idle")
  if animator.hasSound("holdLoop") then
	animator.stopAllSounds("holdLoop")
  end
  if animator.hasSound("damageLoop") then
	animator.stopAllSounds("damageLoop")
  end
  
  self.damagingTiles = false
  self.holdLoopPlaying = false
  animator.setParticleEmitterActive("miningSparks", false)
end

function StarforgeChainsawAlt:uninit()
  self:reset()
end