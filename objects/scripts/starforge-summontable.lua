require "/scripts/vec2.lua"

function init()
  object.setMaterialSpaces(config.getParameter("materialSpaces", {}))
  self.addonConfig = config.getParameter("addonConfig", {})
  if ObjectAddons then
    local addonConfig = currentAddonData().addonConfig
    ObjectAddons:init(addonConfig or {})
  end
end

function update(dt)
  world.debugText("Has effigy: %s", config.getParameter("isActive", "--"), vec2.add(object.position(), {2, 3}), "red")
  world.debugText("Connected: %s", ObjectAddons:isConnectedAsAny(), vec2.add(object.position(), {2, 4}), "red")
end 

function updateAddonData()
  local addonData = currentAddonData()

  sb.logInfo("addonData %s", addonData)
  for k, v in pairs(addonData or {}) do
    sb.logInfo("k %s, v %s", k, v)
    object.setConfigParameter(k, v)
  end
end

function currentAddonData()
  --Merge data from any connected addons
  local res = {}
  for _, addon in pairs(self.addonConfig.usesAddons or {}) do
    --sb.logInfo("CONFIG CONNECTION %s", ObjectAddons:isConnectedAs(addon.name)) -- PROBLEM IS HERE NO CONNECTION?
    if ObjectAddons:isConnectedTo(addon.name) then
      res = util.mergeTable(res, addon.addonData)
    end
  end
  return res
end

function uninit()
  if ObjectAddons then
    ObjectAddons:uninit()
  end
end 