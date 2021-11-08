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
	  world.sendEntityMessage(entity, self.message, true)
    end
  end
end

function onInteraction(args)
  if storage.hasBeenTriggered == false then
    trigger()
  end
end