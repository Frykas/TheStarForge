require "/scripts/util.lua"

-- test ability
StarforgeTest = WeaponAbility:new()

function StarforgeTest:init()
  activeItem.setScriptedAnimationParameter("entities", {})
  activeItem.setScriptedAnimationParameter("entityMarker", self.entityMarker)
end

function StarforgeTest:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  activeItem.setScriptedAnimationParameter("entities", self:findTargets())
end

function StarforgeTest:findTargets()
  local nearEntities = world.entityQuery(mcontroller.position(), self.targetQueryDistance or 100, { includedTypes = {"monster", "npc", "player"} })
  nearEntities = util.filter(nearEntities, function(entityId)
    if not world.entityCanDamage(activeItem.ownerEntityId(), entityId) then
      return false
    end

    if world.lineTileCollision(mcontroller.position(), world.entityMouthPosition(entityId)) then
      return false
    end

    return true
  end)

  if #nearEntities > 0 then
    return nearEntities
  else
    return {}
  end
end


function StarforgeTest:uninit()
  activeItem.setScriptedAnimationParameter("entities", {})
end
