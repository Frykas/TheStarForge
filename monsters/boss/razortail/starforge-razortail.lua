local baseInit = init
function init() baseInit()
  animator.resetTransformationGroup("all")

  self.sleepTime = config.getParameter("targetResetTime", 2)

  storage.spawnPosition = storage.spawnPosition or mcontroller.position()
end

local baseUpdate = update
function update(dt) baseUpdate(dt)
  if self.healthCooldownFactor then
    self.cooldownFactor = self.healthCooldownFactor[1] + (status.resourcePercentage("health") * (self.healthCooldownFactor[2] - self.healthCooldownFactor[1]))
  end

  if not storage.sleepingInvulnerable and animator.animationState("body") == "sleeping" then
    status.addPersistentEffect("starforge-razortailSleeping", "invulnerable")
    storage.sleepingInvulnerable = true
  elseif storage.sleepingInvulnerable and animator.animationState("body") ~= "sleeping" then
    status.clearPersistentEffects("starforge-razortailSleeping")
    storage.sleepingInvulnerable = false
  end

  self.onGround = mcontroller.groundMovement() or mcontroller.onGround()
  --world.debugText("%s", self.sleepTimer or 0, mcontroller.position(), "green")
  if not hasTarget() then
    self.sleepTimer = math.max(0, (self.sleepTimer or 0) - dt)
    if self.sleepTimer == 0 and animator.animationState("body") ~= "sleeping" then
      self.sleepTimer = self.sleepTime
      sanctusTeleport(storage.spawnPosition,
      0,
      function()
        animator.setAnimationState("body", "sleeping")
        self.awake = false
      end)
    end
    return false
  elseif hasTarget() and not self.awake then
    self.sleepTimer = self.sleepTime
    local directionToPlayer = util.toDirection(world.distance(mcontroller.position(), self.targetPosition)[1])
    mcontroller.controlFace(directionToPlayer)
    animator.setAnimationState("body", "jumping")
    mcontroller.setVelocity({directionToPlayer * 15, 25})
    self.awake = true
  end

  if self.onGround and (animator.animationState("body") == "falling" or animator.animationState("body") == "jumping") then
    animator.setAnimationState("body", "idle")
  elseif not self.onGround and (animator.animationState("body") == "idle" or animator.animationState("body") == "falling" or animator.animationState("body") == "jumping") then
    if mcontroller.yVelocity() > 0 then
      animator.setAnimationState("body", "jumping")
    else
      animator.setAnimationState("body", "falling")
    end
  end
end

function calculateCooldown(time, minTime)
  local newTime = math.max(minTime or (self.healthCooldownFactor and self.healthCooldownFactor[3]) or 0.15, time * (self.cooldownFactor or 1))
  return newTime
end