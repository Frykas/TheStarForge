require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  object.setHealth(2147483647)
  self.lastHealth = object.health()
  self.damageTaken = 0
  
  self.regrowTime = config.getParameter("regrowTime", 5)
  storage.regrowTimer = 0
  
  self.proximityScan = config.getParameter("proximityScan")
  self.proximityToDetonate = config.getParameter("proximityToDetonate")
  self.proximityShakeConfig = config.getParameter("proximityShakeConfig")
  
  animator.setAnimationState("activeState", (storage.regrowTimer > 0) and "inactive" or "active")
end

function update(dt)
  storage.regrowTimer = math.max(0, storage.regrowTimer - dt)
  if storage.regrowTimer == 0 and animator.animationState("activeState") == "inactive" then
	animator.setAnimationState("activeState", "regrow")
  end
  
  animator.resetTransformationGroup("body")
  if self.proximityScan and animator.animationState("activeState") == "active" then
    local target = world.entityQuery(entity.position(), self.proximityScan, {
	  withoutEntityId = entity.id(),
	  includedTypes = {"player"},
	  order = "nearest"
    })[1]
	
	if target then
	  local dist = world.magnitude(entity.position(), world.entityPosition(target))
	
	  if self.proximityToDetonate and dist < self.proximityToDetonate then
	    explode()
	  end
	
	  if self.proximityShakeConfig then
	    local distFactor = 1 - (dist / self.proximityScan)
	    local cycle = (self.proximityShakeConfig.cycle / (2 * math.pi))
	    self.shakeTimer = (self.shakeTimer or 0) + (dt * distFactor) % (cycle * 2)
	  
	    local floorPoint = vec2.add(vec2.sub(world.lineTileCollisionPoint(entity.position(), vec2.add(entity.position(), {0, -5}))[1], entity.position()), self.proximityShakeConfig.floorOffset or {0, 0})
		world.debugPoint(vec2.add(entity.position(), floorPoint), "blue")
	    animator.rotateTransformationGroup("body", self.proximityShakeConfig.amplitude * math.sin(self.shakeTimer / cycle), floorPoint)
	  end
	end
  end
  
  if self.damageTaken > config.getParameter("damageToBurst", 5) and animator.animationState("activeState") == "active" then
    explode()
  end
  
  if object.health() < self.lastHealth then
    takeDamage(self.lastHealth - object.health())
  end
  self.lastHealth = object.health()
  world.debugText("Regrow Time: " .. storage.regrowTimer, vec2.add(entity.position(), {0, 5}), "yellow")
end

function takeDamage(damage)
  if animator.animationState("activeState") == "active" then
    self.damageTaken = self.damageTaken + damage
  end
  
  animator.playSound("takeDamage")
  animator.burstParticleEmitter("takeDamage")
  object.setHealth(2147483647)
end

function explode()
  self.damageTaken = 0
  storage.regrowTimer = self.regrowTime

  animator.setAnimationState("activeState", "inactive")
  animator.playSound("burst")
  animator.burstParticleEmitter("burst")
  
  local params = sb.jsonMerge(config.getParameter("burstProjectileParameters", {}), {})
  local projectileType = config.getParameter("burstProjectileType", "standardbullet")
  if type(projectileType) ~= "table" then
    projectileType = {projectileType}
  end
  
  for _, projectile in ipairs(projectileType) do
    projectileId = world.spawnProjectile(
        projectile,
        object.position(),
        entity.id(),
        {0, 0},
        false,
        params
      )
  end
end