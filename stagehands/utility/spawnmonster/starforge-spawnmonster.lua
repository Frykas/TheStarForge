require "/scripts/vec2.lua"

function init()
  self.monsterConfigs = config.getParameter("monsterConfigs", {})
  self.owner = config.getParameter("owner")
  self.trackEntities = config.getParameter("trackEntities")
  self.forceSpawnPos = config.getParameter("forceSpawnPos")
end

function update()
  if not self.spawnedMonsters then
    self.spawnedMonsters = {}
    for i, monsterConfig in ipairs(self.monsterConfigs) do
      local resolvedPosition = world.resolvePolyCollision(config.getParameter("monsterTestPoly"), vec2.add(entity.position(), monsterConfig.spawnOffset), config.getParameter("spawnTolerance"))

      local monsterParams = sb.jsonMerge(monsterConfig.monsterParameters, {})
      if monsterConfig.uuid then
        monsterParams.uniqueId = monsterConfig.uuid
      end

      if self.owner then
        local damageTeam = world.entityDamageTeam(self.owner)
        monsterParams.damageTeam = damageTeam.team
        monsterParams.damageTeamType = damageTeam.type
        monsterParams.aggressive = monsterParams.aggressive or true
      end
        
      local spawnedMonsterId = world.spawnMonster(monsterConfig.monsterType, self.forceSpawnPos and vec2.add(entity.position(), monsterConfig.spawnOffset) or resolvedPosition, monsterParams)

      if spawnedMonsterId then        
        self.spawnedMonsters[i] = spawnedMonsterId

        for _, spawnEffect in ipairs(monsterConfig.spawnEffects) do
          world.callScriptedEntity(spawnedMonsterId, "status.addEphemeralEffect", spawnEffect, nil, entity.id())
        end
      end
    end
  end
  if self.spawnedMonsters and not self.trackEntities then
    stagehand.die()
  end

  if self.spawnedMonsters and self.trackEntities and world.entityExists(self.trackEntities) then
    stagehand.setPosition(world.entityPosition(self.trackEntities))
    for i = 1, #self.spawnedMonsters do
      if not world.entityExists(self.spawnedMonsters[i]) then
        self.spawnedMonsters[i] = nil
      end
    end
    if #self.spawnedMonsters == 0 then
      stagehand.die()
    end
  end
end
