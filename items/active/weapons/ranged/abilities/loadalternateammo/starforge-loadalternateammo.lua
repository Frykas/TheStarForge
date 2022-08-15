require "/scripts/starforge-abilityutil.lua" -- nebAbilityUtil

StarForgeLoadAlternateAmmo = WeaponAbility:new()

function StarForgeLoadAlternateAmmo:init()
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.weapon.abilities[self.adaptedAbilityIndex].stances.idle)
  end
  
  self.newAbilityLoaded = false
  self.abilityBackup = false
end

function StarForgeLoadAlternateAmmo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) then
    self:setState(self.loadAmmo)
  end
  
  if self.abilityBackup == false then
	--sb.jsonMerge() and copy() cause stack overflow
    self.abilityBackup = nebAbilityUtil.backupAbility(self.weapon.abilities[self.adaptedAbilityIndex])
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
	
  animator.playSound("loadAmmo")
  animator.setParticleEmitterActive("ammoIndicator", self.newAbilityLoaded)

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
end

function StarForgeLoadAlternateAmmo:adaptAbility(abilityType)
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  
  util.mergeTable(self.weapon.abilities[self.adaptedAbilityIndex], abilityType)
end

function StarForgeLoadAlternateAmmo:uninit()
end