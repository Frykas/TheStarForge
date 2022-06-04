require "/scripts/status.lua"

function init()
  self.damageTypeWhitelist = config.getParameter("damageTypeWhitelist", {})
  self.treasurePools = config.getParameter("treasurePools", {})
  self.damageGivenListener = damageListener("inflictedDamage", function(notifications)
    for _, notification in pairs(notifications) do
	  if notification.hitType == "Kill" and notification.healthLost > 0 and isValidDamageType(notification.damageType) then
	    spawnTreasure(notification.position)
	  end
	end
  end)
end

function update(dt)
  self.damageGivenListener:update()
end

function spawnTreasure(position)
  for _, treasurePool in ipairs(self.treasurePools) do
	world.spawnTreasure(position, treasurePool, world.level())
  end
end

function isValidDamageType(testType)
  if #self.damageTypes == 0 then
    return true
  end
  for _, damageType in ipairs(self.damageTypes) do
    if damageType == testType then
	  return true
	end
  end
end