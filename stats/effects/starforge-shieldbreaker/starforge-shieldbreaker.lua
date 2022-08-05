function init()
  local entityType = entity.entityType()
  
  --Monsters use a resource called shieldHealth rather than a stat
  --Do the duration as raw damage to the shield, then another 25% of the duration as percentage damage, for example, 55 duration would be raw 55 damage plus 13.75% of the shield health as damage
  --duration + duration * 0.0025 * shield
  if entityType == "monster" then
    --FIX ON MONSTERS WHERE BULLET BREAKS SHIELD, NOT THIS EFFECT, THEREFORE NO EXPLOSION... CHECK FOR IF SHIELD IS BROKEN BEFORE DAMAGING SHIELD SOMEHOW?
	--MAYBE IN THE BULLET CHECK?
    sb.logInfo("Monster stat: %s", status.resource("shieldHealth"))
    if status.resourcePositive("shieldHealth") and status.resource("shieldHealth") > 0 then
      local damage = -(effect.duration() + (effect.duration() * 0.0025 * status.resource("shieldHealth")))
	  impactShield("shieldHealth", damage)
    end
  else
    sb.logInfo("Stat: %s", status.stat("shieldHealth"))
    if status.statPositive("shieldHealth") and status.stat("shieldHealth") > 0 then
      local damage = -((effect.duration() / status.stat("shieldHealth")) + (effect.duration() * 0.0025))
  	  impactShield("shieldStamina", damage)
	  status.setResourcePercentage("shieldStaminaRegenBlock", config.getParameter("shieldStaminaRegenBlockOverride", 1.0))
    end
  
    if status.resourcePositive("damageAbsorption") and status.resource("damageAbsorption") > 0 then
      local damage = -(effect.duration() + (effect.duration() * 0.0025 * status.resource("damageAbsorption")))
	  impactShield("damageAbsorption", damage)
    end
  end
  
  effect.expire()
end

function impactShield(res, damage)
  --Convert duration into damage
  sb.logInfo("Stat: %s", status.resource(res))
  sb.logInfo("Damage: %s", damage)
  
  --Apply damage to shields
  status.modifyResource(res, damage)
  sb.logInfo("Damaged Stat: %s", status.resource(res))
  
  if config.getParameter("breakProjectileType") and status.resource(res) == 0 then
    explode()
  end
end

function explode()
  if not self.exploded then
    local sourceEntityId = effect.sourceEntity() or entity.id()
    local sourceDamageTeam = world.entityDamageTeam(sourceEntityId)
    local bombPower = status.resourceMax("health") * config.getParameter("healthDamageFactor", 1.0)
    local projectileConfig = {
      power = bombPower,
      damageTeam = sourceDamageTeam,
      onlyHitTerrain = false,
      timeToLive = 0,
      actionOnReap = {
        {
          action = "projectile",
          type = config.getParameter("breakProjectileType"),
		  config = config.getParameter("breakProjectileParameters")
        }
      }
    }
    world.spawnProjectile("invisibleprojectile", mcontroller.position(), 0, {0, 0}, false, projectileConfig)
    self.exploded = true
  end
end