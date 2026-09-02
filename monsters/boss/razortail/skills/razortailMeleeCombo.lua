razortailMeleeCombo = {}

function razortailMeleeCombo.enter()
  if not hasTarget() then return nil end

  return {
    timer = config.getParameter("razortailMeleeCombo.windDownDuration", 0.7),

    randomSequence = config.getParameter("razortailMeleeCombo.randomSequence", false),
    attackSequence = config.getParameter("razortailMeleeCombo.attackSequence", {
      {
        windupState = "tailWhipWindup",
        attackState = "tailWhip",
        windupDuration = 0.45,

        teleportOffset = 9,
        attackImpulse = 145,

        damageDuration = 0.35,
        idleTime = 0.3,

        correctedKnockback = true,
        damageConfig = {
          poly = { {2.5, 1}, {7, -1.75}, {7, -4}, {-7, -4}, {-7, -1.75}, {-2.5, 1} },
          damage = 12,
          knockback = 55,

          teamType = "enemy",
          damageSourceKind = "starforge-tidalfrost",
          statusEffects = { "starforge-tidalfreeze" },
          damageRepeatGroup = "starforge-razortailTailWhip",
          damageRepeatTimeout = 1
        }
      },
      {
        windupState = "clawSlashWindup",
        attackState = "clawSlash",
        windupDuration = 0.3,

        teleportOffset = 8,
        attackImpulse = 155,

        damageDuration = 0.35,
        idleTime = 0.2,

        correctedKnockback = true,
        damageConfig = {
          poly = { {2.5, 1}, {7, -1.75}, {7, -4}, {-7, -4}, {-7, -1.75}, {-2.5, 1} },
          damage = 10,
          knockback = 55,

          teamType = "enemy",
          damageSourceKind = "starforge-tidalfrost",
          statusEffects = { "starforge-tidalfreeze" },
          damageRepeatGroup = "starforge-razortailClawSlash",
          damageRepeatTimeout = 1
        }
      },
      {
        windupState = "biteWindup",
        attackState = "bite",
        windupDuration = 0.2,

        teleportOffset = 7,
        attackImpulse = 125,

        damageDuration = 0.35,
        idleTime = 0.7,

        correctedKnockback = true,
        damageConfig = {
          poly = { {2.5, 1}, {7, -1.75}, {7, -4}, {-7, -4}, {-7, -1.75}, {-2.5, 1} },
          damage = 25,
          knockback = 55,

          teamType = "enemy",
          damageSourceKind = "starforge-tidalfrost",
          statusEffects = { "starforge-tidalfreeze" },
          damageRepeatGroup = "starforge-razortailBite",
          damageRepeatTimeout = 1
        }
      }
    }),
    sequenceStep = 1,
    
    sequenceBreakDistance = config.getParameter("razortailMeleeCombo.sequenceBreakDistance", {15, 9})
  }
end

function razortailMeleeCombo.enteringState(stateData)
  monster.setActiveSkillName("razortailMeleeCombo")
  razortailMeleeCombo.teleport(stateData)
  stateData.timer = calculateCooldown(stateData.timer)
end

function razortailMeleeCombo.update(dt, stateData)
  if stateData.timerActive then
    stateData.timer = math.max(0, stateData.timer - dt)
    
    if stateData.timer == 0 then
      return true
    end
  end
  return false
end

function razortailMeleeCombo.teleport(stateData)
  local currentStep = stateData.attackSequence[stateData.sequenceStep]
  
  stateData.directionToPlayer = stateData.directionToPlayer or util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  local teleportPosition = calculatePosition(self.targetPosition, {(stateData.sequenceStep % 2 == 0 and -1 or 1) * stateData.directionToPlayer * currentStep.teleportOffset, 0})

  if world.lineTileCollision(self.targetPosition, teleportPosition) then
    stateData.timerActive = true
    stateData.timer = 0
  else
    sanctusTeleport(
      teleportPosition,
      0,
      function()
        razortailMeleeCombo.windup(stateData)
      end)
  end
end

function razortailMeleeCombo.windup(stateData)
  local currentStep = stateData.attackSequence[stateData.sequenceStep]

  if stateData.sequenceStep == 1 then
    animator.burstParticleEmitter("eyeSparkMeleeCombo")
    playSound("eyeSpark")
  end

  local animation = currentStep.windupState
  animator.setAnimationState("body", animation)
  wait(
    currentStep.windupDuration,
    function(dt, timer)
      mcontroller.setVelocity({0, 0})
    end,
    function()
      razortailMeleeCombo.attack(stateData)
    end)
end

function razortailMeleeCombo.attack(stateData)
  local currentStep = stateData.attackSequence[stateData.sequenceStep]

  local directionToPlayer = util.toDirection(world.distance(self.targetPosition, mcontroller.position())[1])
  mcontroller.addMomentum({directionToPlayer * currentStep.attackImpulse, 0})
  mcontroller.controlFace(-directionToPlayer)

  local animation = currentStep.attackState
  animator.setAnimationState("body", animation)

  wait(
    currentStep.damageDuration,
    function(dt, timer)      
      if not mcontroller.onGround() then
        mcontroller.controlApproachXVelocity(0, 800)
      end

      local newConfig = sb.jsonMerge(currentStep.damageConfig, {})
      if currentStep.correctedKnockback then
        newConfig.knockback = {currentStep.damageConfig.knockback * -mcontroller.facingDirection(), 5}
      end
      newConfig.damage = scalePower(newConfig.damage)
      updateDamageSources(newConfig, true)
    end,
    function()
      updateDamageSources(nil)
      stateData.sequenceStep = stateData.sequenceStep + 1
      if razortailMeleeCombo.comboValid(stateData) then
        wait(
          calculateCooldown(currentStep.idleTime),
          nil,
          function()
            razortailMeleeCombo.teleport(stateData)
          end
        )
      else
        stateData.timerActive = true
      end
    end)
end

function razortailMeleeCombo.comboValid(stateData)
  local valid = true

  local dist = world.distance(self.targetPosition, mcontroller.position())
  if (stateData.sequenceStep > #stateData.attackSequence) 
    and hasTarget() then

    valid = false
  end

  return valid
end

function razortailMeleeCombo.leavingState(stateData)
end

  --  or math.abs(dist[1]) > stateData.sequenceBreakDistance[1]
  --  or math.abs(dist[2]) > stateData.sequenceBreakDistance[2]