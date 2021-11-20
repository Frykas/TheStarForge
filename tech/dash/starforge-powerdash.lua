require "/tech/doubletap.lua"
require "/scripts/vec2.lua"
require "/scripts/starforge-util.lua"

function init()
  nebUtil.getParameters({"dashCharges", "dashRechargeInterval", "dashInternalCooldown", "dashControlForce", "dashSpeed", "dashDuration", "consecutiveDashTimeout", "dashOverchargeTimeout"})

  -- Optional config parameters
  self.dashingDirectives = config.getParameter("dashingDirectives", "?fade=88FFFFFF=0.4")
  self.rechargeDirectives = config.getParameter("rechargeDirectives", "?fade=CCCCFF88=0.15")
  self.rechargeEffectTime = config.getParameter("rechargeEffectTime", 0.08)
  self.rechargeBeepTime = config.getParameter("rechargeBeepTime", 0.18)
  self.groundOnly = config.getParameter("groundOnly", true)
  self.cooldownOnGroundOnly = config.getParameter("cooldownOnGroundOnly", true)
  
  self.maxPitch = config.getParameter("maxPitch", 1) - 1
  
  -- Base Values
  self.currentCharges = self.dashCharges
  
  self.dashDirection = {0, 0}
  self.dashTimer = 0
  self.consecutiveDashTimer = 0
  self.consecutiveDashes = 0
  
  self.cooldownTimer = 0
  self.rechargeTimer = 0
  self.rechargeEffectTimer = 0
  animator.setAnimationState("dashing", "off")
  animator.setParticleEmitterActive("dashParticles", false)
  
  self.doubleTap = DoubleTap:new({"left", "right"}, config.getParameter("maximumDoubleTapTime"), function(dashKey)
    -- Special key pressed and internal cooldown off
    if self.currentCharges > 0
      and self.cooldownTimer == 0
      and self.dashTimer == 0
      and groundValid()
      and not mcontroller.crouching()
      and not status.statPositive("activeMovementAbilities") then
	  
      startDash(dashKey == "left" and -1 or 1)
    end
  end)
end

function update(args)
  self.wasOnGround = mcontroller.onGround() or mcontroller.liquidMovement() or mcontroller.zeroG()
  
  local dt, moves = args.dt, args.moves
  
  updateCooldowns(dt)
  self.doubleTap:update(dt, moves)
  updateDash(dt)
end

function groundValid()
  return mcontroller.groundMovement() or not self.groundOnly
end

function updateCooldowns(dt)  
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  --Recharge the dashes
  if self.rechargeTimer > 0 and self.wasOnGround and self.cooldownTimer == 0 then
    self.rechargeTimer = math.max(0, self.rechargeTimer - dt)
	if self.rechargeTimer == 0 then
      self.currentCharges = math.min(self.dashCharges, self.currentCharges + 1)
	  
      tech.setParentDirectives(self.rechargeDirectives)
      animator.playSound("recharge")
      self.rechargeEffectTimer = self.rechargeEffectTime
	  
      startRecharge()
	end
  end
  
  --Charge animations
  if self.rechargeEffectTimer > 0 then
    self.rechargeEffectTimer = math.max(0, self.rechargeEffectTimer - dt)
	if self.rechargeEffectTimer == 0 then
      tech.setParentDirectives()
    end
  end
  
  if self.consecutiveDashTimer > 0 then
    self.consecutiveDashTimer = math.max(0, self.consecutiveDashTimer - dt)
    if self.consecutiveDashTimer <= 0 then
      self.consecutiveDashes = 0
    end
  end
end

function updateDash(dt)
  if self.dashTimer > 0 then
    tech.setParentDirectives(self.dashingDirectives)
  
    mcontroller.setVelocity(vec2.mul(self.dashDirection, self.dashSpeed))
    mcontroller.controlModifiers({jumpingSuppressed = true})
  
    animator.setFlipped(mcontroller.facingDirection() == -1)
  
    self.dashTimer = math.max(0, self.dashTimer - dt)
    if self.dashTimer == 0 then
      endDash()
    end
  end
end

function startDash(direction)
  self.cooldownTimer = self.dashInternalCooldown
  self.dashDirection = {direction, 0.2}
  
  self.dashTimer = self.dashDuration
  self.currentCharges = math.max(0, self.currentCharges - 1)

  startRecharge()
  
  status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  
  local boostPercent = self.consecutiveDashes / self.dashCharges
  local boostPitch = boostPercent * self.maxPitch
  animator.setSoundPitch("dash", 1 + boostPercent)
  animator.playSound("dash")
  
  tech.setParentState("Fly")
  status.addEphemeralEffect("invulnerable")
  
  self.consecutiveDashTimer = self.consecutiveDashTimeout + config.getParameter("maximumDoubleTapTime")
  self.consecutiveDashes = self.consecutiveDashes + 1
  
  if self.consecutiveDashes == self.dashCharges then
    animator.playSound("dashOvercharge")
    self.cooldownTimer = self.dashOverchargeTimeout
	self.consecutiveDashes = 0
  end
  
  animator.setAnimationState("dashing", "on")
  animator.setParticleEmitterActive("dashParticles", true)
end

function endDash()
  tech.setParentDirectives()
  tech.setParentState()
  status.removeEphemeralEffect("invulnerable")
  status.clearPersistentEffects("movementAbility")

  local movementParams = mcontroller.baseParameters()
  local currentVelocity = mcontroller.velocity()
  
  if math.abs(currentVelocity[1]) > movementParams.runSpeed then
    mcontroller.setXVelocity(movementParams.runSpeed * self.dashDirection[1])
  end
  mcontroller.setYVelocity(0)
  
  mcontroller.controlApproachXVelocity(self.dashDirection[1] * movementParams.runSpeed, self.dashControlForce)
  
  animator.setAnimationState("dashing", "off")
  animator.setParticleEmitterActive("dashParticles", false)
end

function startRecharge()
  if self.rechargeTimer > 0 or self.currentCharges >= self.dashCharges then
    return
  end
  self.rechargeTimer = self.dashRechargeInterval
end

function uninit()
  status.removeEphemeralEffect("invulnerable")
  status.clearPersistentEffects("movementAbility")
  tech.setParentDirectives()
  animator.setAnimationState("dashing", "off")
  animator.setParticleEmitterActive("dashParticles", false)
end