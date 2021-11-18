require "/scripts/vec2.lua"

function destroy()
  if world.isTileProtected(entity.position()) then
    world.setTileProtection(world.dungeonId(entity.position()), false)
    world.placeObject(projectile.getParameter("objectToSpawn"), vec2.floor(entity.position()), projectile.getParameter("objectDirection"), projectile.getParameter("objectParameters"))
    world.setTileProtection(world.dungeonId(entity.position()), true)
  else
    world.placeObject(projectile.getParameter("objectToSpawn"), vec2.floor(entity.position()), projectile.getParameter("objectDirection"), projectile.getParameter("objectParameters"))
  end
end