function init()
  local entityType = entity.entityType()

  local intEffectiveness = math.floor(math.fmod(effect.duration(), 10000) + 0.5)
  local effectiveness = intEffectiveness / 1000

  local damageFromHit = math.floor((effect.duration() / 10000) + 0.5)
  local shieldDamage = damageFromHit * effectiveness

  self.damageFromHit = root.evalFunction2("protection", damageFromHit, status.stat("protection"))

  if entityType == "monster" then
    if status.resourcePositive("shieldHealth") and status.resource("shieldHealth") > 0 then
      local damage = -(shieldDamage + (shieldDamage * 0.0025 * status.resource("shieldHealth")))
      impactShield("shieldHealth", damage, self.damageFromHit)

    elseif status.statPositive("starforge-shieldHealth") and status.stat("starforge-shieldHealth") > 0 then
      local currentShield = status.stat("starforge-shieldHealth")
      local damage = shieldDamage + (shieldDamage * 0.0025 * currentShield)
      
      status.modifyResource("health", -damage)

      if config.getParameter("breakProjectileType") and (currentShield - self.damageFromHit) <= 0 then
        explode()
      end
    end
  else
    if status.statPositive("shieldHealth") and status.stat("shieldHealth") > 0 then
      local damage = -((shieldDamage / status.stat("shieldHealth")) + (shieldDamage * 0.0025))
      impactShield("shieldStamina", damage, self.damageFromHit / status.stat("shieldHealth"))
      status.setResourcePercentage("shieldStaminaRegenBlock", config.getParameter("shieldStaminaRegenBlockOverride", 1.0))

    elseif status.statPositive("starforge-shieldHealth") and status.stat("starforge-shieldHealth") > 0 then
      local currentShield = status.stat("starforge-shieldHealth")
      local damage = shieldDamage + (shieldDamage * 0.0025 * currentShield)

      status.modifyResource("health", -damage)

      if config.getParameter("breakProjectileType") and (currentShield - self.damageFromHit) <= 0 then
        explode()
      end
    end
  
    if status.resourcePositive("damageAbsorption") and status.resource("damageAbsorption") > 0 then
      local damage = -(shieldDamage + (shieldDamage * 0.0025 * status.resource("damageAbsorption")))
      impactShield("damageAbsorption", damage, self.damageFromHit)
    end
  end
  
  effect.expire()
end

function impactShield(res, damage, initialHitDamage)
  status.modifyResource(res, damage)
  
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