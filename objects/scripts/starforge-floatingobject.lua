function init()
  self.hoverCycle = config.getParameter("hoverCycle", 1.0) / (2 * math.pi)
  self.hoverMaxTransform = config.getParameter("hoverMaxTransform", 1.0)
  self.timer = math.random() * self.hoverCycle
  
  animator.resetTransformationGroup("object")
end

function update(dt)
  self.timer = (self.timer + dt) % (self.hoverCycle * 2 * math.pi)
  local offset = math.sin(self.timer / self.hoverCycle) * self.hoverMaxTransform
	
  animator.resetTransformationGroup("object")
  animator.translateTransformationGroup("object", {0, offset})
end
