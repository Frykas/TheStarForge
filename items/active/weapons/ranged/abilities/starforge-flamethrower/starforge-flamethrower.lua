require "/items/active/weapons/ranged/starforge-gunfire.lua"

StarforgeFlamethrower = StarforgeGunFire:new()

function StarforgeFlamethrower:init()
  StarforgeGunFire.init(self)

  self.active = false
  
  --For randomness in pitch
  self.pitchPerlinNoise = sb.makePerlinSource({seed = math.random(0,65535), type = "perlin"})
end

function StarforgeFlamethrower:update(dt, fireMode, shiftHeld)
  StarforgeGunFire.update(self, dt, fireMode, shiftHeld)

  if self.active then
    --Sound pitch variance
	local pitchVariance = (1 + (self.pitchPerlinNoise:get(os.clock()) * (self.pitchVariance or 0.5)))
	animator.setSoundPitch("fireLoop", pitchVariance)
  end

  if self.weapon.currentAbility == self then
    if not self.active then self:activate() end
  elseif self.active then
    self:deactivate()
  end
end

function StarforgeFlamethrower:muzzleFlash()
  --Disable the normal muzzle flash
end

function StarforgeFlamethrower:activate()
  self.active = true
  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)
end

function StarforgeFlamethrower:deactivate()
  self.active = false
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
  animator.playSound("fireEnd")
end
