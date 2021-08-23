function init()
  effect.addStatModifierGroup({{stat = "protection", amount = config.getParameter("protection", 0)}})
  script.setUpdateDelta(3)
end

function update(dt)
  animator.setFlipped(mcontroller.facingDirection() == -1)
end

function uninit()
  
end