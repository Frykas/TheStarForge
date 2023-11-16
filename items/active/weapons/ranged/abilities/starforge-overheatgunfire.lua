require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/starforge-util.lua"
require "/items/active/weapons/ranged/starforge-gunfire.lua"

local oldInit = StarforgeGunFire.init or function() end
function StarforgeGunFire:init()
  self.overheat = config.getParameter("overheat", 0)
  self.overheated = config.getParameter("overheated", false)
  
  self.energyUsage = self.weapon.abilities[1].energyUsage * 0.5
  
  oldInit(self)
end

local oldUpdate = StarforgeGunFire.update or function() end
function StarforgeGunFire:update(dt, fireMode, shiftHeld)
  if self.overheated then
    self.overheat = math.max(0, self.overheat - (1.5 * self.energyUsage) * dt)
    local soundPitchFactor = self.overheat / 100
    local soundPitch = 0.75 + (soundPitchFactor * 0.5)
    animator.setSoundPitch("overheatedLoop", soundPitch)
    
    self.cooldownTimer = self.fireTime
    if self.overheat == 0 then
      animator.stopAllSounds("overheatedLoop")
      self.overheated = false
    end
  elseif self.cooldownTimer == 0 then
    self.overheat = math.max(0, self.overheat - (1.25 * self.energyUsage) * dt)
  end 
  world.debugText("%s", self.overheat, {mcontroller.position()[1] + 5, mcontroller.position()[2]}, "red")
  
  self:updateIndicator()
  
  oldUpdate(self, dt, fireMode, shiftHeld)
end

function StarforgeGunFire:updateIndicator()
  animator.resetTransformationGroup("heatIndicator")
  
  local heatFactor = math.min(1, self.overheat * 0.01)
  
  local overheatedRotation = (self.overheatRotation and self.overheatRotation[1] or -math.pi)
  local neutralRotation = (self.overheatRotation and self.overheatRotation[2] or math.pi)
  local rotation = nebUtil.interpLinear(neutralRotation, overheatedRotation, heatFactor)
  animator.rotateTransformationGroup("heatIndicator", rotation)
  --world.debugText("%s, %s, %s", neutralRotation, overheatedRotation, rotation, {mcontroller.position()[1] + 7, mcontroller.position()[2]}, "red")
  
  local overheatedPosition = self.overheatPosition and self.overheatPosition[1] or {0, 0}
  local neutralPosition = self.overheatPosition and self.overheatPosition[2] or {0, 0}
  local position = {nebUtil.interpLinear(neutralPosition[1], overheatedPosition[1], heatFactor), nebUtil.interpLinear(neutralPosition[2], overheatedPosition[2], heatFactor)}
  animator.translateTransformationGroup("heatIndicator", position)
  
  animator.translateTransformationGroup("heatIndicator", self.weapon.weaponOffset)
  animator.rotateTransformationGroup("heatIndicator", self.weapon.relativeWeaponRotation, self.weapon.relativeWeaponRotationCenter)
end

local oldMuzzleFlash = StarforgeGunFire.muzzleFlash or function() end
function StarforgeGunFire:muzzleFlash() 
  self.overheat = self.overheat and (self.overheat + (self:energyPerShot() * 2.5)) or 0
  
  local pitchIncrease = 0
  if self.overheat > 60 then
    local factor = (self.overheat - 60) / 40
    pitchIncrease = factor * 0.5
  end
  
  if self.overheat > 100 then
    animator.playSound("overheatedLoop", -1)
    animator.playSound("overheat")
    self.overheated = true
  end
  
  oldMuzzleFlash(self, pitchIncrease)
end

local oldUninit = StarforgeGunFire.uninit or function() end
function StarforgeGunFire:uninit() oldUninit(self)
  --animator.stopAllSounds("overheatedLoop")
  activeItem.setInstanceValue("overheat", self.overheat)
  activeItem.setInstanceValue("overheated", self.overheated)
end
