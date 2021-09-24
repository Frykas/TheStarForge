idleState = {}

function idleState.enter()
  if hasTarget() then return nil end

  return {
  }
end

function idleState.enteringState(stateData)
end

function idleState.update(dt, stateData)
end
