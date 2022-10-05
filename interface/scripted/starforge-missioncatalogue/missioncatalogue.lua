function init()
  local destinationConfig = root.assetJson(config.getParameter("destinationConfig", "/interface/scripted/starforge-missioncatalogue/config/destinations.config"))
  
  self_destinationList = "destinationScrollArea.itemList"
  self_validDestinations = {}
  for x, config in pairs(destinationConfig.missions) do
    local valid = true
    for _, quest in pairs(config.questPrerequisites or {}) do
	  if not player.hasCompletedQuest(quest) then
	    valid = false 
	  end
	end
	if valid then
	  self_validDestinations[x] = config
	end
  end
  self_teleportDestination = false
  
  populateDestinationList()
end

function close() pane.dismiss() end

function teleport()
  if (self_teleportDestination) then
  	player.warp(string.format("instanceWorld:%s", self_teleportDestination), "beam")
  	close()
  end
end

function destinationSelected()
  local destinationName = widget.getListSelected(self_destinationList)
  if destinationName then
    local config = self_validDestinations[widget.getData(string.format("%s.%s", self_destinationList, destinationName))]
    widget.setImage("destinationIcon", config.icon or "/assetmissing.png")
    widget.setImage("destinationPreview", config.previewImage or "/assetmissing.png")
	
    widget.setText("destinationShortDescription", string.format("%s\n^gray;Level ^reset;%s", config.shortDescription, config.level))
    widget.setText("destinationDescription", string.format("%s", config.description):gsub("%^white;", "^reset;"))
	
	self_teleportDestination = config.destination
  end
end

function populateDestinationList()
  widget.clearListItems(self_destinationList)

  for x, config in pairs(self_validDestinations) do
	local listItem = widget.addListItem(self_destinationList)
	widget.setText(string.format("%s.%s.destinationName", self_destinationList, listItem), config.shortDescription)
	widget.setImage(string.format("%s.%s.destinationIcon", self_destinationList, listItem), config.icon or "/assetmissing.png")
	widget.setData(string.format("%s.%s", self_destinationList, listItem), x)
  end
end