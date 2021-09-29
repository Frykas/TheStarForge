local oldUpdate = update
function update(dt, ...)
  if status.resourcePositive("health") and animator.animationState("tracks") == "moving" then
    mcontroller.setXVelocity((config.getParameter("movementSpeed", 16) * (1 - (status.resource("health") / status.resourceMax("health")))) + 2)
  elseif animator.animationState("tracks") ~= "moving" and status.resourcePositive("health") then
    animator.setAnimationState("tracks", "moving")
  elseif not status.resourcePositive("health") or mcontroller.xVelocity() == 0 then
    animator.setAnimationState("tracks", "idle")
    mcontroller.setXVelocity(0)
  end
  
  return oldUpdate(dt, ...)
end