require "/scripts/stagehandutil.lua"

function init()
  self.players = {}

  self.currentTrack = config.getParameter("currentTrack")
  -- Ensure currentTrack is a table/array because fuck Starbound seriously
  if self.currentTrack and type(self.currentTrack) == "string" then
    self.currentTrack = { self.currentTrack }
  end

  self.hostEntity = config.getParameter("hostEntity")
  self.timeToLive = config.getParameter("timeToLive")

  message.setHandler("killStagehand", function(_, _) return killStagehand() end)
end

function update(dt)
  if self.hostEntity then
    if world.entityExists(self.hostEntity) then
      stagehand.setPosition(world.entityPosition(self.hostEntity))
    else
      killStagehand()
    end
  end

  if self.timeToLive then
    self.timeToLive = self.timeToLive - dt 
    if self.timeToLive <= 0 then
      killStagehand()
    end
  end

  local newPlayersArray = broadcastAreaQuery({ includedTypes = {"player"} })
  local newPlayers = {}

  for _, playerId in ipairs(newPlayersArray) do
    newPlayers[playerId] = true
  end

  for playerId, _ in pairs(self.players) do
    if not world.entityExists(playerId) then
      self.players[playerId] = nil
    elseif not newPlayers[playerId] then
      world.sendEntityMessage(playerId, "playAltMusic", jarray(), 0.5)
      self.players[playerId] = nil
    end
  end

  for playerId, _ in pairs(newPlayers) do
    if self.hostEntity and not self.players[playerId] then
      world.sendEntityMessage(playerId, "playAltMusic", self.currentTrack or jarray(), 0.5)
      self.players[playerId] = true
    end
  end
end

function killStagehand()
  stagehand.die()
  for playerId, _ in pairs(self.players) do
    world.sendEntityMessage(playerId, "playAltMusic", jarray())
  end
end