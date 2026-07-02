require "/scripts/status.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/async.lua"

function init()
  self.healthCooldownFactor = config.getParameter("healthCooldownFactor")
  self.musicStagehands = {}

  self.idleTouchDamage = config.getParameter("idleTouchDamage")
  self.defaultDamageSources = {self.idleTouchDamage or nil}
  self.damageSources = self.defaultDamageSources
  
  self.tookDamage = false
  self.dead = false

  if rangedAttack then
    rangedAttack.loadConfig()
  end

  --Movement
  self.spawnPosition = mcontroller.position()

  self.jumpTimer = 0
  self.isBlocked = false
  self.willFall = false

  self.queryTargetDistance = config.getParameter("queryTargetDistance", 30)
  self.trackTargetDistance = config.getParameter("trackTargetDistance")
  self.switchTargetDistance = config.getParameter("switchTargetDistance")
  self.keepTargetInSight = config.getParameter("keepTargetInSight", true)

  self.targets = {}

  --Non-combat states
  local states = stateMachine.scanScripts(config.getParameter("scripts"), "(%a+State)%.lua")
  self.state = stateMachine.create(states)

  self.state.leavingState = function(stateName)
    self.state.moveStateToEnd(stateName)
  end

  self.skillParameters = {}
  for _, skillName in pairs(config.getParameter("skills")) do
    self.skillParameters[skillName] = config.getParameter(skillName)
  end

  --Load phases
  self.phases = config.getParameter("phases")
  setPhaseStates(self.phases)

  for skillName, params in pairs(self.skillParameters) do
    if type(_ENV[skillName].onInit) == "function" then
      _ENV[skillName].onInit()
    end
  end

  monster.setUniqueId(config.getParameter("uniqueId"))

  monster.setDeathParticleBurst("deathPoof")

  monster.setDamageBar("None")

  self.activeCoroutines = {}
end

function stunBoss(duration, endFunc)
  self.activeCoroutines["stunBoss"] = coroutine.create(function()
    playSound("stun")
    self.stunned = true
    animator.setAnimationState("body", "stunIn")

    wait(duration)

    self.stunned = false
    animator.setAnimationState("body", "stunOut")

    if endFunc ~= nil then
      endFunc()
    end
  end)
end

function startFight()
  playSound("fightStart")
  monster.setDamageBar("Special")
  monster.setAggressive(true)
  setBattleMusicEnabled(config.getParameter("music"))
end

function playSound(sound, pitchVariance)
  if animator.hasSound(sound) then
    pitchVariance = pitchVariance or 0.1
    local pitch = (1 - pitchVariance) + (pitchVariance * 2 * math.random())
    animator.setSoundPitch(sound, pitch)
    animator.playSound(sound)
  else
    sb.logError("Sound %s does not exist", sound)
  end
end

function wait(time, holdFunc, endFunc)
  self.activeCoroutines["wait"] = coroutine.create(function()
    local timer = time

    local dt = script.updateDt()
    while timer > 0 do
      if holdFunc ~= nil and holdFunc(dt, timer) == true then
        timer = 0
      end
      timer = timer - dt
      coroutine.yield(false)
    end

    if endFunc ~= nil then
      endFunc()
    end
  end)
end

function calculatePosition(middlePoint, offset, grounded, alwaysAcrossMiddle)
  local offsetPos = vec2.add(middlePoint, offset)
  local position = (world.lineTileCollisionPoint(middlePoint, offsetPos) or {offsetPos, 0})[1]
  if alwaysAcrossMiddle then
    local toMid = vec2.sub(middlePoint, alwaysAcrossMiddle)
    local toEnd = vec2.sub(position, alwaysAcrossMiddle)

    local midDist = math.sqrt(toMid[1]^2 + toMid[2]^2)
    local dot = (toMid[1] * toEnd[1] + toMid[2] * toEnd[2]) / midDist
    local isBetween = dot > 0 and dot < midDist

    if isBetween then
      position = vec2.sub(vec2.mul(middlePoint, 2), position)
    end
  end

  local poly = mcontroller.collisionPoly()

  local resolvedPosition = world.resolvePolyCollision(poly, position, 10) or position
  local correctedPositionAndNormal = {resolvedPosition, nil}
  if grounded then
    correctedPositionAndNormal = world.lineTileCollisionPoint(resolvedPosition, vec2.add(resolvedPosition, {0, -50})) or {resolvedPosition, 0}
    correctedPositionAndNormal[1] = vec2.add(correctedPositionAndNormal[1], {0, 4})
  end
  correctedPositionAndNormal = world.lineTileCollisionPoint(middlePoint, correctedPositionAndNormal[1]) or {correctedPositionAndNormal[1], 0}
  resolvedPosition = world.resolvePolyCollision(poly, correctedPositionAndNormal[1], 4) or correctedPositionAndNormal[1]

  return resolvedPosition
end

function findRandomPosition(middlePoint, spawnRange, grounded, alwaysAcrossMiddle)
  local offset = {
    randomRange(spawnRange[1]),
    randomRange(spawnRange[2]) + (spawnRange[2] * 0.5)
  }
  local position = vec2.add(middlePoint, offset)
  if alwaysAcrossMiddle then
    local toMid = vec2.sub(middlePoint, alwaysAcrossMiddle)
    local toEnd = vec2.sub(position, alwaysAcrossMiddle)

    local midDist = math.sqrt(toMid[1]^2 + toMid[2]^2)
    local dot = (toMid[1] * toEnd[1] + toMid[2] * toEnd[2]) / midDist
    local isBetween = dot > 0 and dot < midDist

    if isBetween then
      position = vec2.sub(vec2.mul(middlePoint, 2), position)
    end
  end

  local poly = {{-2.25, 2.25}, {2.25, 2.25}, {2.25, -2.25}, {-2.25, -2.25}}

  local resolvedPosition = world.resolvePolyCollision(poly, position, 4) or position
  local correctedPositionAndNormal = {resolvedPosition, nil}
  if grounded then
    correctedPositionAndNormal = world.lineTileCollisionPoint(resolvedPosition, vec2.add(resolvedPosition, {0, -50})) or {resolvedPosition, 0}
  end
  correctedPositionAndNormal = world.lineTileCollisionPoint(middlePoint, correctedPositionAndNormal[1]) or {correctedPositionAndNormal[1], 0}
  resolvedPosition = world.resolvePolyCollision(poly, correctedPositionAndNormal[1], 4) or correctedPositionAndNormal[1]

  return resolvedPosition
end

function randomRange(range)
  return (range * -0.5) + (math.random() * range)
end

function lerpColor(color1, color2, t)
  local result = {}
  for i = 1, 4 do
    result[i] = color2[i] + (color1[i] - color2[i]) * t
  end
  return result
end

function scalePower(power)
  return power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
end

function updateDamageSources(damageSource, ignoreDefault)
  local damageSources = {}
  if not ignoreDefault then
    table.insert(damageSources, self.idleTouchDamage)
  end
  if damageSource and not damageSource.poly then
    for _, source in ipairs(damageSource) do 
      table.insert(damageSources, source)
    end
  else
    table.insert(damageSources, damageSource)
  end
  self.damageSources = damageSources
end

function sanctusTeleport(teleportPos, endSpeed, endFunc)
  self.activeCoroutines["sanctusTeleport"] = coroutine.create(function()
    local dashDir = vec2.norm(world.distance(teleportPos, mcontroller.position()))

    animator.setEffectActive("teleport", true)
    animator.burstParticleEmitter("teleport")
    animator.playSound("blinkDash")
    animator.setAnimationState("body", "invisible")
    mcontroller.controlFace(util.toDirection(world.distance(teleportPos, self.targetPosition or self.spawnPosition)[1]))

    monster.setAnimationParameter("dash", {first = mcontroller.position(), last = teleportPos, config = config.getParameter("dashConfig", {})})

    util.wait(0.1)

    monster.setAnimationParameter("dash", nil)
    mcontroller.setPosition(teleportPos)
    mcontroller.setVelocity(vec2.mul(dashDir, endSpeed))

    if endFunc ~= nil then
      endFunc()
    end
        
    util.wait(0.1)

    animator.setEffectActive("teleport", false)
  end)
end

function endCurrentState()
  if hasTarget() then
    self.phaseStates[currentPhase()].endState()
  end
end

function update(dt)
  for name, co in pairs(self.activeCoroutines) do
    if co and coroutine.status(co) ~= "dead" then
      local ok, err = coroutine.resume(co)
      if not ok then
        sb.logError("Coroutine '%s' error: %s", name, err)
        self.activeCoroutines[name] = nil --Properly remove it
      end
    elseif coroutine.status(co) == "dead" then
      self.activeCoroutines[name] = nil
    end
  end
  
  if self.healthCooldownFactor then
    self.cooldownFactor = self.healthCooldownFactor[1] + (status.resourcePercentage("health") * (self.healthCooldownFactor[2] - self.healthCooldownFactor[1]))
  end

  --Clean dead stagehands
  for stagehand, stagehandTrack in pairs(self.musicStagehands) do
    if stagehand and not world.entityExists(stagehand) then
      stagehand = nil
    end
  end

  monster.setDamageSources(self.damageSources)

  self.tookDamage = false

  if not status.resourcePositive("health") then
    local inState = self.state.stateDesc()
    if inState ~= "dieState" and not self.state.pickState({ die = true }) then
      self.state.endState()
      self.dead = true
    end

    self.state.update(dt)

    cullMusicStagehand()
    setBattleMusicEnabled(false)
  else
    trackTargets(self.keepTargetInSight, self.queryTargetDistance, self.trackTargetDistance, self.switchTargetDistance)

    for skillName, params in pairs(self.skillParameters) do
      if type(_ENV[skillName].onUpdate) == "function" then
        _ENV[skillName].onUpdate(dt)
      end
    end
    setBattleMusicEnabled(config.getParameter("musicStagehands"))
    monster.setDamageBar("Special")
    monster.setAggressive(true)

    if hasTarget() then
      script.setUpdateDelta(1)
      updatePhase(dt)

      animator.setGlobalTag("phase", "phase"..currentPhase())
    else
      if self.hadTarget then
        --Lost target, reset boss
        if currentPhase() then
          self.phaseStates[currentPhase()].endState()
        end
        self.phase = nil
        self.lastPhase = nil
        setPhaseStates(self.phases)
        status.setResource("health", status.stat("maxHealth"))

        if bossReset then bossReset() end
        monster.setDamageBar("None")
        cullMusicStagehand()
        setBattleMusicEnabled(false)
        monster.setAggressive(false)
      end

      script.setUpdateDelta(10)

      if not self.state.update(dt) then
        self.state.pickState()
      end

      cullMusicStagehand()
      setBattleMusicEnabled(false)
    end

    self.hadTarget = hasTarget()
  end
  
  --world.debugText("Current state: %s", self.phaseStates[currentPhase()].stateDesc() or "N/A", mcontroller.position(), "red")
end

function damage(args)
  self.tookDamage = true

  if args.sourceId and args.sourceId ~= 0 and not inTargets(args.sourceId) then
    table.insert(self.targets, args.sourceId)
  end
end

function shouldDie()
  return self.dead
end

function hasTarget()
  if self.targetId and self.targetId ~= 0 then
    return self.targetId
  end
  return false
end

function trackTargets(keepInSight, queryRange, trackingRange)
  if keepInSight == nil then keepInSight = true end

  if #self.targets == 0 then
    local newTarget = util.closestValidTarget(queryRange)
    table.insert(self.targets, newTarget)
  end

  self.targets = util.filter(self.targets, function(targetId)
    if not world.entityExists(targetId) then return false end

    if keepInSight and not entity.entityInSight(targetId) then return false end

    if trackingRange and world.magnitude(mcontroller.position(), world.entityPosition(targetId)) > trackingRange then
      return false
    end

    return true
  end)

  --Set target to be top of the list
  self.targetId = self.targets[1]
  if self.targetId then
    self.targetPosition = world.entityPosition(self.targetId)
  end
end

function validTarget(targetId, keepInSight, trackingRange)
  local entityType = world.entityType(targetId)
  if entityType ~= "player" and entityType ~= "npc" then
    return false
  end

  if not world.entityExists(targetId) then return false end

  if keepInSight and not entity.entityInSight(targetId) then return false end

  if trackingRange then
    local distance = world.magnitude(mcontroller.position(), world.entityPosition(targetId))
    if distance > trackingRange then return false end
  end

  return true
end

function inTargets(entityId)
  for i,targetId in ipairs(self.targets) do
    if targetId == entityId then
      return i
    end
  end
  return false
end

--PHASES-----------------------------------------------------------------------

function currentPhase()
  return self.phase
end

function updatePhase(dt)
  if not self.phase then
    self.phase = 1
  end

  --Check if next phase is ready
  local nextPhase = self.phases[self.phase + 1]
  if nextPhase then
    if nextPhase.trigger and nextPhase.trigger == "healthPercentage" then
      if status.resourcePercentage("health") < nextPhase.healthPercentage then
        self.phase = self.phase + 1
      end
    end
  end

  if not self.lastPhase or self.lastPhase ~= self.phase then
    if self.lastPhase then
      self.phaseStates[self.lastPhase].endState()
    end
    self.phaseStates[currentPhase()].pickState({enteringPhase = currentPhase()})
  end
  if not self.phaseStates[currentPhase()].update(dt) then
    self.phaseStates[currentPhase()].pickState()
  end

  self.lastPhase = self.phase
end

function setPhaseStates(phases)
  self.phaseSkills = {}
  self.phaseStates = {}
  for i,phase in ipairs(phases) do
    self.phaseSkills[i] = {}
    for _,skillName in ipairs(phase.skills) do
      table.insert(self.phaseSkills[i], skillName)
    end
    if phase.enterPhase then
      table.insert(self.phaseSkills[i], 1, phase.enterPhase)
    end
    self.phaseStates[i] = stateMachine.create(self.phaseSkills[i])

    --Cycle through the skills
    self.phaseStates[i].leavingState = function(stateName)
      self.phaseStates[i].moveStateToEnd(stateName)
    end
  end
end

--MOVEMENT---------------------------------------------------------------------

function boundingBox(force)
  if self.boundingBox and not force then return self.boundingBox end

  local collisionPoly = mcontroller.collisionPoly()
  local bounds = {0, 0, 0, 0}

  for _,point in pairs(collisionPoly) do
    if point[1] < bounds[1] then bounds[1] = point[1] end
    if point[2] < bounds[2] then bounds[2] = point[2] end
    if point[1] > bounds[3] then bounds[3] = point[1] end
    if point[2] > bounds[4] then bounds[4] = point[2] end
  end
  self.boundingBox = bounds

  return bounds
end

function checkWalls(direction)
  local bounds = mcontroller.boundBox()
  bounds[2] = bounds[2] + 1
  if direction > 0 then
    bounds[1] = bounds[3]
    bounds[3] = bounds[3] + 0.25
  else
    bounds[3] = bounds[1]
    bounds[1] = bounds[1] - 0.25
  end
  util.debugRect(rect.translate(bounds, mcontroller.position()), "yellow")
  return world.rectTileCollision(rect.translate(bounds, mcontroller.position()), {"Null", "Block", "Dynamic", "Slippery"})
end

function flyTo(position, speed)
  if speed then mcontroller.controlParameters({flySpeed = speed}) end
  local toPosition = vec2.norm(world.distance(position, mcontroller.position()))
  mcontroller.controlFly(toPosition)
end

--------------------------------------------------------------------------------
function move(delta, run, jumpThresholdX)
  checkTerrain(delta[1])

  mcontroller.controlMove(delta[1], run)

  if self.jumpTimer > 0 and not self.onGround then
    mcontroller.controlHoldJump()
  else
    if self.jumpTimer <= 0 then
      if jumpThresholdX == nil then jumpThresholdX = 4 end

      -- We either need to be blocked by something, the target is above us and
      -- we are about to fall, or the target is significantly high above us
      local doJump = false
      if isBlocked() then
        doJump = true
      elseif (delta[2] >= 0 and willFall() and math.abs(delta[1]) > 7) then
        doJump = true
      elseif (math.abs(delta[1]) < jumpThresholdX and delta[2] > config.getParameter("jumpTargetDistance")) then
        doJump = true
      end

      if doJump then
        self.jumpTimer = util.randomInRange(config.getParameter("jumpTime"))
        mcontroller.controlJump()
      end
    end
  end

  if delta[2] < 0 then
    mcontroller.controlDown()
  end
end

--------------------------------------------------------------------------------
--TODO: this could probably be further optimized by creating a list of discrete points and using sensors... project for another time
function checkTerrain(direction)
  --normalize to 1 or -1
  direction = direction > 0 and 1 or -1

  local reverse = false
  if direction ~= nil then
    reverse = direction ~= mcontroller.facingDirection()
  end

  local boundBox = mcontroller.boundBox()

  -- update self.isBlocked
  local blockLine, topLine
  if not reverse then
    blockLine = {monster.toAbsolutePosition({boundBox[3] + 0.25, boundBox[4]}), monster.toAbsolutePosition({boundBox[3] + 0.25, boundBox[2] - 1.0})}
  else
    blockLine = {monster.toAbsolutePosition({-boundBox[3] - 0.25, boundBox[4]}), monster.toAbsolutePosition({-boundBox[3] - 0.25, boundBox[2] - 1.0})}
  end

  local blockBlocks = world.collisionBlocksAlongLine(blockLine[1], blockLine[2])
  self.isBlocked = false
  if #blockBlocks > 0 then
    --check for basic blockage
    local topOffset = blockBlocks[1][2] - blockLine[2][2]
    if topOffset > 2.75 then
      self.isBlocked = true
    elseif topOffset > 0.25 then
      --also check for that stupid little hook ledge thing
      self.isBlocked = not world.pointTileCollision({blockBlocks[1][1] - direction, blockBlocks[1][2] - 1})

      if not self.isBlocked then
        --also check if blocks above prevent us from climbing
        topLine = {monster.toAbsolutePosition({boundBox[1], boundBox[4] + 0.5}), monster.toAbsolutePosition({boundBox[3], boundBox[4] + 0.5})}
        self.isBlocked = world.lineTileCollision(topLine[1], topLine[2])
      end
    end
  end

  -- update self.willFall
  local fallLine
  if reverse then
    fallLine = {monster.toAbsolutePosition({-0.5, boundBox[2] - 0.75}), monster.toAbsolutePosition({boundBox[3], boundBox[2] - 0.75})}
  else
    fallLine = {monster.toAbsolutePosition({0.5, boundBox[2] - 0.75}), monster.toAbsolutePosition({-boundBox[3], boundBox[2] - 0.75})}
  end
  self.willFall =
      world.lineTileCollision(fallLine[1], fallLine[2]) == false and
      world.lineTileCollision({fallLine[1][1], fallLine[1][2] - 1}, {fallLine[2][1], fallLine[2][2] - 1}) == false
end

--------------------------------------------------------------------------------
function isBlocked()
  return self.isBlocked
end

--------------------------------------------------------------------------------
function willFall()
  return self.willFall
end

function cullMusicStagehand(track)
  for stagehand, stagehandTrack in pairs(self.musicStagehands) do
    if not track or stagehandTrack == track then
      world.sendEntityMessage(stagehand, "killStagehand")
    end
  end
end

function createMusicStagehand(track, timeToLive)
  local valid = true
  for stagehand, stagehandTrack in pairs(self.musicStagehands) do
    if stagehandTrack == track then
      valid = false
    end
  end
  if valid then
    local stagehand = world.spawnStagehand(mcontroller.position(), "nebo_improvedbossmusic", {
      broadcastArea = {-self.trackTargetDistance, -self.trackTargetDistance, self.trackTargetDistance, self.trackTargetDistance},
      hostEntity = entity.id(),
      currentTrack = track,
      timeToLive = timeToLive
    })
    table.insert(self.musicStagehands, stagehand)
  end
end

function setBattleMusicEnabled(enabled)
  if self.musicEnabled ~= enabled then
    local musicStagehands = config.getParameter("musicStagehands", {})
    for _, stagehand in pairs(musicStagehands) do
      local entityId = world.loadUniqueEntity(stagehand)

      if entityId and world.entityExists(entityId) then
        world.callScriptedEntity(entityId, "setMusicEnabled", enabled)
        self.musicEnabled = enabled
      end
    end
  end
end