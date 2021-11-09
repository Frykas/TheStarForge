require "/scripts/vec2.lua"

function init()
  animator.scaleTransformationGroup("progressbar", {0, 1}, {-3.0, 0.0})
  animator.setAnimationState("progressbar", "progressing")
  vehicle.setInteractive(false)
  
  message.setHandler("starforge-setprogress", function(_, _, progress, completed)
	self.targetProgress = progress
	self.completed = completed
  end)
end

function update(dt)  
  self.completionProgress = math.min(self.targetProgress or 0, (self.completionProgress or 0) + 0.15 * dt)

  animator.resetTransformationGroup("progressbar")
  animator.scaleTransformationGroup("progressbar", {self.completionProgress, 1}, {-3.0, 0.0})
  
  if self.completed and self.completionProgress == 1 then
	animator.setAnimationState("progressbar", "completed")
	vehicle.destroy()
  end
end
