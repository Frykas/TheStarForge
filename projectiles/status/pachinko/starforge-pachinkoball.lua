require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.homingSpeed = config.getParameter("homingSpeed")
  self.homingForce = config.getParameter("homingForce")
  
  self.searchDistance = config.getParameter("searchDistance")
  self.pickupRange = config.getParameter("pickupRange")
  self.snapRange = config.getParameter("snapRange")
  self.snapSpeed = config.getParameter("snapSpeed")
  self.snapForce = config.getParameter("snapForce")
  self.accelerationFactor = config.getParameter("accelerationFactor", 2)

  self.targetEntity = nil
  
  if config.getParameter("homingStartDelay") ~= nil then
	self.homingEnabled = false
	self.countdownTimer = config.getParameter("homingStartDelay")
  else
	self.homingEnabled = true
  end
end

function update(dt)
  if self.targetEntity and self.homingEnabled then
    --Exponent Acceleration
    mcontroller.accelerate(vec2.mul(mcontroller.velocity(), self.accelerationFactor))
    if world.entityExists(self.targetEntity) then
      --world.debugPoint(world.entityPosition(self.targetEntity), "blue")
	  
	  local targetPos = world.entityPosition(self.targetEntity)
      local toTarget = world.distance(targetPos, mcontroller.position())
      local targetDist = vec2.mag(toTarget)
      if targetDist <= self.pickupRange then
	    for _, effect in ipairs(config.getParameter("statusEffectsOnPickup", {})) do
          world.sendEntityMessage(self.targetEntity, "applyStatusEffect", effect, nil, self.targetEntity)
        end
        projectile.die()
      elseif targetDist <= self.snapRange then
        mcontroller.approachVelocity(vec2.mul(vec2.div(toTarget, targetDist), self.snapSpeed), self.snapForce)
	  else
		mcontroller.approachVelocity(vec2.mul(vec2.norm(toTarget), self.homingSpeed), self.homingForce)
      end
    else
      self.targetEntity = nil
      mcontroller.approachVelocity({0, 0}, self.homingForce)
    end
  elseif not self.homingEnabled then
	self.countdownTimer = math.max(0, self.countdownTimer - dt)
	if self.countdownTimer == 0 then
	  self.homingEnabled = true
	end
  else
    local players = world.entityQuery(entity.position(), self.searchDistance, {includedTypes = {"player"}, order = "nearest"})
    players = util.filter(shuffled(players), function(entityId)
      return not world.lineTileCollision(entity.position(), world.entityPosition(entityId))
    end)
    self.targetEntity = players[1]
  end
end