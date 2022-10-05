require "/scripts/vec2.lua"

function init()
  --if not config.getParameter("host") then status.setResource("health", 0) end
  self.totalProgress = config.getParameter("totalProgress")
  self.currentProgress = 0
  self.deathTimer = config.getParameter("deathTimer", 1)
  self.animConfig = config.getParameter("progressAnimationParameters")
  
  message.setHandler("starforge-setProgress", function(_, _, current)
	self.currentProgress = current
  end)
  message.setHandler("starforge-reset", function(_, _)
	status.setResource("health", 0)
  end)
  
  --world.sendEntityMessage(config.getParameter("host"), "setBar", entity.id())
  if not self.animConfig then status.setResource("health", 0) end
end

function update(dt)
  if self.currentProgress == self.totalProgress then
    self.deathTimer = self.deathTimer - dt
	if self.deathTimer <= 0 then
	  status.setResource("health", 0)
    end
  end
  
  updateProgressBar()
end

function updateProgressBar()
  local info = {}
  info.totalProgress = self.totalProgress
  info.currentProgress = self.currentProgress
  info.animConfig = self.animConfig

  monster.setAnimationParameter("progressConfig", info)
end