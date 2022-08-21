function init()
  recoil = 0
  recoilRate = 0
  fireOffset = config.getParameter("fireOffset")
  active = false
  storage.fireTimer = storage.fireTimer or 0
end

function update(dt)
  updateAim()

  storage.fireTimer = math.max(storage.fireTimer - dt, 0)

  if active then
    recoilRate = 0
  else
    recoilRate = math.max(1, recoilRate + (10 * dt))
  end
  recoil = math.max(recoil - dt * recoilRate, 0)

  if active and not storage.firing and storage.fireTimer <= 0 then
    recoil = math.pi/2 - aimAngle
    activeItem.setArmAngle(math.pi/2)
    if animator.animationState("firing") == "off" then
      animator.setAnimationState("firing", "fire")
    end
    storage.fireTimer = config.getParameter("fireTime", 1.0)
    storage.firing = true

  end

  active = false

  if storage.firing and animator.animationState("firing") == "off" then
    item.consume(1)
    if player then
      local treasure = root.createTreasure(config.getParameter("treasure.pool"), config.getParameter("treasure.level"), config.getParameter("treasure.seed"))
      for _,item in pairs(treasure) do
        player.giveItem(item)
      end
    end
    storage.firing = false
    return
  end
end

function activate()
  if not storage.firing then
    active = true
  end
end

function updateAim()
  aimAngle, aimDirection = activeItem.aimAngleAndDirection(fireOffset, activeItem.ownerAimPosition())
  aimAngle = aimAngle + recoil
  activeItem.setArmAngle(aimAngle)
  activeItem.setFacingDirection(aimDirection)
end
