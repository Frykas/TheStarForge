require "/scripts/stagehandutil.lua"

function init()
  self.containsPlayers = {}
  self.uniqueIdToMessage = config.getParameter("uniqueIdToMessage")
  self.messageType = config.getParameter("messageType")
  self.messageRadius = config.getParameter("messageRadius", 2)
  self.messageArgs = config.getParameter("messageArgs", {})
  if type(self.messageArgs) ~= "table" then
    self.messageArgs = {self.messageArgs}
  end
end

function update(dt)
  local players = broadcastAreaQuery({ includedTypes = {"player"} })
  if players[1] then
    local entitiesToMessage = world.entityQuery(entity.position(), self.messageRadius)
    for _, entity in pairs(entitiesToMessage) do
	  world.sendEntityMessage(entity, self.messageType, table.unpack(self.messageArgs))
    end
    if config.getParameter("dieOnMessage", false) then
	  stagehand.die()
    end
  end
  self.containsPlayers = players
end
