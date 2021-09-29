require "/scripts/vec2.lua"

function destroy()
  local places = world.placeObject(projectile.getParameter("objectToSpawn"), vec2.floor(entity.position()), projectile.getParameter("objectDirection"))
end