require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  object.setInteractive(true)
  
  self.currentStage = 1
  self.addonConfig = config.getParameter("addonConfig", {})
  
  if ObjectAddons then
    backupData()
    updateAddonData()
    ObjectAddons:init(self.addonConfig or {}, updateAddonData)
  end
end

--
--MAIN MANAGEMENT
--
function onInteraction(args)
  local item = determineItem()
  
  --Check and consume the item if it is available and progress
  if consumeItem(args.sourceId, item) then
    self.currentStage = self.currentStage + 1
	animator.setGlobalTag("stage", self.currentStage)
	if not config.getParameter("isActive") and self.currentStage == config.getParameter("stageCount", 5) - 1 then
	  object.setInteractive(false)
	elseif config.getParameter("isActive") and self.currentStage == config.getParameter("stageCount", 5) then
	  local boss = spawnMonster()
	  world.sendEntityMessage(boss, "applyStatusEffect", "starforge-yukaiteleporteffect")
	end
  end
end

function spawnMonster()
  local monsterId = world.spawnMonster(config.getParameter("summonedMonster", "poptop"), object.position(), {level = world.threatLevel(), aggressive = true})
  
  --BREAK ADDON PERMANENTLY
  
  --Reset object back to stage 1
  self.currentStage = 1
  
  return monsterId
end

function consumeItem(interactEntityId, item)
  if world.entityHasCountOfItem(interactEntityId, item) > 0 then --THIS FUNCTION IS INCONSISTENT ONLINE, FIND AN ALTERNATIVE!!
    world.sendEntityMessage(interactEntityId, "starforge-callPlayerFunction", consumeItem, {item})
    return true
  end
  return false
end

--If broken, spawn all items put into the object
function die()
  for x = 1, self.currentStage do
    local item = determineItem()
    world.spawnItem(itemDescriptor, vec2.add(object.position(), {0, 3}))
  end
end

--Determine whether we use the base item or final item
function determineItem()
  local item = config.getParameter("requireItem", "money")
  if self.currentStage == config.getParameter("stageCount", 5) then
	item = config.getParameter("finalRequiredItem", "money")
  end
  return item
end

--
--ADDON MANAGEMENT
--
function currentAddonData()
  --Check if we are connected to any addons
  if ObjectAddons:isConnectedToAny() then
    --Merge data from any connected addons
    local res = copy(storage.backupData)
    for _, addon in pairs(self.addonConfig.usesAddons or {}) do
      if ObjectAddons:isConnectedTo(addon.name) then
	    --Reset interactivity
		object.setInteractive(true)
		--Merge backup/default table with addon data
        res = util.mergeTable(res, addon.addonData)
      end
    end
    return res
  --Otherwise return the base stats to reset the values
  else return storage.backupData end
end

function updateAddonData()
  local addonData = currentAddonData()

  for k, v in pairs(addonData or {}) do
    --sb.logInfo("%s: %s", k, v)
    object.setConfigParameter(k, v)
  end
end

function backupData()
  local backup = config.getParameter("backupData", storage.backupData or {})
  for _, addon in pairs(self.addonConfig.usesAddons or {}) do
    for k, v in pairs(addon.addonData or {}) do
      if not backup[k] then
	    backup[k] = config.getParameter(k)
	  end
    end
  end
  storage.backupData = backup
  object.setConfigParameter("backupData", backup)
end

function uninit()
  if ObjectAddons then
    ObjectAddons:uninit()
  end
end 