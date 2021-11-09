require "/scripts/vec2.lua"

function init()
  self.advancedPeriodicActions = config.getParameter("advancedPeriodicActions", {})
end

function update(dt)
  --Advanced Periodic Action
  for _, action in pairs(self.advancedPeriodicActions) do
    advancedPeriodicActions(action, dt, _)
  end
end

function advancedPeriodicActions(action, dt, index)
  if action.action == "particle" then
    local baseAction = config.getParameter("advancedPeriodicActions", {})[index]
  
    action.specification.size = baseAction.specification.size * config.getParameter("scaleModifier", 1)
	action.specification.position = vec2.mul(baseAction.specification.position, config.getParameter("scaleModifier", 1))
	action.specification.variance.size = baseAction.specification.variance.size * config.getParameter("scaleModifier", 1)
	action.specification.variance.position = vec2.mul(baseAction.specification.variance.position, config.getParameter("scaleModifier", 1))
  end
  if action.terminateOnDeath then
	if action.action == "projectile" then
	  action.config.timeToLive = projectile.timeToLive()
	elseif action.action == "particle" then
	  action.specification.timeToLive = projectile.timeToLive()
	end
  elseif action.beginDestructionOnDeath then
	if action.action == "projectile" then
	  action.config.timeToLive = projectile.timeToLive() + self.timeToLive
	elseif action.action == "particle" then
	  action.specification.destructionTime = projectile.timeToLive() * 0.5
	end
  end
  
  if action.complete then
	return
  elseif action.delayTime then
	action.delayTime = action.delayTime - dt
	if action.delayTime <= 0 then
	  action.delayTime = nil
	end
  elseif action.loopTime and action.loopTime ~= -1 then
	action.loopTimer = action.loopTimer or 0
	action.loopTimer = math.max(0, action.loopTimer - dt)
	if action.loopTimer == 0 then
	  action.loopTimer = action.loopTime
	  if action.loopTimeVariance then
	    action.loopTimer = action.loopTimer + (2 * math.random() - 1) * action.loopTimeVariance
	  end
	  projectile.processAction(action)
	end
  else
	projectile.processAction(action)
	action.complete = true
  end
end