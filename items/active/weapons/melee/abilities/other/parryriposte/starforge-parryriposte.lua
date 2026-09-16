require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/poly.lua"
require "/items/active/weapons/weapon.lua"

StarforgeParryRiposte = WeaponAbility:new()

function StarforgeParryRiposte:init()
  self.cooldownTimer = 0
end

function StarforgeParryRiposte:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.weapon.currentAbility == nil
    and fireMode == "alt"
    and self.cooldownTimer == 0
    and status.overConsumeResource("energy", self.energyUsage) then

    self:setState(self.parry)
  end
end

function StarforgeParryRiposte:parry()
  self.weapon:setStance(self.stances.parry)
  self.weapon:updateAim()
  
  --Display the shield health bar
  status.setPersistentEffects("broadswordParry", {{stat = "shieldHealth", amount = 1000}})
  
  --Create a shield poly to block attacks
  local blockPoly = animator.partPoly("parryShield", "shieldPoly")
  activeItem.setItemShieldPolys({blockPoly})
  
  --Play the iniate guard stance sound
  animator.playSound("guard")
  
  --Set up a damagelistener for incoming blocked damage
  local damageListener = damageListener("damageTaken", function(notifications)
    for _, notification in pairs(notifications) do
      if notification.sourceEntityId ~= entity.id() and notification.healthLost == 0 then
        animator.playSound("parry")
		    world.spawnProjectile(self.deflectProjectileType, mcontroller.position(), activeItem.ownerEntityId(), {0, 0}, true)

        local sourceEntity = notification.sourceEntityId
        sb.logInfo("%s", sourceEntity)
        if sourceEntity and (not world.entityExists(sourceEntity) or sourceEntity == 0) then
          local targets = world.entityQuery(notification.position or mcontroller.position(), 5, {
            withoutEntityId = activeItem.ownerEntityId(),
            includedTypes = {"creature"},
            order = "nearest"
          })
          for _, target in ipairs(targets) do
            if world.entityExists(target) then
              sourceEntity = target
              break
              return
            end
          end
        end
        sb.logInfo("%s", sourceEntity)
		
		    self:setState(self.windup, sourceEntity)
        return
      end
    end
  end)
  
  --Wait for incoming attacks
  util.wait(self.parryTime, function(dt)
    --Interrupt when running out of shield stamina
    if not status.resourcePositive("shieldStamina") then
      return true
    end

    damageListener:update()
  end)
  
  --Reset the parry behaviour
  self.cooldownTimer = self.cooldownTime
  activeItem.setItemShieldPolys({})
end

--Brief frame before the parry attack
function StarforgeParryRiposte:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

-- State: windup
function StarforgeParryRiposte:windup(hitEntity)
  local stance = self.stances.windup
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")
  
  status.clearPersistentEffects("broadswordParry")
  activeItem.setItemShieldPolys({})

  if stance.teleport and stance.animateEarly then
    local animStateKey = self.animKeyPrefix .. "altFire"
    animator.setAnimationState("swoosh", animStateKey)
    animator.playSound(animStateKey)

    local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
    animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  end
  
  -- Optionally flash the weapon
  if stance.flashTime then
    self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end
  -- Optional Emotes
  if stance.emote then
    activeItem.emote(stance.emote)
  end

  self.weapon:setStance(stance)

  self.edgeTriggerTimer = 0

  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    local windupSwing = {}
    if stance.windupSwing ~= false or stance.windupSwing ~= 0 then
      local windupSwingValue = stance.windupSwing or 0.1
      local fireStance = self.stances.fire
      windupSwing.armRotation = (stance.armRotation - fireStance.armRotation) * windupSwingValue
      windupSwing.weaponRotation = (stance.weaponRotation - fireStance.weaponRotation) * windupSwingValue
    end
    
    local progress = 0
    util.wait(stance.duration * (self.stanceSpeedFactor or 1), function()
      if stance.windupSwing ~= false then
        for part, rotation in pairs(windupSwing) do
          local from = stance[part]
          local to = stance[part] + rotation
        
          self.weapon["relative" .. part:gsub("^%l", string.upper)] = util.toRadians(util.interpolateHalfSigmoid(1- progress, from, to))
        end
        progress = math.min(1.0, progress + (self.dt / (stance.duration * (self.stanceSpeedFactor or 1))))
      end
    end)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if stance.teleport then
    self:setState(self.teleport, hitEntity)
  elseif self.stances.preslash then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- waiting for next combo input
function StarforgeParryRiposte:teleport(hitEntity)
  local stance = self.stances.fire
  
  --Create the teleportation effect and add 0.5 for both animations to take effect
  status.addEphemeralEffect(stance.teleportStatus or "starforge-teleporteffect", stance.duration * (self.stanceSpeedFactor or 1) + 0.5)

  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")
  self.weapon:setStance(stance)
  self.weapon:updateAim()

  --Allow first teleport effect to take place
  util.wait(0.25)
  
  local oldPosition = mcontroller.position()
  local targetPosition = world.entityPosition(hitEntity or entity.id())

  local groundCollision = world.lineTileCollisionPoint(mcontroller.position(), targetPosition)
  if groundCollision then
    local groundPos, normal = groundCollision[1], groundCollision[2]
    targetPosition = groundPos
  end
	
  world.resolvePolyCollision(mcontroller.collisionPoly(), vec2.add(targetPosition, stance.teleportOffset), stance.teleportTolerance)
  if stance.projectileType and targetPosition then
    local angleToTarget = vec2.angle({targetPosition[2] - mcontroller.position()[2], targetPosition[1] - mcontroller.position()[1]})
    local aimVector = vec2.rotate({0, 1}, -angleToTarget)
    --aimVector[1] = aimVector[1] * mcontroller.facingDirection()
    
    local params = stance.projectileParameters or {}
    params.power = stance.projectileDamage * config.getParameter("damageLevelMultiplier")
    params.powerMultiplier = activeItem.ownerPowerMultiplier()
    params.speed = util.randomInRange(params.speed)
      
    world.spawnProjectile(
      stance.projectileType,
      targetPosition,
      activeItem.ownerEntityId(),
      aimVector,
      false,
      params
    )
  end
  
  util.wait(stance.duration * (self.stanceSpeedFactor or 1), function()
    --Reset player momentum, prevents fall damage
    if stance.trackProjectile ~= false then
      mcontroller.setXVelocity(0, 0)
      mcontroller.setYVelocity(0, 0)
      mcontroller.setPosition(targetPosition)
    end
  end)
  animator.setGlobalTag("comboDirectives", "")
  
  if stance.trackProjectile ~= false then
    mcontroller.setPosition(oldPosition)
  end

  self.cooldownTimer = self.successfulCooldownTime
end

-- State: preslash
-- brief frame in between windup and fire
function StarforgeParryRiposte:preslash()
  local stance = self.stances.preslash
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(self.fire)
end

-- State: fire
function StarforgeParryRiposte:fire()
  local stance = self.stances.fire
  animator.setGlobalTag("comboDirectives", stance.comboDirectives or "")
  
  -- Optionally flash the weapon
  if stance.flashTime then
    self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end
  -- Optional Emotes
  if stance.emote then
    activeItem.emote(stance.emote)
  end

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. "altfire"
  if animator.hasTransformationGroup("swooshOffset") then
    animator.resetTransformationGroup("swooshOffset")
    if self.swooshReachOffset then
      animator.translateTransformationGroup("swooshOffset", {self.swooshReachOffset, 0})
    end
    if stance.swooshRotation then
      animator.rotateTransformationGroup("swooshOffset", util.toRadians(stance.swooshRotation))
    end
  end
  if not stance.animationStates or not stance.animationStates.swoosh then
    animator.setAnimationState("swoosh", animStateKey)
  end

  --Add normal pitch variance to shots
  local pitchVariance = ((self.swingPitchFactor or 1) + (self.pitchVariance or 0.1)) - (math.random() * ((self.pitchVariance or 0.1) * 2)) + (pitchIncrease or 0)
  animator.setSoundPitch(animStateKey, pitchVariance)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)
  
  if stance.projectileType then
    self:spawnProjectile(stance)
  end

  -- If this step is configured as a "spin" move, spin the weapon
  if stance.spinRate then
    util.wait(stance.duration * (self.stanceSpeedFactor or 1), function()
      local damageArea = partDamageArea("swoosh")
      self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
    
      -- Remove the weapon from the player's hand, allowing it to rotate freely
      activeItem.setOutsideOfHand(true)
    
      -- Spin the weapon
      self.weapon.relativeWeaponRotation = self.weapon.relativeWeaponRotation + util.toRadians(stance.spinRate * self.dt)
    
      -- Optionally force the player to walk while in this stance
      if stance.forceWalking then
        mcontroller.controlModifiers({runningSuppressed=true})
      end
      
      -- Optionally freeze the player in place if so configured
      if stance.freezePlayer then
       mcontroller.setVelocity({0,0})
      end
    end)
    animator.setAnimationState("swoosh", "idle")
  -- If this step is a regular attack, simply set the damage area for the duration of the step
  else
    local overSwing = {}
    if stance.overSwing ~= false and stance.overSwing ~= 0 then
      local overSwingValue = stance.overSwing or 0.1
      local windupStance = self.stances["windup"..self.comboStep]
      overSwing.armRotation = (stance.armRotation - windupStance.armRotation) * overSwingValue
      overSwing.weaponRotation = (stance.weaponRotation - windupStance.weaponRotation) * overSwingValue
    end
    
    local progress = 0
    util.wait(stance.duration * (self.stanceSpeedFactor or 1), function()
      local damageArea = partDamageArea("swoosh")
      self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
      
      --Optionally freeze the player in place if so configured
      if stance.freezePlayer then
        mcontroller.setVelocity({0,0})
      end
    
      if stance.overSwing ~= false and stance.overSwing ~= 0 then
        for part, rotation in pairs(overSwing) do
          local from = stance[part]
          local to = stance[part] + rotation
        
          self.weapon["relative" .. part:gsub("^%l", string.upper)] = util.toRadians(util.interpolateHalfSigmoid(progress, from, to))
        end
        progress = math.min(1.0, progress + (self.dt / (stance.duration * (self.stanceSpeedFactor or 1))))
      end
    end)
  end
  if stance.swooshRotation then
    animator.resetTransformationGroup("swooshOffset")
  end
  
  if stance.continueStep then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
  
    for part, state in pairs(self.resetAnimationStates or {}) do
      animator.setAnimationState(part, state)
    end
      
    local alt = getAltAbility()
    if alt and self.altComboFinisher then
      animator.setGlobalTag("comboDirectives", "")
      self.stallLeaveAbiity = true
      triggerFinisher(self.finisherHoldTime)
    end
  end

  self.cooldownTimer = self.successfulCooldownTime
end

function StarforgeParryRiposte:reset()
  status.clearPersistentEffects("broadswordParry")
  activeItem.setItemShieldPolys({})
end

function StarforgeParryRiposte:uninit()
  self:reset()
end
