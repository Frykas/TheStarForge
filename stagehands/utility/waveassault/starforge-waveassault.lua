require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/stagehandutil.lua"

function init()
  self.validEntityTypes = {"monster", "npc"}
  
  self.enemyCount = config.getParameter("enemyCount")
  
  self.npcSpecies = config.getParameter("npcSpecies")
  self.npcTypes = config.getParameter("npcTypes")
  
  self.monsterTypes = config.getParameter("monsterTypes")
  self.testPoly = config.getParameter("testPoly")
  
  self.spawnOnGround = config.getParameter("spawnOnGround")
  self.minDistanceToPlayer = config.getParameter("minDistanceToPlayer")
  self.spawnRangeX = config.getParameter("spawnRangeX")
  self.spawnRangeY = config.getParameter("spawnRangeY")
  self.spawnTolerance = config.getParameter("spawnTolerance")
  
  self.spawnEffects = config.getParameter("spawnEffects")
  self.waveTime = config.getParameter("waveTime")
  self.waves = config.getParameter("waves")
  self.timer = 0
  
  self.validTypes = {}
  if self.monsterTypes and #self.monsterTypes > 0 then
    table.insert(self.validTypes, "monster")
  end
  if self.npcTypes and #self.npcTypes > 0 then
    table.insert(self.validTypes, "npc")
  end
  
  self.startMessages = config.getParameter("startMessages")
  self.endMessages = config.getParameter("endMessages")
  self.resetMessages = config.getParameter("resetMessages")
  self.messageRadius = config.getParameter("messageRadius", 2)
  
  self.hasSpawnedEnemies = false
  
  self.active = config.getParameter("startActive", false)
  self.delayTime = config.getParameter("delayTime", 0)
  
  message.setHandler("starforge-setwaveactive", function(_, _, delay)
	self.delayTime = delay
  end)
end

function update(dt)
  if self.active then updateArena(dt) end
  
  if self.player and not self.active and self.delayTime > 0 then
    self.delayTime = math.max(0, self.delayTime - dt)
	if self.delayTime == 0 then
	  self.active = true
	end
  end
  
  local playersFound = broadcastAreaQuery({
    includedTypes = {"player"}
  })
  if #playersFound == 0 then
    reset()
  end
  if not self.player then
	self.player = playersFound[1]
	
	if self.startMessages and self.player then
	  for _, message in ipairs(self.startMessages) do
	    local entitiesToMessage = world.entityQuery(stagehand.position(), self.messageRadius)
	    for _, entity in pairs(entitiesToMessage) do
          world.sendEntityMessage(entity, message)
        end
	  end
	end
  end
end

function reset()
  self.player = nil
  self.waveTime = config.getParameter("waveTime")
  self.waves = config.getParameter("waves")
  self.timer = 0
  
  self.hasSpawnedEnemies = false
	
  if self.progressBarId then
    world.sendEntityMessage(self.progressBarId, "starforge-reset")
	self.progressBarId = nil
  end
  
  --Cull existing monsters
  local remainingMonsters = broadcastAreaQuery({
    includedTypes = self.validTypes
  })
  for _, enemy in pairs(remainingMonsters) do
	world.sendEntityMessage(enemy, "applyStatusEffect", "starforge-terminate")
  end
  
  for _, message in ipairs(self.resetMessages) do
    local entitiesToMessage = world.entityQuery(stagehand.position(), self.messageRadius)
    for _, entity in pairs(entitiesToMessage) do
	  world.sendEntityMessage(entity, message)
    end
  end
end

function updateArena(dt)
  if self.player and not self.progressBarId then
    self.progressBarId = world.spawnVehicle("starforge-progressbar", vec2.add(stagehand.position(), config.getParameter("progressBarPosition", {0.5, 0})))
  end
  
  if self.survivalTimer then
    self.survivalTimer = math.max(0, self.survivalTimer - dt)
  end
  
  if self.hasSpawnedEnemies then
    local entitiesFound = broadcastAreaQuery({
      includedTypes = self.validEntityTypes
    })
    for x, entity in pairs(entitiesFound) do
      if not world.entityCanDamage(entity, self.player) then
        table.remove(entitiesFound, x)
      end
	  if world.entityType(entity) == "player" then
        table.remove(entitiesFound, x)
	  end
    end
    world.debugText("Enemies Left: %s", entitiesFound, vec2.add(stagehand.position(), {0, 5}), "yellow")
    if #entitiesFound == 0 then
	  if not self.hasTriggeredWave and not self.survivalTimer then
	    self.waves = self.waves - 1
		self.hasTriggeredWave = true
	  end
      self.timer = math.max(0, self.timer - dt)
      if self.timer == 0 then
        self.hasSpawnedEnemies = false
		self.hasTriggeredWave = false
      end
    end
  elseif self.player and self.waves > 0 then
    for i = 1, math.random(self.enemyCount[1], self.enemyCount[2]) do
      --Calculate initial x and y offset for the spawn position
      local xOffset = math.random() * self.spawnRangeX
      xOffset = xOffset * util.randomChoice({-1, 1})
      local yOffset = math.random(0, self.spawnRangeY) + config.getParameter("yOffset", 0)
      local position = vec2.add(entity.position(), {xOffset, yOffset})
      
      --Optionally correct the position by finding the ground below the projected position
      local correctedPositionAndNormal = {position, nil}
      if self.spawnOnGround then
        correctedPositionAndNormal = world.lineTileCollisionPoint(position, vec2.add(position, {0, -50})) or {position, 0}
      end
	  
	  --Resolve the NPC poly collision to ensure that we can place an NPC at the designated position
	  local resolvedPosition = world.resolvePolyCollision(self.testPoly, correctedPositionAndNormal[1], self.spawnTolerance)
      
      if resolvedPosition then
        --Spawn the monster and optionally force the monster spawn effect on them
		local entityId = spawnEntity(util.randomChoice(self.validTypes), resolvedPosition)
		for _, effect in pairs(self.spawnEffects) do
		  world.sendEntityMessage(entityId, "applyStatusEffect", effect)
        end
      end
    end
    self.timer = self.waveTime
    self.hasSpawnedEnemies = true
  end
  
  if self.player and self.progressBarId then
    if self.survivalTimer then
	  world.sendEntityMessage(self.progressBarId, "starforge-setprogress", 1 - self.survivalTimer / config.getParameter("survivalTime"), self.survivalTime == 0)
    else
	  world.sendEntityMessage(self.progressBarId, "starforge-setprogress", 1 - self.waves / config.getParameter("waves"), self.waves == 0)
    end
  end
  
  if self.survivalTimer == 0 or self.waves == 0 then
	stagehand.die()
	
	for _, message in ipairs(self.endMessages) do
	  local entitiesToMessage = world.entityQuery(stagehand.position(), self.messageRadius)
	  for _, entity in pairs(entitiesToMessage) do
        world.sendEntityMessage(entity, message)
      end
	end
  end
end

function spawnEntity(type, pos)
  if type == "npc" then
    return world.spawnNpc(pos, util.randomChoice(self.npcSpecies), util.randomChoice(self.npcTypes), world.threatLevel())
  elseif type == "monster" then
	return world.spawnMonster(util.randomChoice(self.monsterTypes), pos, {level = world.threatLevel(), aggressive = true})
  end
end
