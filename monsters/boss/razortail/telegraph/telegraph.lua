require "/scripts/vec2.lua"

function init()
  self.markers = {}
  self.beams = {}
end

function update()
  local dt = script.updateDt()
  localAnimator.clearDrawables()
  localAnimator.clearLightSources()

  local lineTelegraphs = animationConfig.animationParameter("lineTelegraphs") or {}
  for _, telegraph in ipairs(lineTelegraphs) do
    local telegraphPosition = telegraph.pos
    local angle = telegraph.angle or 0
    local width = telegraph.width or 2
    local colour = telegraph.colour or {255, 5, 5, 100}

    local startDir = vec2.rotate({0, 150}, angle)  --25 for length of swansongdash
    local endDir = vec2.rotate({0, -150}, angle)

    --If I wanna specify start and end points!
    if type(telegraphPosition[1]) == "table" then
      startDir = {0, 0}
      endDir = vec2.sub(telegraphPosition[2], telegraphPosition[1])
      telegraphPosition = telegraphPosition[1]
    end

    local worldStart = vec2.add(telegraphPosition, startDir)
    local worldEnd = vec2.add(telegraphPosition, endDir)

    local hitStart = world.lineTileCollisionPoint(telegraphPosition, worldStart)
    local hitEnd = world.lineTileCollisionPoint(telegraphPosition, worldEnd)

    if hitStart then
      startDir = world.distance(hitStart[1], telegraphPosition)
    end
    if hitEnd then
      endDir = world.distance(hitEnd[1], telegraphPosition)
    end

    localAnimator.addDrawable({line = {startDir, endDir}, width = width, position = telegraphPosition, color = colour, fullbright = telegraph.fullbright}, "Projectile-10")
  end

  local warningMarkers = animationConfig.animationParameter("warningMarkers") or {}
  for _, warningMarker in ipairs(warningMarkers) do
    local position = warningMarker[1]
    local image = warningMarker[2]
    localAnimator.addDrawable({
      image = image or "/monsters/boss/nebo_sanctus/telegraph/warningmarker.png",
      position = position,
      fullbright = true,
    }, "Monster-10")
  end

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

  local beamParts = {
    beam = "beam",
    lhbeam = "lefthand",
    rhbeam = "righthand"
  }
  for beamParam, part in pairs(beamParts) do
    if self.beams[beamParam] == nil and animationConfig.animationParameter(beamParam) then
      self.beams[beamParam] = {
        part = part,
        state = 1,
        timer = 0.0
      }
    end
  end
  for beamParam, beam in pairs(self.beams) do
    local line = {animationConfig.partPoint(beam.part, "beamStart"), animationConfig.partPoint(beam.part, "beamEnd")}
    local absoluteLine = {
      vec2.add(entity.position(), line[1]),
      vec2.add(entity.position(), line[2])
    }

    local wallPoint = world.lineCollision(absoluteLine[1], absoluteLine[2])
    if wallPoint then
      line[2] = vec2.add(line[1], world.distance(wallPoint, absoluteLine[1]))
    end

    if beam.state == 1 then
      localAnimator.addDrawable({line = line, width = 1, position = entity.position(), color = {255, 255, 255}, fullbright = true}, "Monster-10")

      if beam.timer > 0.3 then
        beam.state = 2
        beam.timer = 0.0
      end
      
    elseif beam.state == 2 or beam.state == 3 then
      local cycle = 0.2
      local frame = math.ceil((beam.timer % cycle) / cycle * 4)
      local startPart = string.format("/monsters/boss/swansong/beam/beamstart.png:%s", frame)
      local midPart = string.format("/monsters/boss/swansong/beam/beammid.png:%s", frame)
      local endPart = string.format("/monsters/boss/swansong/beam/beamend.png:%s", frame)
      
      local partLength = 0.5
      local lineVec = world.distance(line[2], line[1])
      local dir = vec2.norm(lineVec)
      local angle = vec2.angle(lineVec)
      local length = vec2.mag(lineVec)
      if beam.state == 2 and beam.timer < 0.2 then
        local startLen = (partLength * 2)
        length = startLen + (beam.timer / 0.2) * (length - startLen)
        line[2] = vec2.add(line[1], vec2.mul(dir, length))
      elseif beam.state == 3 then
        local startLen = (partLength * 2)
        local ratio = 1 - (beam.timer / 0.2)
        length = startLen + ratio * (length - startLen)
        line[1] = vec2.sub(line[2], vec2.mul(dir, math.max(0.5, length)))
      end

      if beam.state > 2 or (beam.state == 2 and beam.timer > 0.2) then
        localAnimator.spawnParticle("firebackspark", wallPoint)
        if beam.timer % 0.1 < dt then
          localAnimator.spawnParticle("dust2front", wallPoint)
        end
      end
      
      localAnimator.addDrawable({
        image = startPart,
        position = vec2.add(entity.position(), vec2.add(line[1], vec2.mul(dir, 0.25))),
        rotation = angle,
        fullbright = true,
      }, "Monster-10")
      local steps = math.ceil((length - partLength * 2) / partLength)
      for i = 1, steps do
        local pos = vec2.add(entity.position(), vec2.add(line[1], vec2.mul(dir, i * partLength + 0.25)))
        localAnimator.addDrawable({ image = midPart, position = pos, rotation = angle, fullbright = true}, "Monster-10")
        localAnimator.addLightSource({position = pos, color = {253, 209, 77}})
      end
      localAnimator.addDrawable({
        image = endPart,
        position = vec2.add(entity.position(), vec2.add(line[2], vec2.mul(dir, -0.25))),
        rotation = angle,
        fullbright = true,
      }, "Monster-10")

      if beam.state == 2 and not animationConfig.animationParameter(beamParam) then
        beam.state = 3
        beam.timer = 0.0
      elseif beam.state == 3 and beam.timer > 0.2 then
        self.beams[beamParam] = nil
      end
    end

    beam.timer = beam.timer + dt
  end
end
