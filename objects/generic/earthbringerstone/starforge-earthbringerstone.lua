function init()
  object.setConfigParameter("breakDropPool", "empty")
  if not storage.itemHasSpawned then
    animator.setAnimationState("stone", "swordPresent")
	storage.itemHasSpawned = false
	object.setInteractive(true)
  else
    if storage.hasBroken then
      animator.setAnimationState("stone", "swordBroken")
	else
      animator.setAnimationState("stone", "swordAbsent")
	end
	
	object.setInteractive(false)
  end
  
  self.itemId = config.getParameter("itemId")
  self.brokenItemId = config.getParameter("brokenItemId")
  
  self.breakChance = config.getParameter("breakChance", 0.5)
end

function pullSword()
  animator.playSound("pullSword")
  if math.random() < self.breakChance then
    storage.hasBroken = true
    animator.playSound("breakSword")
    animator.setAnimationState("stone", "swordBroken")
    world.spawnItem(self.brokenItemId, entity.position(), 1)
  else
    animator.setAnimationState("stone", "swordAbsent")
    world.spawnItem(self.itemId, entity.position(), 1)
  end
  storage.itemHasSpawned = true
  object.setInteractive(false)
end


function onInteraction(args)
  if storage.itemHasSpawned == false then
    pullSword()
  end
end