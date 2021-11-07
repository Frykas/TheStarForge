--------------------------------------------------------------------------------
dieState = {}

function dieState.enterWith(params)
  if not params.die then return nil end
  
  rangedAttack.setConfig(config.getParameter("projectiles.deathexplosion.type"), config.getParameter("projectiles.deathexplosion.config"), 0.2)

  return {
    timer = 3,
  }
end

function dieState.enteringState(stateData)
  --world.objectQuery(mcontroller.position(), 50, { name = "lunarbaselaser", callScript = "openLunarBaseDoor" })

  --Make it look dead
  animator.setAnimationState("engine", "off")
  
  animator.setAnimationState("body", "stage3")
  animator.setAnimationState("barrel", "broken")
  animator.setAnimationState("rocketLauncher", "broken")
  
  animator.playSound("death")
  
  --Unbossify it and stop it from taking damage
  monster.setDamageBar("None")
  status.addPersistentEffect("unboundtankboss", "invulnerable")
	
  --Drop loot
  local dropPools = config.getParameter("dropPools")
  for _, pool in pairs(dropPools) do
    world.spawnTreasure(mcontroller.position(), pool, 1)
  end
  
  --Spawn some explosions
  explode(15)

  --And spawn an unbound soldier
  world.spawnNpc(vec2.add(mcontroller.position(), {0, 2}), "apex", "starforge-unboundtankcaptain", monster.level())
end

function dieState.update(dt, stateData)
  stateData.timer = math.max(0, stateData.timer - dt)

  if stateData.timer <= 0 then
    --self.dead = true
  end
  return false
end

function explode(count)
  local params = {}
  params.power = 0
  params.actionOnReap = {
	{
	  action = "projectile",
	  inheritDamageFactor = 0,
	  type = "mechexplosion"
	}
  }
  for i = 1, count do
    local randAngle = math.random() * math.pi * 2
	local randOffset = {math.random() * 9 - 4.5, math.random() * 4 - 2.5}
    local spawnPosition = vec2.add(mcontroller.position(), randOffset)
    local aimVector = {math.cos(randAngle), math.sin(randAngle)}
	
	params.timeToLive = math.random() * 3
	world.spawnProjectile("shockwavespawner", spawnPosition, entity.id(), aimVector, false, params)
  end
end
