require "/scripts/stagehandutil.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

--NEEDS A REWORK

function init()
  --Projectile stuffs
  self.projectileType = config.getParameter("projectileType", "electrictrail")
  self.projectileParameters = config.getParameter("projectileParameters", {})
  self.projectileCount = config.getParameter("projectileCount", 1)
  self.aimAccuracyFactor = config.getParameter("aimAccuracyFactor", 1)
  self.projectileTime = config.getParameter("projectileTime", {0.1, 1})
  self.projectileTimer = self.projectileTime[1]
  self.persistent = config.getParameter("persistent", false)
  self.alwaysAimUp = config.getParameter("alwaysAimUp")
  
  --Liquid scanning
  self.ignoreLiquidType = config.getParameter("ignoreLiquidType", true)  
  self.liquidWhitelist = config.getParameter("liquidWhitelist", {})
  self.minimumLiquidLevel = config.getParameter("minimumLiquidLevel", 0.75)
  self.onlyConsiderSurface = config.getParameter("onlyConsiderSurface", false)
  self.scanFrequency = 5
  self.scanTimer = 0

  self.playerScanRadius = 100
  
  self.timeToExist = config.getParameter("timeToExist")
  reset()
end

function update(dt)
  local active = #world.playerQuery(stagehand.position(), self.playerScanRadius)

  self.projectileTimer = math.max(0, self.projectileTimer - dt)
  if self.projectileTimer == 0 and active then
	  spawnProjectile(self.onlyConsiderSurface and self.liquidSurfaceSpaces or self.liquidSpaces)
    self.projectileTimer = math.random() * self.projectileTime[2] - self.projectileTime[1]
  end
  
  if self.timeToExist then
    self.timeToExist = math.max(0, self.timeToExist - dt)
    if self.timeToExist == 0 then
	    stagehand.die()
    end
  end

  self.scanTimer = math.max(0, self.scanTimer - dt)
  if self.scanTimer == 0 and active then
    reset()
  end

  for _, space in ipairs(self.liquidSurfaceSpaces) do
    world.debugPoint(vec2.add(space, {0, 0.5}), "yellow")
  end
  for _, space in ipairs(self.liquidSpaces) do
    world.debugPoint(space, "red")
  end
end

function spawnProjectile(table)
  if #table == 0 then return false end

  local params = sb.jsonMerge(self.projectileParameters, {})

  local projectileType = self.projectileType
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  params.power = (params.power or 0) + world.threatLevel()

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    local projectilePosition = table[math.ceil(math.random() * #table)]
    local positionVariance = {math.random() * 1 - 0.5, math.random() * 1 - 0.5}
    local position = vec2.add(projectilePosition or stagehand.position(), positionVariance)
	
    local aimVec = {0, 1}
    aimVec = vec2.rotate(aimVec, math.random() * math.pi * self.aimAccuracyFactor * util.randomDirection())

    projectileId = world.spawnProjectile(
        projectileType,
        position,
        nil,
        aimVec,
        false,
        params
      )
  end
  return projectileId
end

function checkSpace(position, ignoreAdjacent)
  --Check liquid spots
  local liquid = world.liquidAt(position)
  local liquidAbove = world.liquidAt(vec2.add(position, {0, 1}))
  local liquidBelow = world.liquidAt(vec2.add(position, {0, -1}))
  local liquidLeft = world.liquidAt(vec2.add(position, {-1, 0}))
  local liquidRight = world.liquidAt(vec2.add(position, {1, 0}))
  local materialAbove = world.material(vec2.add(position, {0, 1}), "foreground")
  
  local validLiquid = self.ignoreLiquidType
  if not liquid then
    if not self.persistent then 
      stagehand.die() 
    end
    validLiquid = false
  end
  for _, id in ipairs(self.liquidWhitelist) do
    if liquid and liquid[1] == id then
      validLiquid = true
    end
  end

  if not validLiquid then
    return false
  end
  
  --Check if the liquid at the position is the surface of the liquid
  local isLiquidSurface = false
  if liquid then
    if not isDuplicate(position, self.liquidSpaces) then
      table.insert(self.liquidSpaces, position)
    end
    if not materialAbove then
      --If there is no liquid above and liquid is over minimum liquid level
      if liquid[2] > self.minimumLiquidLevel and not liquidAbove then
        isLiquidSurface = true
      --If the same liquid is also below and the liquid above is not full
      elseif liquidBelow and liquidBelow[1] == liquid[1] and not liquidAbove then
        isLiquidSurface = true
      end
    end
  end
  
  --Check adjacent spots if they also have liquid
  if not ignoreAdjacent then
    if liquidAbove and not isDuplicate(vec2.add(position, {0, 1})) then
      checkSpace(vec2.add(position, {0, 1}))
    end
    if liquidBelow and not isDuplicate(vec2.add(position, {0, -1})) then
      checkSpace(vec2.add(position, {0, -1}))
    end
    if liquidLeft and not isDuplicate(vec2.add(position, {-1, 0})) then
      checkSpace(vec2.add(position, {-1, 0}))
    end
    if liquidRight and not isDuplicate(vec2.add(position, {1, 0})) then
      checkSpace(vec2.add(position, {1, 0}))
    end
  end
  
  --Add to liquid surface table if needed
  if isLiquidSurface then
    if not isDuplicate(position, self.liquidSurfaceSpaces) then
      table.insert(self.liquidSurfaceSpaces, position)
    end
  end
  
  return (liquid ~= nil)
end

function reset()
  self.liquidSpaces = {}
  self.liquidSurfaceSpaces = {}
  local isActive = checkSpace(vec2.add(vec2.floor(entity.position()), {0.5, 0.5}))
  if not isActive and not self.persistent then
    stagehand.die()
  end
  self.scanTimer = self.scanFrequency
end

function isDuplicate(vector, table)
  local spaceExists = false
  for _, space in ipairs(table or self.liquidSpaces) do
    if vec2.eq(space, vector) then
	    spaceExists = true
    end
  end
  return spaceExists
end