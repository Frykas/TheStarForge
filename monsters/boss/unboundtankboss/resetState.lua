function bossReset()
  animator.setAnimationState("engine", "on")
  
  animator.setAnimationState("rocketLauncher", "idle")
  animator.setAnimationState("barrel", "idle")
  animator.setAnimationState("body", "stage1")
  mcontroller.setXVelocity(0)
  
  returnToStartPosition()
end
