require "/scripts/util.lua"
require "/scripts/starforge-util.lua"

function build(directory, config, parameters, level, seed)
  if parameters.playerPortrait then
    local skinColour = parameters.playerPortrait[1].image
    local splitString = nebUtil.splitString(skinColour)
    table.remove(splitString, 1)
	
    local playerDirectives = ""
	for _, x in ipairs(splitString) do
      playerDirectives = playerDirectives .. "?" .. x
    end
	
	local splitDirectives = nebUtil.splitString(playerDirectives, ";")
    table.remove(splitDirectives, 1)
	local targetDirectives = ""
	for _, x in ipairs(splitDirectives) do
	  local splitX = nebUtil.splitString(x, "=")
	  local foundQuestion = string.find(splitX[2], "?")
	  if foundQuestion then
  	    splitX[2] = splitX[2]:sub(1, foundQuestion - 1)
	  end
	  sb.logInfo("%s", splitX)
	  targetDirectives = targetDirectives .. ";" .. splitX[1] .. "=" .. splitX[2] .. (config.alphaHex or "")
	end
	targetDirectives = "?replace" .. targetDirectives
	
	if targetDirectives ~= parameters.targetDirectives then
	  parameters.targetDirectives = targetDirectives
      local dyeDirectives = parameters.colorIndex and nebUtil.determineReplaceColours(config.colorOptions[parameters.colorIndex]) or ""
      parameters.directives = dyeDirectives .. targetDirectives
    end
  end
  
  return config, parameters
end