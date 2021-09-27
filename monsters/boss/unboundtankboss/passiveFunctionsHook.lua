local oldUpdate = update
function update(dt, ...)
  if status.resourcePositive("health") and animator.animationState("tracks") == "moving" then
    mcontroller.setXVelocity(config.getParameter("movementSpeed", 15) * (status.resource("health") / status.resource("maxhealth")))
  elseif not status.resourcePositive("health") then
    animator.setAnimationState("tracks", "idle")
    mcontroller.setXVelocity(0)
  elseif animator.animationState("tracks") ~= "moving" then
    animator.setAnimationState("tracks", "moving")
  end
  
  return oldUpdate(dt, ...)
end