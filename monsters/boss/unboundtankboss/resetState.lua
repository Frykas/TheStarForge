function bossReset()
  animator.setAnimationState("engine", "on")
  
  animator.setAnimationState("tracks", "idle")
  animator.setAnimationState("rocketLauncher", "idle")
  animator.setAnimationState("barrel", "idle")
  animator.setAnimationState("body", "stage1")
  
  mcontroller.setPosition(config.getParameter("spawnPosition", mcontroller.position()))
end
