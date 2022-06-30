ObjectAddons = {
  connectedAs = {}, -- default to empty table so isConnectedAs doesn't explode when called uninitialized
  connectedTo = {} -- default to empty table so isConnectedTo doesn't explode when called uninitialized
}

-- call this in the object's init(), passing it the full addon configuration object
-- which can optionally contain lists of "usesAddons" and/or "isAddons" config objects
-- also accepts an optional callback to be called when connection status may have changed
function ObjectAddons:init(addonConfig, connectionCallback)
  self.isAddons = addonConfig.isAddons or {} -- addons we can connect AS
  self.usesAddons = addonConfig.usesAddons or {} -- addons we can connect TO
  self.connectionCallback = connectionCallback

  local queryArea = object.boundBox() -- TODO: use proper bound box and expand rather than relying on metaboundbox
  local pos = entity.position()
  self.queryPoints = {
    {queryArea[1], queryArea[2]},
    {queryArea[3], queryArea[4]}
  }

  message.setHandler("connectAsAddon", function(_, _, addonName, position, connectionId)
      return self:connectAsAddon(addonName, position, connectionId)
    end)

  message.setHandler("connectToAddon", function(_, _, addonName, position, connectionId)
      return self:connectToAddon(addonName, position, connectionId)
    end)

  message.setHandler("disconnectFrom", function(_, _, connectionId)
      return self:disconnectFrom(connectionId)
    end)

  self:connect()
  
  sb.logInfo("initialised")
end

-- call this in the object's uninit()
function ObjectAddons:uninit()
  self:disconnect()
end

-- query nearby objects and attempt to connect both AS and TO addons
function ObjectAddons:connect()
  local queryParameters = {
    boundMode = "MetaBoundBox",
    withoutEntityId = entity.id(),
    callScript = "usesObjectAddons"
  }
  local addonObjectsNearby = world.entityQuery(self.queryPoints[1], self.queryPoints[2], queryParameters)

  local entityId = entity.id()
  local pos = entity.position()

  self.connectedAs = {}
  for _, addon in pairs(self.isAddons) do
    for _, id in pairs(addonObjectsNearby) do
      self.connectedAs[addon.name] = self.connectedAs[addon.name] or world.sendEntityMessage(id, "connectToAddon", addon.name, pos, entityId):result() or false
    end
  end

  self.connectedTo = {}
  for _, addon in pairs(self.usesAddons) do
    local addonPosition = {pos[1] + addon.position[1], pos[2] + addon.position[2]}
    for _, id in pairs(addonObjectsNearby) do
      self.connectedTo[addon.name] = self.connectedTo[addon.name] or world.sendEntityMessage(id, "connectAsAddon", addon.name, addonPosition, entityId):result() or false
    end
  end

  if self.connectionCallback then self.connectionCallback() end
end

-- handle a message to connect AS an addon with a given name and (world) position
-- return entityId if successful, false otherwise
function ObjectAddons:connectAsAddon(addonName, position, connectionId)
  if self:positionMatches(position, entity.position()) then
    for _, addon in pairs(self.isAddons) do
      if addon.name == addonName then
        self.connectedAs[addonName] = connectionId
        if self.connectionCallback then self.connectionCallback() end
        return entity.id()
      end
    end
  end
  return false
end

-- handle a message to connect TO an addon with a given name and (world) position
-- return entityId if successful, false otherwise
function ObjectAddons:connectToAddon(addonName, position, connectionId)
  local pos = entity.position()
  for _, addon in pairs(self.usesAddons) do
    local targetPosition = {pos[1] + addon.position[1], pos[2] + addon.position[2]}
	sb.logInfo("name: %s, pos: %s, targetPos: %s, addonpos: %s", addon.name, pos, targetPosition, addon.position)
    if addon.name == addonName and self:positionMatches(position, targetPosition) then
      self.connectedTo[addonName] = connectionId
      if self.connectionCallback then self.connectionCallback() end
      return entity.id()
    end
  end
  return false
end

-- send disconnection messages to all connected objects
function ObjectAddons:disconnect()
  local entityId = entity.id()
  for _, connectionId in pairs(self.connectedAs) do
    if connectionId then
      world.sendEntityMessage(connectionId, "disconnectFrom", entityId)
    end
  end
  for _, connectionId in pairs(self.connectedTo) do
    if connectionId then
      world.sendEntityMessage(connectionId, "disconnectFrom", entityId)
    end
  end
end

-- handle a disconnection message from a specified id
function ObjectAddons:disconnectFrom(connectionId)
  for addonName, connection in pairs(self.connectedAs) do
    if connection == connectionId then
      self.connectedAs[addonName] = false
    end
  end
  for addonName, connection in pairs(self.connectedTo) do
    if connection == connectionId then
      self.connectedTo[addonName] = false
    end
  end

  if self.connectionCallback then self.connectionCallback() end
end

-- for use by local scripts to determine whether we're connected AS any addon
function ObjectAddons:isConnectedAsAny()
  for _, connection in pairs(self.connectedAs) do
    if connection then return true end
  end
  return false
end

-- for use by local scripts to determine whether we're connected AS a specific addon
function ObjectAddons:isConnectedAs(addonName)
  return self.connectedAs[addonName]
end

-- for use by local scripts to determine whether we're connected TO any addon
function ObjectAddons:isConnectedToAny()
  for _, connection in pairs(self.connectedTo) do
    if connection then return true end
  end
  return false
end

-- for use by local scripts to determine whether we're connected TO a specific addon
function ObjectAddons:isConnectedTo(addonName)
  return self.connectedTo[addonName]
end

-- helper because we don't have vec2 userdata
function ObjectAddons:positionMatches(pos1, pos2)
  return pos1[1] == pos2[1] and pos1[2] == pos2[2]
end

-- used by entityQuery to let other objects know to attempt communication
function usesObjectAddons()
  return true
end
