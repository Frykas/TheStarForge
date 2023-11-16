local baseInit = init or function() end
function init() baseInit()
  self.fullPower = projectile.power()
  self.armourPiercingDamage = self.fullPower * config.getParameter("armourPiercingFactor", 0.5)
  projectile.setPower(self.fullPower - self.armourPiercingDamage)
  self.effect = config.getParameter("effectOverwrite", "starforge-armourpiercing")
end

local baseHit = hit or function() end
function hit(entityId) baseHit(entityId)
  world.sendEntityMessage(entityId, "applyStatusEffect", self.effect, self.armourPiercingDamage, projectile.sourceEntity() or entity.id())
end

