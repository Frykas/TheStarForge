require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/starforge-weapon.lua"
require "/scripts/starforge-util.lua"

--meleeweapon.lua edited by Nebulox to allow for:
--Custom reticles
--Custom passive status effects that can be cleared on unequip, or left to last their duration
--Custom synergies between other handed weapons

function init()
  if config.getParameter("passiveStatusEffects") then
    self.tagGroup = ("starforge-" .. config.getParameter("itemName") .. activeItem.hand())
    status.addPersistentEffects(self.tagGroup, config.getParameter("passiveStatusEffects"))
  end

  local synergisticWeapons = config.getParameter("synergisticWeapons")
  if synergisticWeapons then
    self.synergyTagGroup = ("starforge-synergy" .. config.getParameter("itemName") .. activeItem.hand())

    local activeEffects = {}
    for weapon, effects in pairs(synergisticWeapons or {}) do
      if ((activeItem.hand() == "primary") and world.entityHandItem(entity.id(), "alt") or world.entityHandItem(entity.id(), "primary")) == weapon then
        for _, newEffect in ipairs(effects) do
          table.insert(activeEffects, newEffect)
        end
      end
    end
    status.addPersistentEffects(self.synergyTagGroup, activeEffects)
  end

  activeItem.setCursor(config.getParameter("cursor", "/cursors/pointer.cursor"))
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))
  animator.setGlobalTag("directives", "")
  animator.setGlobalTag("bladeDirectives", "")

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, util.toRadians(config.getParameter("baseWeaponRotation", 0)))
  self.weapon:addTransformationGroup("swoosh", {0,0}, math.pi/2)

  self.primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(self.primaryAbility)

  self.altAbility = getAltAbility()
  if self.altAbility then
    self.weapon:addAbility(self.altAbility)
  end

  self.finisherGraceTimer = 0
  
  self.partForActive = config.getParameter("partForActive", "blade")
  self.activeTime = config.getParameter("activeTime")
  if self.activeTime then
    self.activeTimer = 0
    animator.setAnimationState(self.partForActive, "inactive")
  end

  self.canEmpower = config.getParameter("canEmpower")
  if self.canEmpower then
    self.empowered = false

    self.depoweredBaseDps = config.getParameter("depoweredBaseDps", 10)
    self.empoweredBaseDps = config.getParameter("empoweredBaseDps", 12)
    self.depoweredEnergyUsage = config.getParameter("depoweredEnergyUsage", 0)
    self.empoweredEnergyUsage = config.getParameter("empoweredEnergyUsage", 1)

    self.activeSwooshPrefix = config.getParameter("activeSwooshPrefix")

    self.baseDamageConfig = nebUtil.copyTable(self.primaryAbility.damageConfig, 5)
    self.empoweredDamageConfig = config.getParameter("empoweredDamageConfig", self.baseDamageConfig)

    animator.setAnimationState(self.partForActive, "inactive")
    self.primaryAbility.baseDps = self.depoweredBaseDps
  end

  self.weapon:init()
end

function update(dt, fireMode, shiftHeld)
  --Thanks to C0bra5 for helping figure this out
	if self.finisherGraceTimer > 0 then
		self.finisherGraceTimer = self.finisherGraceTimer - dt
		fireMode = "alt"
	end

  self.weapon:update(dt, fireMode, shiftHeld)
  
  updateActiveState(dt)
  if self.canEmpower and self.altAbility then
    updateEmpoweredState()
  end
end

function updateActiveState(dt)
  if self.activeTime then
    local nowActive = self.weapon.currentAbility ~= nil
    if nowActive then
      if self.activeTimer == 0 then
        animator.setAnimationState(self.partForActive, "extend")
      end
      self.activeTimer = self.activeTime
    elseif self.activeTimer > 0 then
      self.activeTimer = math.max(0, self.activeTimer - dt)
      if self.activeTimer == 0 then
        animator.setAnimationState(self.partForActive, "retract")
      end
    end
  end
end

function updateEmpoweredState()
  if self.empowered ~= self.altAbility.active then
    self.empowered = self.altAbility.active
    if self.empowered then
      animator.setAnimationState(self.partForActive, "extend")
      self.primaryAbility.baseDps = self.empoweredBaseDps
      self.primaryAbility.energyUsage = self.empoweredEnergyUsage
      self.primaryAbility.damageConfig = self.empoweredDamageConfig
      self.primaryAbility:computeDamageAndCooldowns()
      self.primaryAbility.animKeyPrefix = self.activeSwooshPrefix or ""
    else
      animator.setAnimationState(self.partForActive, "retract")
      self.primaryAbility.baseDps = self.depoweredBaseDps
      self.primaryAbility.energyUsage = self.depoweredEnergyUsage
      self.primaryAbility.damageConfig = self.baseDamageConfig
      self.primaryAbility:computeDamageAndCooldowns()
      self.primaryAbility.animKeyPrefix = ""
    end
  end
end

function triggerFinisher(holdTime)
  self.finisherGraceTimer = holdTime or 0.5
end

function uninit()
  if config.getParameter("passiveStatusEffects") then
    status.clearPersistentEffects(self.tagGroup)
    if config.getParameter("statusEffectsLingerOnUnequip") then
      status.addEphemeralEffects(config.getParameter("passiveStatusEffects"), activeItem.ownerEntityId())
    end
    self.tagGroup = nil
  end

  if self.synergyTagGroup then
    status.clearPersistentEffects(self.synergyTagGroup)
    self.synergyTagGroup = nil
  end

  self.weapon:uninit()
end