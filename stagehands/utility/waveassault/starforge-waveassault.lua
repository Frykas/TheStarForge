require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/stagehandutil.lua"

function init()
  self.validEntityTypes = {"monster", "npc"}
  
  self.npcSpecies = config.getParameter("npcSpecies")
  self.npcTypes = config.getParameter("npcTypes")
  
  self.monsterTypes = config.getParameter("monsterTypes")
  self.monsterCount = config.getParameter("monsterCount")
  self.monsterTestPoly = config.getParameter("monsterTestPoly")
  
  self.spawnOnGround = config.getParameter("spawnOnGround")
  self.minDistanceToPlayer = config.getParameter("minDistanceToPlayer")
  self.spawnRangeX = config.getParameter("spawnRangeX")
  self.spawnRangeY = config.getParameter("spawnRangeY")
  self.spawnTolerance = config.getParameter("spawnTolerance")
  
  self.spawnEffects = config.getParameter("spawnEffects")
  self.waveTime = config.getParameter("waveTime")
  
  self.hasSpawnedEnemies = false
end

function update(dt)
  if not self.player then
    local playersFound = broadcastAreaQuery({
      includedTypes = {"player"}
    })
	self.player = playersFound[1]
  end
  
  if self.hasSpawnedEnemies then
    local enemiesFound = broadcastAreaQuery({
      includedTypes = self.validEntityTypes
    })
    for x, monster in pairs(enemiesFound) do
      if world.entityCanDamage(monster, self.player) then
        table.remove(enemiesFound, x)
      end
	  if monster == self.player then
        table.remove(enemiesFound, x)
	  end
    end
    if #enemiesFound == 0 then
      self.timer = math.max(0, self.timer - dt)
      if self.timer == 0 then
        self.hasSpawnedEnemies = false
      end
    end
  elseif self.player then
    for i = 1, math.random(self.monsterCount[1], self.monsterCount[2]) do
      --Calculate initial x and y offset for the spawn position
      local xOffset = math.random(self.minDistanceToPlayer, self.spawnRangeX)
      xOffset = xOffset * util.randomChoice({-1, 1})
      local yOffset = math.random(0, self.spawnRangeY)
      local position = vec2.add(entity.position(), {xOffset, yOffset})
      
      --Optionally correct the position by finding the ground below the projected position
      local correctedPositionAndNormal = {position, nil}
      if self.spawnOnGround then
        correctedPositionAndNormal = world.lineTileCollisionPoint(position, vec2.add(position, {0, -50})) or {position, 0}
      end
      
      --Resolve the monster poly collision to ensure that we can place an monster at the designated position
      local resolvedPosition = world.resolvePolyCollision(self.monsterTestPoly, correctedPositionAndNormal[1], self.spawnTolerance)
      
      if resolvedPosition then
        --Spawn the monster and optionally force the monster spawn effect on them
        local entityId = world.spawnMonster(util.randomChoice(self.monsterTypes), resolvedPosition, {level = world.threatLevel(), aggressive = true})
		for _, effect in pairs(self.spawnEffects) do
		  world.sendEntityMessage(entity, "applyStatusEffect", effect)
        end
      end
    end
    self.timer = self.waveTime
    self.hasSpawnedEnemies = true
  end
end
