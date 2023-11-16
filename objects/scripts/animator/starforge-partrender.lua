function init()
  self.partsToRender = config.getParameter("partsToRender", {})
end

function update(dt)
  for x, part in ipairs(self.partsToRender) do
	part.objectName = object.name()
	part.direction = object.direction()
	
	--Animation
	if part.frames > 1 then
      part.animationTimer = (part.animationTimer + dt) % part.animationTime
	  part.currentFrame = math.ceil(part.animationTimer / part.animationTime * part.frames)
	end
	self.partsToRender[x] = part
  end
  object.setAnimationParameter("starforge-partsToRender", self.partsToRender)
end