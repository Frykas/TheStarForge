require "/scripts/vec2.lua"

function update(dt)
  localAnimator.clearDrawables()
  
  updateProgress()
end

function updateProgress()
  local progressConfig = animationConfig.animationParameter("progressConfig")
  if progressConfig then
    local barWidth = progressConfig.totalProgress * progressConfig.animConfig.chunkXSeparation
	local chunkInterval = barWidth / progressConfig.totalProgress
	local finalOffset = barWidth/2 + chunkInterval/2
	--Background caps
	local startPos = vec2.add(entity.position(), {-finalOffset, 0})
	local startCap = {
        image = progressConfig.animConfig.chunkImages .. ":start",
	    position = startPos,
	    centered = true,
	    fullbright = true
	}
    localAnimator.addDrawable(startCap, progressConfig.animConfig.renderLayer .. "+5")
	
	local endPos = vec2.add(entity.position(), {barWidth + chunkInterval - finalOffset, 0})
	local endCap = {
        image = progressConfig.animConfig.chunkImages .. ":end",
	    position = endPos,
	    centered = true,
	    fullbright = true
	}
    localAnimator.addDrawable(endCap, progressConfig.animConfig.renderLayer .. "+5")
	
	--Chunks
    for i = 1, progressConfig.totalProgress do
	  local chunkOffset = chunkInterval * i
	
	  --Progress
	  local chunkState = (i <= progressConfig.currentProgress) and "complete" or "incomplete"
	  local chunkImage = progressConfig.animConfig.chunkImages .. ":" .. chunkState
	
	  local imagePos = vec2.add(entity.position(), {chunkOffset - finalOffset, 0})
	  local progressChunk = {
        image = chunkImage,
	    position = imagePos,
	    centered = true,
	    fullbright = (chunkState == "complete") and true or false
      }
      localAnimator.addDrawable(progressChunk, progressConfig.animConfig.renderLayer .. "+6")
	  
	  --Background
	  local backgroundImage = progressConfig.animConfig.chunkImages .. ":middle"
	  
	  local backgroundChunk = {
        image = backgroundImage,
	    position = imagePos,
	    centered = true,
	    fullbright = true
      }
      localAnimator.addDrawable(backgroundChunk, progressConfig.animConfig.renderLayer .. "+5")
    end
  end
end
