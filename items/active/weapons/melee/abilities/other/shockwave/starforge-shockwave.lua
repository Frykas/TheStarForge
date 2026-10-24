require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/items/active/weapons/weapon.lua"

StarforgeShockwave = WeaponAbility:new()

function StarforgeShockwave:init()
  self.cooldownTimer = self.cooldownTime
end

function StarforgeShockwave:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  if self.weapon.currentAbility == nil and self.fireMode == "alt" and mcontroller.onGround() and not status.resourceLocked("energy") and self.cooldownTimer == 0 then
    self:setState(self.windup)
  end
end

-- Attack state: windup
function StarforgeShockwave:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  animator.setParticleEmitterActive("chargeShockwave", true)
  animator.playSound("chargeShockwave")

  local wasFull = false
  local chargeTimer = 0
  while self.fireMode == "alt" and (chargeTimer == self.chargeTime or status.overConsumeResource("energy", (self.energyUsage / self.chargeTime) * self.dt)) and not wasFull do
    chargeTimer = math.min(self.chargeTime, chargeTimer + self.dt)

    if chargeTimer == self.chargeTime and not wasFull then
      wasFull = true
      animator.stopAllSounds("chargeShockwave")
    end

    local chargeRatio = math.sin(chargeTimer / self.chargeTime * 1.57)
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.armRotation, self.stances.windup.endArmRotation}))
    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.weaponRotation, self.stances.windup.endWeaponRotation}))

    mcontroller.controlModifiers({
      jumpingSuppressed = true,
      runningSuppressed = true
    })

    coroutine.yield()
  end

  animator.stopAllSounds("chargeShockwave")

  if chargeTimer > self.minChargeTime then
    self:setState(self.fire, chargeTimer / self.chargeTime)
  end
end

-- Attack state: fire
function StarforgeShockwave:fire(charge)
  self.weapon:setStance(self.stances.fire)
  self.cooldownTimer = self.cooldownTime

  self:fireShockwave(charge)
  animator.playSound("fire")

  util.wait(self.stances.fire.duration)
end

function StarforgeShockwave:reset()
  animator.setParticleEmitterActive("chargeShockwave", false)
  animator.stopAllSounds("chargeShockwave")
end

function StarforgeShockwave:uninit()
  self:reset()
end

-- Helper functions
function StarforgeShockwave:fireShockwave(charge)
  local impact, impactHeight = self:impactPosition()

  if impact then
    local charge = math.floor(charge * self.maxProjectiles)
    local spawnData = self:shockWaveProjectilePositions(impact, charge)
    if #spawnData > 0 then
      animator.playSound("shockwaveImpact")
      local params = copy(self.projectileParameters)
      params.powerMultiplier = activeItem.ownerPowerMultiplier()
      params.power = (params.power or 1) * config.getParameter("damageLevelMultiplier")
      
      local childParams = self.projectileParameters or {}
      params.actionOnReap = {}
      params.damageType = "nodamage"
      params.actionOnReap[#params.actionOnReap + 1] = {
        action = "projectile",
        inheritDamageFactor = 1,
        type = self.projectileType,
        config = childParams,
        fuzzAngle = self.projectileFuzzAngle or nil,
        direction = self.forceDirection or nil
      }
      for i, data in pairs(spawnData) do
        params.timeToLive = data.delayTime
        local aimVec = (self.moveInDirection and data.direction) or {0, 1}
        if self.targetDirection then
          aimVec = {self.targetDirection[1] * mcontroller.facingDirection(), self.targetDirection[2]}
        end
        local point = data.position
        if self.projectileOffset then
          point = vec2.add(point, self.projectileOffset)
        end
        world.spawnProjectile("starforge-shockwavespawner", point, activeItem.ownerEntityId(), aimVec, false, params)
      end
    end
  end
end

function StarforgeShockwave:impactPosition()
  local dir = mcontroller.facingDirection()
  local startLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[1], {dir, 1}))
  local endLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[2], {dir, 1}))

  local blocks = world.collisionBlocksAlongLine(startLine, endLine, {"Null", "Block"})
  if self.ignoreGround then
    return mcontroller.position(), mcontroller.position()[2] + 1
  elseif #blocks > 0 then
    return vec2.add(blocks[1], {0.5, 0.5}), endLine[2] - blocks[1][2] + 1
  end
end

function StarforgeShockwave:shockWaveProjectilePositions(impactPosition, maxProjectiles)
  local spawnData = {}
  
  for x, dir in pairs(self.directions or {{1, 0}}) do
    local newDir = {dir[1] * mcontroller.facingDirection(), dir[2]}
    local position = copy(impactPosition)
    for i = 1, maxProjectiles do
      local continue = false

      local stepDistance = vec2.mul(vec2.norm(newDir), self.shockwaveStepDistance * i)
      local waveStepPosition = vec2.add(position, stepDistance)

      local yPositiveTest = vec2.add(waveStepPosition, {0, self.maxYStep})
      local yNegativeTest = vec2.add(waveStepPosition, {0, -self.maxYStep})

      local collidePoint = world.lineTileCollisionPoint(yPositiveTest, yNegativeTest, {"Null", "Block", "Dynamic", "Slippery"})
      local bounds = rect.translate(self.shockWaveBounds, vec2.add(collidePoint and collidePoint[1] or waveStepPosition, {0, self.shockwaveHeight}))
      if self.ignoreGround or collidePoint then
        local point = self.ignoreGround and waveStepPosition or collidePoint[1]
        local posData = {
          position = point,
          direction = newDir,
          delayTime = self.delayTime or 0
        }
        if self.directionDelay then
          posData.delayTime = posData.delayTime + (self.directionDelay * x)
        end
        if self.distanceDelay then
          posData.delayTime = posData.delayTime + (math.floor(math.abs(world.magnitude(mcontroller.position(), point)))) * self.distanceDelay
        end
        table.insert(spawnData, posData)

        continue = true
      end

      if not continue then break end
    end
  end
  
  return spawnData
end