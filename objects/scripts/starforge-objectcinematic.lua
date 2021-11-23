require "/scripts/vec2.lua"

function init()
  knownPlayers = {}
  message = config.getParameter("messageType","playCinematic")
  data = config.getParameter("messageData","/cinematics/beamaxe.cinematic")
end

function update(dt)
  local players = world.players()
  if #players > 0 then
    for i = 1, #players do
      if not knownPlayers[players[i]] then
      world.sendEntityMessage(players[i],messageType,messageData)
      knownPlayers[players[i]] = true
      end
    end
  end
end