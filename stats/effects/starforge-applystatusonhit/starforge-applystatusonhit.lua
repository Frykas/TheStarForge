require "/scripts/status.lua"

function init()
  self.statusEffect = config.getParameter("statusEffects", {})
  self.damageGivenListener = damageListener("inflictedDamage", function(notifications)
    for _, notification in pairs(notifications) do
	  for _, effect in ipairs(self.statusEffects) do
        world.sendEntityMessage(notification.targetEntityId, "applyStatusEffect", effect, config.getParameter("statusDurationOverwrite", nil), entity.id())
      end
	end
  end)
end

function update(dt)
  self.damageGivenListener:update()
end

function uninit()
end

function onExpire()
end