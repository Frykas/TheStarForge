local baseUpdate = update
function update(dt) baseUpdate(dt)
  self.onGround = mcontroller.groundMovement() or mcontroller.onGround()
  --world.debugText("%s", self.sleepTimer or 0, mcontroller.position(), "green")
  if not hasTarget() then
    self.sleepTimer = math.max(0, (self.sleepTimer or 0) - dt)
    if self.sleepTimer == 0 and animator.animationState("body") ~= "sleeping" then
      animator.setAnimationState("body", "sleeping")
      self.awake = false
    end
    return false
  elseif hasTarget() and not self.awake then
    self.sleepTimer = 5
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
