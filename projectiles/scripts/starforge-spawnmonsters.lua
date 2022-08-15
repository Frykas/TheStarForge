require "/scripts/vec2.lua"

function init()
  local spawnPositions = config.getParameter("spawnPositions", {0,0})
  local spawnEffect = config.getParameter("spawnEffect", {"starforge-fadein", 0.5})
  --Spawn the monsters
  for i = 1, #spawnPositions do
	--Resolve the monster poly collision to ensure that we can place an monster at the designated position
	local resolvedPosition = world.resolvePolyCollision(config.getParameter("monsterTestPoly"), vec2.add(entity.position(), spawnPositions[i]), config.getParameter("spawnTolerance"))
	--Spawn monster and apply spawn effect
    local entityId = world.spawnMonster(config.getParameter("monsterType", "starforge-alabatling"), resolvedPosition, {level = world.threatLevel(), aggressive = true})
    world.callScriptedEntity(entityId, "status.addEphemeralEffect", spawnEffect[1], spawnEffect[2])
  end
end