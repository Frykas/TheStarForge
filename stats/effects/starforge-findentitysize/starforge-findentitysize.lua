function update(dt)
  self.sourceEntity = effect.sourceEntity()
  
  self.entitySize = 1
  local boundBox = mcontroller.boundBox()
  for i, coord in ipairs(boundBox) do
	if coord > self.entitySize then
	  self.entitySize = coord
	end
  end

  world.sendEntityMessage(self.sourceEntity, "setParentSize", self.entitySize)
  effect.expire()
end
