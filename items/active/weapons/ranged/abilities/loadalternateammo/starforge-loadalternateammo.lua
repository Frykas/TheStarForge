require "/scripts/starforge-abilityutil.lua" -- nebAbilityUtil

StarForgeLoadAlternateAmmo = WeaponAbility:new()

function StarForgeLoadAlternateAmmo:init()
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.weapon.abilities[self.adaptedAbilityIndex].stances.idle)
  end
  
  animator.setParticleEmitterActive("ammoIndicator", false)
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
  end
end

function StarForgeLoadAlternateAmmo:loadAmmo()
  local abilityType = self.newAbilityLoaded and self.abilityBackup or self.newAbility
  
  self:adaptAbility(abilityType)
	
  self.newAbilityLoaded = (not self.newAbilityLoaded)
	
  animator.playSound("loadAmmo")
  animator.setParticleEmitterActive("ammoIndicator", self.newAbilityLoaded)

  self.weapon:setStance(self.stances.load)
  util.wait(self.stances.load.duration)
end

function StarForgeLoadAlternateAmmo:adaptAbility(abilityType)
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  
  util.mergeTable(self.weapon.abilities[self.adaptedAbilityIndex], abilityType)
end

function StarForgeLoadAlternateAmmo:uninit()
end