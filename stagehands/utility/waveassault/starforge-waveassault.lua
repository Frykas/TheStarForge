require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/stagehandutil.lua"

function init()
  --Init all variables
  self.enemyCount = config.getParameter("enemyCount")
  
  self.npcSpecies = config.getParameter("npcSpecies")
  self.npcTypes = config.getParameter("npcTypes")
  
  self.monsterTypes = config.getParameter("monsterTypes")
  self.testPoly = config.getParameter("testPoly")
  
  self.spawnOnGround = config.getParameter("spawnOnGround")
  self.minDistanceToPlayer = config.getParameter("minDistanceToPlayer")
  self.spawnRange = config.getParameter("spawnRange")
  self.spawnTolerance = config.getParameter("spawnTolerance")
  
  self.spawnEffects = config.getParameter("spawnEffects")
  self.waveTime = config.getParameter("waveTime")
  self.totalWaves = config.getParameter("waveCount")
  self.remainingWaves = self.totalWaves
  self.waveTimer = self.waveTime
  
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
  
  self.currentEnemies = {}
  
  self.active = config.getParameter("startActive", false)
  self.delayTime = config.getParameter("delayTime", 0)
  
  message.setHandler("starforge-setWaveActive", function(_, _, delay)
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
  
  checkPlayers()
end

function reset()
  --Reset values
  self.player = nil
  self.waveTime = config.getParameter("waveTime")
  self.remainingWaves = self.totalWaves
  self.waveTimer = self.waveTime
  
  --Cull the progress bar
  if self.progressBarId then
    world.sendEntityMessage(self.progressBarId, "starforge-reset")
	self.progressBarId = nil
  end
  
  --Cull existing monsters
  for _, enemy in pairs(self.currentEnemies) do
	world.sendEntityMessage(enemy, "applyStatusEffect", "starforge-terminate")
  end
  self.currentEnemies = {}
  
  --Send out reset messages
  messageNearbyEntities(self.resetMessages)
end

function updateArena(dt)
  --Update progress bar and spawn it if we haven't already
  if self.player and not self.progressBarId then
    self.progressBarId = world.spawnMonster("starforge-progressbar", vec2.add(stagehand.position(), config.getParameter("progressBarPosition", {0.5, 0})), { totalProgress = self.totalWaves })
    updateProgress()
  end
  
  --Handle when a wave ends, and whether it is still ongoing
  if #self.currentEnemies > 0 then
    --Check our memory of our enemies, and see if they're alive, if not, remove them from our memory
	for x, entityId in pairs(self.currentEnemies) do
	  if not world.entityExists(entityId) then
        table.remove(self.currentEnemies, x)
	  end
	end
  --If there are not alive enemies, there are still remaining waves and the timer is active, count down to spawn a new set of enemies
  elseif self.player and self.remainingWaves > 0 and self.waveTimer > 0 then
    self.waveTimer = math.max(0, self.waveTimer - dt)
    if self.waveTimer == 0 then
      spawnEnemies()
    end
  --If there are no enemies, and the timer is not active, count down the current waves, and activate the timer
  elseif #self.currentEnemies == 0 and self.waveTimer == 0 then
	self.remainingWaves = self.remainingWaves - 1
    updateProgress()
    self.waveTimer = self.waveTime
  end
  
  --If we have completed, send the end messages, and die
  if self.remainingWaves == 0 then
    updateProgress()
	messageNearbyEntities(self.endMessages)
	stagehand.die()
  end
end

function updateProgress()
  if self.player and self.progressBarId then
    world.sendEntityMessage(self.progressBarId, "starforge-setProgress", self.totalWaves - self.remainingWaves)
  end
end

function checkPlayers()
  local playersFound = broadcastAreaQuery({ includedTypes = {"player"} })
  if #playersFound == 0 then
    reset()
  elseif not self.player then
	self.player = playersFound[1]
	
	if self.startMessages and self.player then
	  messageNearbyEntities(self.startMessages)
	end
  end
end

function messageNearbyEntities(messagesToSend)
  --Find all nearby entities and send them a set of messages
  local entitiesToMessage = world.entityQuery(stagehand.position(), self.messageRadius)	
  for _, entity in pairs(entitiesToMessage) do
	for _, message in ipairs(messagesToSend) do
      world.sendEntityMessage(entity, message)
    end
  end
end

function spawnEnemies()
  for i = 1, math.random(self.enemyCount[1], self.enemyCount[2]) do
    --Calculate initial x and y offset for the spawn position
    local xOffset = math.random() * self.spawnRange[1]
    xOffset = xOffset * util.randomChoice({-1, 1})
    local yOffset = math.random(0, self.spawnRange[2]) + config.getParameter("yOffset", 0)
    local position = vec2.add(entity.position(), {xOffset, yOffset})
  
    --Optionally correct the position by finding the ground below the projected position
    local correctedPositionAndNormal = {position, nil}
    if self.spawnOnGround then
	  correctedPositionAndNormal = world.lineTileCollisionPoint(position, vec2.add(position, {0, -50})) or {position, 0}
    end
  
    --Resolve the NPC poly collision to ensure that we can place an NPC at the designated position
    local resolvedPosition = world.resolvePolyCollision(self.testPoly, correctedPositionAndNormal[1], self.spawnTolerance)
  
    if resolvedPosition then
	  --Spawn the enemy and optionally force the enemy spawn effect on them
	  local entityId = spawnEntity(util.randomChoice(self.validTypes), resolvedPosition)
	  for _, effect in pairs(self.spawnEffects) do
	    world.sendEntityMessage(entityId, "applyStatusEffect", effect)
	  end
	  --Insert to memory of all enemies
	  table.insert(self.currentEnemies, entityId)
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
