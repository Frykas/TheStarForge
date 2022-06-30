require "/scripts/util.lua"

function init()
  self.itemList = "itemScrollArea.itemList"
  self.totalCost = "lblCostTotal"

  self.weaponType = config.getParameter("weaponType", "starforge-combatrifle")
  self.weaponInventorySize = config.getParameter("weaponInventorySize", 5)
 
  self.seed = config.getParameter("seed", 1)
  self.seeds = {}
  for i = 1, self.weaponInventorySize do
	local newSeed = ((self.seed + i) % 4294967295) + 1
    table.insert(self.seeds, newSeed)
  end
  
  self.selectedItem = nil
	
  populateItemList(true)
end

function update(dt)
  populateItemList()
end

function populateItemList(forceRepop)
  local playerMoney = player.currency("money")

  if forceRepop then
    widget.clearListItems(self.itemList)

    local showEmptyLabel = true

    for i = 1, self.weaponInventorySize do
	  local generatedWeapon = root.createItem(self.weaponType, world.threatLevel(), self.seeds[i])
	  --local randomWeapon = self.weaponTypes[(math.random(1, 4294967295) % #self.weaponTypes) + 1]
	  --root.itemConfig(randomWeapon)
      local config = generatedWeapon.parameters 

	  showEmptyLabel = false

	  local listItem = string.format("%s.%s", self.itemList, widget.addListItem(self.itemList))
	  local name = config.shortdescription or config.shortdescription or "Failed to reach item name"
	  local cost = config.price or 1

	  widget.setItemSlotItem(string.format("%s.itemIcon", listItem), generatedWeapon)
	  widget.setText(string.format("%s.itemName", listItem), name)
	  
	  widget.setText(string.format("%s.priceLabel", listItem), cost)

	  widget.setData(listItem,
		{
		  item = generatedWeapon
		}
	  )
	  
	  widget.setVisible(string.format("%s.unavailableoverlay", listItem), cost > playerMoney)
    end

	self.selectedItem = nil
	showWeapon(nil)

    widget.setVisible("emptyLabel", showEmptyLabel)
  end
end

function showWeapon(item)
  local playerMoney = player.currency("money")
  local enableButton = false

  if item then
    local cost = item.parameters.price
    enableButton = playerMoney >= cost
    widget.setText(self.totalCost, string.format("%s", cost))
  else
    widget.setText(self.totalCost, string.format("--"))
  end

  widget.setButtonEnabled("btnBuy", enableButton)
end

function itemSelected()
  local listItem = widget.getListSelected(self.itemList)
  self.selectedItem = listItem

  if listItem then
    local listItem = string.format("%s.%s", self.itemList, self.selectedItem)
    local itemData = widget.getData(listItem)
    showWeapon(itemData.item)
  end
end

function purchase()
  if self.selectedItem then
    local listItem = string.format("%s.%s", self.itemList, self.selectedItem)
    local selectedData = widget.getData(listItem)
    local selectedItem = selectedData.item

    if selectedItem then
	  --If we successfully consumed enough currency, give the new item to the player
	  local consumedCurrency = player.consumeCurrency("money", selectedItem.parameters.price)
	  if consumedCurrency then
		player.giveItem(selectedItem)
	    widget.setData(listItem,
		  {
		    price = 999999999999
		  }
	    )
	    widget.setVisible(string.format("%s.unavailableoverlay", listItem), true)
	    widget.setText(string.format("%s.priceLabel", listItem), "Sold!")
		widget.setText(self.totalCost, string.format("--"))
		widget.setButtonEnabled("btnBuy", false)
	  end
    end
    populateItemList()
  end
end
