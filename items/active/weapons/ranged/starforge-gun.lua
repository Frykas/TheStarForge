require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/starforge-weapon.lua"

--gun.lua edited by Nebulox to allow for:
--Custom reticles
--Custom passive status effects that can be cleared on unequip, or left to last their duration

function init()
  if config.getParameter("passiveStatusEffects") then
    self.tagGroup = ("starforge-" .. config.getParameter("itemName") .. activeItem.hand())
    status.addPersistentEffects(self.tagGroup, config.getParameter("passiveStatusEffects"))
  end

  activeItem.setCursor(config.getParameter("cursor", "/cursors/reticle0.cursor"))
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, 0)
  self.weapon:addTransformationGroup("muzzle", self.weapon.muzzleOffset, 0)

  local primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(primaryAbility)

  local secondaryAbility = getAltAbility(self.weapon.elementalType)
  if secondaryAbility then
    self.weapon:addAbility(secondaryAbility)
  end

  self.weapon:init()
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)
  
  world.debugPoint(vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset)), "red")
end

function uninit()
  if config.getParameter("passiveStatusEffects") then
    status.clearPersistentEffects(self.tagGroup)
    if config.getParameter("statusEffectsLingerOnUnequip") then
	  status.addEphemeralEffects(config.getParameter("passiveStatusEffects"), activeItem.ownerEntityId())
	end
  end

  self.weapon:uninit()
end
