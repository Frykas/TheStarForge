require "/scripts/vec2.lua"

function init()
end

function update(dt)
  local targets = world.entityLineQuery(mcontroller.position(), vec2.add(mcontroller.position(), {0, -15}), {
	withoutEntityId = entity.id(),
	includedTypes = {"player"},
	order = "nearest"
  })
  if targets[1] then
    projectile.die()
  end
end
