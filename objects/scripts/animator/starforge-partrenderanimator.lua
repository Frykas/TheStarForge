require "/scripts/vec2.lua"

function update(dt)
  localAnimator.clearDrawables()
  
  updateParts()
end

function updateParts()
  local partsToRender = animationConfig.animationParameter("starforge-partsToRender")
  for _, part in ipairs(partsToRender) do
    local localPart = {}
	
	--If the directory isn't absolute, assume the directory using the objects directory
	localPart.image = part.image
	if part.image:sub(1, 1) ~= "/" then
	  localPart.image = root.itemConfig(part.objectName).directory .. part.image .. (part.currentFrame or "")
	end
	
	localPart.mirrored = (part.flipImages) and (part.direction > 0) or (part.direction < 0)
	localPart.fullbright = part.fullbright
	localPart.position = vec2.add(entity.position(), vec2.add(part.offset, {0, root.imageSize(localPart.image)[2] / 16}))
	localPart.centered = part.centered
	
	localAnimator.addDrawable(localPart, part.renderLayer)
  end
end
