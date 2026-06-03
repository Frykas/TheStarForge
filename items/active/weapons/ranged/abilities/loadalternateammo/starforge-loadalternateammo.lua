require "/scripts/starforge-util.lua" -- nebUtil

StarForgeLoadAlternateAmmo = WeaponAbility:new()

function StarForgeLoadAlternateAmmo:init()  
  self.newAbilityLoaded = false
  self.abilityBackup = false
  self.swapCooldown = 0
end

function StarForgeLoadAlternateAmmo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.swapCooldown = math.max(0, self.swapCooldown - self.dt)
  if self.swapCooldown == 0 and not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) then
    self:setState(self.loadAmmo)
  end
  
  if self.abilityBackup == false then
	  --sb.jsonMerge() and copy() cause stack overflow
    self.abilityBackup = nebUtil.backupAbility(self.weapon.abilities[self.adaptedAbilityIndex])
    if config.getParameter("newAbilityLoaded", false) then
      self:initAltAmmo()
    end
  end
end

function StarForgeLoadAlternateAmmo:initAltAmmo()
  local abilityType = self.newAbilityLoaded and self.abilityBackup or self.newAbility
  self:adaptAbility(abilityType)
  
  self.newAbilityLoaded = true
  activeItem.setInstanceValue("newAbilityLoaded", self.newAbilityLoaded)
  
  animator.setParticleEmitterActive("ammoIndicator", self.newAbilityLoaded)
end

function StarForgeLoadAlternateAmmo:loadAmmo()
  local abilityType = self.newAbilityLoaded and self.abilityBackup or self.newAbility
  
  self:adaptAbility(abilityType)

  self.newAbilityLoaded = (not self.newAbilityLoaded)
  activeItem.setInstanceValue("newAbilityLoaded", self.newAbilityLoaded)

  self.swapCooldown = self.newAbilityLoaded and self.swapOnCooldown or self.swapOffCooldown
  animator.playSound("loadAmmo")
  animator.setParticleEmitterActive("ammoIndicator", self.newAbilityLoaded)

  if self.loadAnimationStates and self.newAbilityLoaded then
    for part, state in pairs(self.loadAnimationStates) do
      animator.setAnimationState(part, state)
    end
  elseif self.unloadAnimationStates and not self.newAbilityLoaded then
    for part, state in pairs(self.unloadAnimationStates) do
      animator.setAnimationState(part, state)
    end
  end

  self.weapon:setStance(self.stances.load)
  util.wait(self.stances.load.duration / 2)
  
  local progress = 0
  util.wait(self.stances.load.duration, function()
    local from = self.stances.load.weaponOffset or {0,0}
    local to = self.weapon.abilities[self.adaptedAbilityIndex].stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {util.interpolateHalfSigmoid(progress, from[1], to[1]), util.interpolateHalfSigmoid(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateHalfSigmoid(progress, self.stances.load.weaponRotation, self.weapon.abilities[self.adaptedAbilityIndex].stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(util.interpolateHalfSigmoid(progress, self.stances.load.armRotation, self.weapon.abilities[self.adaptedAbilityIndex].stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.load.duration))
  end)

  self.weapon:setStance(self.weapon.abilities[self.adaptedAbilityIndex].stances.idle)
  self.weapon:updateAim()
end

function StarForgeLoadAlternateAmmo:adaptAbility(abilityType)
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  util.mergeTable(self.weapon.abilities[self.adaptedAbilityIndex], abilityType)
end

function StarForgeLoadAlternateAmmo:uninit()
end