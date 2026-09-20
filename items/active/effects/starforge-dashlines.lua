require "/scripts/vec2.lua"
require "/scripts/util.lua"

function update()
  local dt = script.updateDt()
  localAnimator.clearDrawables()

  local dash = animationConfig.animationParameter("dash")
  if dash ~= nil and self.dash == nil then
    self.dash = dash
    self.dash.timer = dt
    self.dash.lines = {}
  end
  if self.dash then
    local dashTime = 0.1
    if #self.dash.lines == 0 then
      for i = 1, self.dash.config.dashLines or 15 do
        local first = vec2.withAngle(math.random() * math.pi * 2, math.random() * self.dash.config.height or 6.0)
        local last = vec2.add(first, vec2.sub(self.dash.last, self.dash.first))
        table.insert(self.dash.lines, {
          pos = self.dash.first,
          first = first,
          last = last,
          length = 1.0 + math.random() * 16.0
        })
      end
    end
    
    local ratio = self.dash.timer / dashTime
    if ratio < 1.0 then
      local dashLength = world.magnitude(self.dash.first, self.dash.last)
      local dashDir = vec2.norm(world.distance(self.dash.last, self.dash.first))

      for _, line in ipairs(self.dash.lines) do
        local length = line.length
        if ratio < 0.2 then
          length = (ratio / 0.2) * length
        elseif ratio > 0.8 then
          length = ((1 - ratio) / 0.2) * length
        end
        local moveDist = math.max(0.0, ((ratio - 0.2) / 0.8) * (dashLength - length))

        local first = vec2.add(line.first, vec2.mul(dashDir, moveDist))
        local last = vec2.add(first, vec2.mul(dashDir, length))
        localAnimator.addDrawable({line = {first, last}, width = 1, position = line.pos, color = self.dash.config.colour or {253, 209, 77, 180}}, "Monster-10")
      end

      self.dash.timer = self.dash.timer + dt
    else
      self.dash = nil
    end
  end
end
