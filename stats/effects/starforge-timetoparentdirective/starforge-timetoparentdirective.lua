function init()
  self.directiveToTime = config.getParameter("directiveToTime", {})
  self.activeTime = 0
  updateDirectives()
end

function update(dt)
  self.activeTime = self.activeTime + dt
  updateDirectives()
end

function updateDirectives()
  local directive = ""
  for _, step in ipairs(self.directiveToTime) do
    if self.activeTime > step[1] then
      directive = step[2]
    end
  end
  effect.setParentDirectives(directive)
end

function onExpire()
  effect.setParentDirectives("")
end
