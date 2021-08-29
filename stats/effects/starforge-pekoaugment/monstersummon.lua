--made by Nebulox 

require "/scripts/util.lua"

function init()
  self.monsterType = config.getParameter("monsterType")
  self.monsterParameters = config.getParameter("monsterParameters", {})
  self.droneCount = config.getParameter("droneCount", {})

  self.droneIds = {}
end


function update(dt)
  updateDrones()

  if #self.droneIds < self.droneCount then
    local damageTeam = entity.damageTeam()
	
    local params = self.monsterParameters
    params.level = config.getParameter("monsterLevel", 1)
    params.damageTeam = damageTeam.team
    params.damageTeamType = damageTeam.type
	params.aggressive = true
    params.parentEntity = entity.id()
	
	world.spawnProjectile("alliancecenturiondroneteleport", releasePosition())
    --Spawn the drone
    local droneId = world.spawnMonster(
	  self.monsterType,
	  releasePosition(),
	  params
    )
	
    table.insert(self.droneIds, droneId)
  end
end

function uninit()
  --Cull drones upon removal of status
  for _, drone in ipairs(self.droneIds) do
	world.sendEntityMessage(drone, "despawn")
  end
end

function releasePosition()
  return world.entityMouthPosition(entity.id()) or world.entityPosition(entity.id()) or mcontroller.position()
end

function updateDrones()
  --Check if drones are alive
  self.droneIds = util.filter(self.droneIds, function(droneId)
	if world.entityExists(droneId) then
	  return true
	end
	return false
  end)
  
  --sb.logInfo("Current drones: %s", self.droneIds)
end