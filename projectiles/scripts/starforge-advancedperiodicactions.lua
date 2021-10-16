function init()
end

function update(dt)
  --Advanced Periodic Action
  for _, action in pairs(config.getParameter("advancedPeriodicActions", {})) do
    advancedPeriodicActions(action, dt)
  end
end

function advancedPeriodicActions(action, dt)
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
	  action.specification.destructionTime = projectile.timeToLive() / 2
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
	  projectile.processAction(action)
	  action.loopTimer = action.loopTime
	  if action.loopTimeVariance then
	    action.loopTimer = action.loopTimer + (2 * math.random() - 1) * action.loopTimeVariance
	  end
	end
  else
	projectile.processAction(action)
	action.complete = true
  end
end