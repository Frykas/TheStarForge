-- NPC Health Bar by Lyrthras
-- Rest by Nebulox

local oldInit = init or function() end
function init()
  if oldInit then oldInit() end

  self.music = config.getParameter("music")
  if self.music then
    storage.musicPlaying = false
    self.musicStagehands = {}
  end

  self.damageBarActive = config.getParameter("damageBarActive", false)
  if self.damageBarActive then
    storage.companionId = spawnCompanion()

    self.companionSpawnAttempts = 0
  end
end

local oldUpdate = update or function(dt) end
function update(dt)
  if oldUpdate then oldUpdate(dt) end

  if self.music then
    local targetId = self.board:getEntity("target") 
                  or self.board:getEntity("hostileTarget")

    if targetId and world.entityExists(targetId) then
      if not storage.musicPlaying then
        storage.musicPlaying = true
        createMusicStagehand(self.music)
      end
    else
      storage.musicPlaying = false
      cullMusicStagehand()
    end
  end

  if self.damageBarActive then
    if world.entityTypeName(storage.companionId) ~= "starforge-npchealthbar" then
      self.companionSpawnAttempts = self.companionSpawnAttempts + 1
      storage.companionId = spawnCompanion()
      if not storage.companionId or self.companionSpawnAttempts > 33 then    -- prevent spam
        error("Repeated failure in spawning companion monster, terminating...")
      end
    end
    
    if config.getParameter("nameTag") then
      npc.setDisplayNametag(config.getParameter("nameTag"))
    end

    world.callScriptedEntity(storage.companionId, "status.setResourcePercentage", "health", status.resourcePercentage("health"))
    world.callScriptedEntity(storage.companionId, "mcontroller.setPosition", mcontroller.position())
  end
end

function spawnCompanion()
  return world.spawnMonster("starforge-npchealthbar", entity.position(), {
    shortdescription = config.getParameter("bossName", npc.npcType()),
    trackingNpc = entity.id()
  })
end

function cullMusicStagehand(track)
  for stagehand, stagehandTrack in pairs(self.musicStagehands) do
    if (not track) or (stagehandTrack == track) then
      world.sendEntityMessage(stagehand, "killStagehand")
      self.musicStagehands[stagehand] = nil
    end
  end
end

function createMusicStagehand(track, timeToLive)
  local valid = true
  for stagehand, stagehandTrack in pairs(self.musicStagehands) do
    if stagehandTrack == track then
      valid = false
    end
  end
  if valid then
    local stagehand = world.spawnStagehand(mcontroller.position(), "starforge-bossmusic", {
      broadcastArea = config.getParameter("musicBounds", {-100, -50, 100, 50}),
      hostEntity = entity.id(),
      currentTrack = track,
      timeToLive = timeToLive
    })
    self.musicStagehands[stagehand] = track
  end
end
