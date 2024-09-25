require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"
require "/scripts/status.lua"

function init()
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))
  animator.setGlobalTag("directives", "")
  animator.setGlobalTag("bladeDirectives", "")

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, util.toRadians(config.getParameter("baseWeaponRotation", 0)))
  self.weapon:addTransformationGroup("swoosh", {0,0}, math.pi/2)

  self.primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(self.primaryAbility)

  self.altAbility = getAltAbility()
  self.weapon:addAbility(self.altAbility)

  self.weapon:init()

  self.inactiveBaseDps = config.getParameter("inactiveBaseDps", 10)
  self.activeBaseDps = config.getParameter("activeBaseDps", 12)
  self.inactiveEnergyUsage = config.getParameter("inactiveEnergyUsage", 0)
  self.activeEnergyUsage = config.getParameter("activeEnergyUsage", 1)
  
  self.statusEffects = config.getParameter("statusEffects", {})

  self.active = false
  animator.setAnimationState("sword", "inactive")
  self.primaryAbility.baseDps = self.inactiveBaseDps
  self.primaryAbility:computeDamageAndCooldowns()
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)

  setActive(self.altAbility.active)
  if self.active then
    self.damageListener:update()
  end
end

function uninit()
  self.weapon:uninit()
end

function setActive(active)
  if self.active ~= active then
    self.active = active
    if self.active then
	  createDamageListener("inflictedDamage")
      animator.setAnimationState("sword", "extend")
      self.primaryAbility.baseDps = self.activeBaseDps
      self.primaryAbility.energyUsage = self.activeEnergyUsage
      self.primaryAbility:computeDamageAndCooldowns()
    else
      animator.setAnimationState("sword", "retract")
      self.primaryAbility.baseDps = self.inactiveBaseDps
      self.primaryAbility.energyUsage = self.inactiveEnergyUsage
      self.primaryAbility:computeDamageAndCooldowns()
    end
  end
end

function createDamageListener(type)
  self.damageListener = damageListener(type, function(notifications)
    for _, notification in ipairs(notifications) do
      for _, statusEffect in ipairs(self.statusEffects) do
		world.sendEntityMessage(notification.targetEntityId, "applyStatusEffect", statusEffect)
	  end
	end
  end)
end