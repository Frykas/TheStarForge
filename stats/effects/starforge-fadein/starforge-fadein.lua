function init()
  self.baseEffectDuration = effect.duration()
end

function update(dt)
  local fade = toHex(255 - math.floor(255 * (effect.duration() / self.baseEffectDuration)))
  effect.setParentDirectives("?multiply=FFFFFF".. fade)
  
  world.debugText("Fade = %s", fade, mcontroller.position(), "red")
end

function toHex(num)
  local hex = string.format("%X", math.floor(num + 0.5))
  if num < 16 then hex = "0"..hex end
  return hex
end

--/spawnitem antidote 1 '{"description":"Use this to test a status effect.","shortdescription":"Test Potion","maxstack":100,"effects":[["starforge-fadein"]]}'