function init()
  local entityType = entity.entityType()

  --This mess might be temporary but it is a way to figure out how much damage was dealt from that shot
  local intEffectiveness = math.floor(math.fmod(effect.duration(), 10000) + 0.5)
  local effectiveness = intEffectiveness / 1000

  local damageFromHit = math.floor((effect.duration() / 10000) + 0.5)
  local shieldDamage = damageFromHit * effectiveness

  self.damageFromHit = root.evalFunction2("protection", damageFromHit, status.stat("protection"))

  --Monsters use a resource called shieldHealth rather than a stat
  --Do the duration as raw damage to the shield, then another 25% of the duration as percentage damage, for example, 55 duration would be raw 55 damage plus 13.75% of the shield health as damage
  --duration + duration * 0.0025 * shield
  if entityType == "monster" then
    --sb.logInfo("Monster stat: %s", status.resource("shieldHealth"))
    if status.resourcePositive("shieldHealth") and status.resource("shieldHealth") > 0 then
      local damage = -(shieldDamage + (shieldDamage * 0.0025 * status.resource("shieldHealth")))
	    impactShield("shieldHealth", damage, self.damageFromHit)
    end
  else
    --sb.logInfo("Stat: %s", status.stat("shieldHealth"))
    if status.statPositive("shieldHealth") and status.stat("shieldHealth") > 0 then
      local damage = -((shieldDamage / status.stat("shieldHealth")) + (shieldDamage * 0.0025))
  	  impactShield("shieldStamina", damage, self.damageFromHit / status.stat("shieldHealth"))
	    status.setResourcePercentage("shieldStaminaRegenBlock", config.getParameter("shieldStaminaRegenBlockOverride", 1.0))
    end
  
    if status.resourcePositive("damageAbsorption") and status.resource("damageAbsorption") > 0 then
      local damage = -(shieldDamage + (shieldDamage * 0.0025 * status.resource("damageAbsorption")))
	    impactShield("damageAbsorption", damage, self.damageFromHit)
    end
  end
  
  effect.expire()
end


function impactShield(res, damage, initialHitDamage)
  --Convert duration into damage
  --sb.logInfo("Stat: %s", status.resource(res))
  --sb.logInfo("Damage: %s", damage)
  
  --Apply damage to shields
  status.modifyResource(res, damage)
  --sb.logInfo("Damaged Stat: %s", status.resource(res))
  
  if config.getParameter("breakProjectileType") and (status.resource(res) - initialHitDamage) <= 0 then
    explode()
  end
end

function explode()
  if not self.exploded then
    local sourceEntityId = effect.sourceEntity() or entity.id()
    local sourceDamageTeam = world.entityDamageTeam(sourceEntityId)
    local bombPower = self.damageFromHit * config.getParameter("damageFactor", 1.0)
    local projectileConfig = {
      power = bombPower,
      damageTeam = sourceDamageTeam,
      onlyHitTerrain = false,
      timeToLive = 0,
      damageType = "noDamage",
      actionOnReap = {
        {
          action = "projectile",
          type = config.getParameter("breakProjectileType"),
		      config = config.getParameter("breakProjectileParameters")
        }
      }
    }
    world.spawnProjectile("invisibleprojectile", mcontroller.position(), effect.sourceEntity(), {0, 0}, false, projectileConfig)
    self.exploded = true
  end
end