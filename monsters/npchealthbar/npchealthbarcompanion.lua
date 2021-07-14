---
--- Created by Lyrthras#7199.
--- DateTime: 6/26/2021 11:14 AM UTC+08
---

function init()
  monster.setDeathSound(nil)
  monster.setDamageBar("special")

  self.trackingNpc = config.getParameter("trackingNpc")
end


function update(dt)
  if not world.entityExists(self.trackingNpc) then
    status.setResource("health", 0)
  end
end


function uninit()
end

