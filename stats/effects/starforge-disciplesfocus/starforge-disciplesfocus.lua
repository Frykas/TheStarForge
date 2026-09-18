require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/status.lua"

function init()
  animator.setGlobalTag("colour", "?brightness=0")

  self.minimumDamageToTrigger = config.getParameter("minimumDamageToTrigger", 5)
  self.range = config.getParameter("range", 25)

  self.maxBrightness = config.getParameter("maxBrightness", 100)
  self.flashTime = config.getParameter("flashTime")
  self.flashTimer = 0

  self.fireTime = config.getParameter("fireTime", 1)
  self.cooldownTimer = self.fireTime
  self.damagePercent = config.getParameter("damagePercent", 0.1)
  self.lastShotsDamaage = 0
  self.projectileCount = config.getParameter("projectileCount", 1)
  self.inaccuracy = config.getParameter("inaccuracy", 0)
  
  self.projectileType = config.getParameter("projectileType", "standardbullet")
  self.projectileParameters = config.getParameter("projectileParameters", {})
  self.trackSourceEntity = config.getParameter("trackSourceEntity", false)

  self.hoverTimer = 0
  self.hoverAmplitude = config.getParameter("hoverAmplitude", 0.25)
  self.hoverCycle = config.getParameter("hoverCycle", 2)
  self.crystalPosition = config.getParameter("crystalPosition", {-0.5, 4})
  
  script.setUpdateDelta(1)

  self.damageGivenListener = damageListener("inflictedDamage", function(notifications)
    for _, notification in pairs(notifications) do
      if canFire(notification) then
        fireProjectile(notification)
        self.flashTimer = self.flashTime
        self.cooldownTimer = self.fireTime
        break
        return
      end
    end
  end)
end

function canFire(notification)
  return (
    self.cooldownTimer == 0
    and (notification.damageDealt 
    and notification.damageDealt > self.minimumDamageToTrigger 
    and math.floor(notification.damageDealt) ~= math.floor(self.lastShotsDamaage))

    and notification.sourceEntityId == entity.id()

    and (notification.targetEntityId 
    and world.entityExists(notification.targetEntityId) 
    and world.magnitude(entity.position(), world.entityPosition(notification.targetEntityId)) < self.range
    and not world.lineTileCollision(firePosition(), world.entityPosition(notification.targetEntityId)))
  )
end

function update(dt)
  self.cooldownTimer = math.max(self.cooldownTimer - dt, 0)

  if self.flashTime then
    self.flashTimer = math.max(self.flashTimer - dt, 0)

    updateBrightness()
  end
  
  self.hoverTimer = self.hoverTimer + dt
  updateTransformationGroup()

  self.damageGivenListener:update()
end

function updateTransformationGroup()
  local yOffset = self.hoverAmplitude * math.sin(self.hoverTimer / (self.hoverCycle / (2 * math.pi)))
  self.currentCrystalOffset = vec2.add(self.crystalPosition, {0, yOffset})
  self.currentCrystalOffset[1] = self.currentCrystalOffset[1] * mcontroller.facingDirection()

  animator.resetTransformationGroup("crystal")
  animator.translateTransformationGroup("crystal", self.currentCrystalOffset)
end

function fireProjectile(notification)
  local params = sb.jsonMerge(self.projectileParameters, params or {})
  params.power = damagePerShot(notification)
  params.powerMultiplier = status.stat("powerMultiplier") or world.threatLevel()

  self.lastShotsDamaage = params.power * params.powerMultiplier

  local baseSpeed = params.speed
  local baseTTL = params.timeToLive
  for i = 1, (projectileCount or self.projectileCount) do
    local projectileType = projectileType or self.projectileType
    if type(projectileType) == "table" then
      projectileType = projectileType[math.random(#projectileType)]
    end
    if baseTTL then
      params.timeToLive = util.randomInRange(baseTTL)
    end
    if baseSpeed then
      params.speed = util.randomInRange(baseSpeed)
    end

    world.spawnProjectile(
      projectileType,
      firePosition(),
      entity.id(),
      aimVector(notification.targetEntityId),
      self.trackSourceEntity,
      params
    )
  end
end

function damagePerShot(notification)
  return (((notification.damageDealt / status.stat("powerMultiplier") or math.max(world.threatLevel(), 1)) + world.threatLevel()) * self.damagePercent + 1) * self.fireTime
end

function firePosition()
  return vec2.add(entity.position(), self.currentCrystalOffset)
end

function updateBrightness()
  local factor = self.flashTimer / self.flashTime
  local brightness = factor * self.maxBrightness
  animator.setGlobalTag("colour", "?brightness=" .. brightness)
end

function aimVector(target)
  local aimAngle = vec2.angle(vec2.sub(world.entityPosition(target), firePosition()))
  local aimVector = vec2.rotate({1, 0}, aimAngle + sb.nrand(self.inaccuracy or 0, 0))
  return aimVector
end

function uninit()
end