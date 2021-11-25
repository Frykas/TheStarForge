require "/scripts/stagehandutil.lua"
require "/scripts/vec2.lua"

function init()
  --Projectile stuffs
  self.projectileType = config.getParameter("projectileType", "electrictrail")
  self.projectileParameters = config.getParameter("projectileParameters", {})
  self.projectileCount = config.getParameter("projectileCount", 1)
  self.projectileTime = config.getParameter("projectileTime", {0.1, 1})
  self.projectileTimer = self.projectileTime[1]
  
  --Liquid scanning
  self.ignoreLiquidType = config.getParameter("ignoreLiquidType", true)  
  self.liquidWhitelist = config.getParameter("liquidWhitelist", {})
  self.minimumLiquidLevel = config.getParameter("minimumLiquidLevel", 0.75)
  self.onlyConsiderSurface = config.getParameter("onlyConsiderSurface", false)
  self.scanFrequency = 10
  self.scanTimer = 0
  
  self.timeToExist = config.getParameter("timeToExist")
  
  world.entityType(entity.id())
  reset()
end

function update(dt)
  self.projectileTimer = math.max(0, self.projectileTimer - dt)
  if self.projectileTimer == 0 then
	spawnProjectile(self.liquidSpaces)
    self.projectileTimer = math.random() * self.projectileTime[2] - self.projectileTime[1]
  end
  
  if self.timeToExist then
	self.timeToExist = math.max(0, self.timeToExist - dt)
	if self.timeToExist == 0 then
	  stagehand.die()
    end
  end

  --if self.scanTimer == 0 then
  --  reset()
  --end
  for _, space in ipairs(self.liquidSurfaceSpaces) do
    world.debugPoint(vec2.add(space, {0, 0.5}), "yellow")
  end
  for _, space in ipairs(self.liquidSpaces) do
    world.debugPoint(space, "red")
  end
end

function spawnProjectile(table)	
  local params = sb.jsonMerge(self.projectileParameters, {})

  local projectileType = self.projectileType
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    local projectilePosition = table[math.ceil(math.random() * #table)]
    local positionVariance = {math.random() * 1 - 0.5, math.random() * 1 - 0.5}
    local position = vec2.add(projectilePosition, positionVariance)
	
	local aimVec = vec2.rotate({0, 1}, math.random() * math.pi)

    projectileId = world.spawnProjectile(
        projectileType,
        position,
        entity.id(),
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
  for _, id in ipairs(self.liquidWhitelist) do 
    if liquid[1] == id then
	  validLiquid = true
	end
  end
  if not validLiquid then
    return false
  end
  
  --Check if the liquid at the position is the surface of the liquid
  local isLiquidSurface = false
  if liquid then
	if not self.onlyConsiderSurface and not isDuplicate(position, self.liquidSpaces) then
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
  if not isActive then
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