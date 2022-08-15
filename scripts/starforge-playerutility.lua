require "/scripts/util.lua"

local originalInit = init
local originalUpdate = update
local originalUninit = uninit

function init()
  originalInit()
  sb.logInfo("===== STARFORGE PLAYER INITIALIZATION =====")
  sb.logInfo("Initializing general player utility script")
  
  self.areaStatusEffects = config.getParameter("starforge-areaStatusEffects", {})
  self.statusEffectQueryRange = 100
  self.statusEffectIntervalTime = 1
  self.statusEffectIntervalTimer = self.statusEffectIntervalTime
  
  ---Entity Messaging Handler---
  message.setHandler("starforge-callPlayerFunction", callPlayerFunction)
end

function callPlayerFunction(_, _, functionType, args)
  player[functionType](table.unpack(args))
end
  
function update(args)
  originalUpdate(args)
  
  if #self.areaStatusEffects > 0 and self.statusEffectIntervalTimer < 0 then
	self.statusEffectIntervalTimer = self.statusEffectIntervalTime
  
    --Look for entities within our detect distance
    local targets = world.entityQuery(entity.position(), self.statusEffectQueryRange, {
	  withoutEntityId = entity.id(),
  	  includedTypes = {"creature"}
    })
  
    --For every entity found, check if we can damage it then apply status effect
    for _, target in ipairs(targets) do
	  if world.entityCanDamage(entity.id(), target) then
	    for _, effect in ipairs(self.areaStatusEffects) do
          world.sendEntityMessage(target, "applyStatusEffect", effect, config.getParameter("statusDurationOverwrite", nil), entity.id())
        end
	  end
    end
  else
	self.statusEffectIntervalTimer = self.statusEffectIntervalTimer - script.updateDt()
  end
end

function uninit()
  originalUninit()
end