require "/scripts/vec2.lua"

function init()
  if not storage.hasBeenTriggered then
    object.setInteractive(true)
    animator.setAnimationState("objectState", "normal")
	storage.hasBeenTriggered = false
  else
    animator.setAnimationState("objectState", "altered")
	object.setInteractive(false)
  end
  
  self.message = config.getParameter("message")
  self.messageRadius = config.getParameter("messageRadius", 2)
  self.messageArgs = config.getParameter("messageArgs", 1.25)
  if type(self.messageArgs) ~= "table" then
    self.messageArgs = {self.messageArgs}
  end
  
  message.setHandler("starforge-detonatestarforge", function(_, _)
    if not self.exploded then
	  object.setInteractive(false)
	  explode(12)
	  animator.setAnimationState("objectState", "destroyed")
	  self.exploded = true
    end
  end)
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
	local randOffset = {math.random() * 9 - 4.5, math.random() * 7 - 0.5}
    local spawnPosition = vec2.add(entity.position(), randOffset)
    local aimVector = {math.cos(randAngle), math.sin(randAngle)}
	
	params.timeToLive = math.random() * 2  + (i * 0.01)
	world.spawnProjectile("shockwavespawner", spawnPosition, entity.id(), aimVector, false, params)
  end
end

function update(dt)
end

function trigger()
  animator.setAnimationState("objectState", "altered")
  storage.hasBeenTriggered = true
  object.setInteractive(false)
  
  if self.message then
    local entitiesToMessage = world.entityQuery(entity.position(), self.messageRadius)
    for _, entity in pairs(entitiesToMessage) do
	  world.sendEntityMessage(entity, self.message, table.unpack(self.messageArgs))
    end
  end
end

function onInteraction(args)
  if storage.hasBeenTriggered == false then
    trigger()
  end
end