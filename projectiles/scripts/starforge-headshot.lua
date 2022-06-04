require "/scripts/vec2.lua"
require "/scripts/util.lua"

local oldInit = init
function init()
  if oldInit then oldInit() end
  
end

local oldUpdate = update
function update(dt)  
  if oldUpdate then oldUpdate(dt) end
  
end
