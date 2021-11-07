require "/scripts/poly.lua"
require "/scripts/rect.lua"
require "/scripts/pathutil.lua"

function controlFace(direction)
	direction = direction > 0 and 1 or -1
	if npc then
		mcontroller.controlFace(direction)
	else
		if config.getParameter("facingMode", "control") == "transformation" then
			mcontroller.controlFace(1)
			animator.resetTransformationGroup("facing")
			animator.scaleTransformationGroup("facing", {util.toDirection(direction), 1})
			self.facingDirection = direction
		else
			mcontroller.controlFace(direction)
		end
	end
end

-- param position
-- param run
-- param runSpeed
-- param groundPosition
-- param minGround
-- param maxGround
-- param avoidLiquid
-- output direction
-- output pathfinding
function moveToPosition(args, board, node)
	if args.position == nil then return false end

	if entity.entityType() == "npc" then npc.resetLounging() end
	local pathOptions = applyDefaults(args.pathOptions or {}, {
		returnBest = false,
		mustEndOnGround = mcontroller.baseParameters().gravityEnabled,
		maxDistance = 600,
		swimCost = 5,
		dropCost = 1,
		boundBox = mcontroller.boundBox(),
		droppingBoundBox = rect.pad(mcontroller.boundBox(), {0.2, 0}), --Wider bound box for dropping
		standingBoundBox = rect.pad(mcontroller.boundBox(), {-0.7, 0}), --Thinner bound box for standing and landing
		smallJumpMultiplier = 1 / math.sqrt(2), -- 0.5 multiplier to jump height
		jumpDropXMultiplier = 1,
		enableWalkSpeedJumps = true,
		enableVerticalJumpAirControl = true,
		maxFScore = 800,
		maxNodesToSearch = 70000,
		maxLandingVelocity = -20.0,
		liquidJumpCost = 15
	})
	local pathCheck = applyDefaults(args.pathOptions or {}, {
		returnBest = false,
		mustEndOnGround = mcontroller.baseParameters().gravityEnabled,
		maxDistance = 100,
		swimCost = 5,
		dropCost = 1,
		boundBox = mcontroller.boundBox(),
		droppingBoundBox = rect.pad(mcontroller.boundBox(), {0.2, 0}), --Wider bound box for dropping
		standingBoundBox = rect.pad(mcontroller.boundBox(), {-0.7, 0}), --Thinner bound box for standing and landing
		smallJumpMultiplier = 1 / math.sqrt(2), -- 0.5 multiplier to jump height
		jumpDropXMultiplier = 1,
		enableWalkSpeedJumps = true,
		enableVerticalJumpAirControl = true,
		maxFScore = 200,
		maxNodesToSearch = 100,
		maxLandingVelocity = -20.0,
		liquidJumpCost = 15
	})


	local lastPosition = false
	local targetPosition = {args.position[1], args.position[2]}

	local updateTarget = function()
		lastPosition = {args.position[1], args.position[2]}
		if args.groundPosition then
			targetPosition = findGroundPosition(lastPosition, args.minGround, args.maxGround, args.avoidLiquid)
		end
	end

	updateTarget()
	if not targetPosition then
		return false, {pathfinding = mcontroller.pathfinding(), direction = mcontroller.facingDirection(), targetReachable = false}
	end
	local result = mcontroller.controlPathMove(targetPosition, args.run, pathOptions)
	local path = world.findPlatformerPath(mcontroller.position(),targetPosition,mcontroller.baseParameters(),pathCheck)
	local targetReachable = false
	local unreachableCount = 0
	while true do
		if not lastPosition or world.magnitude(targetPosition, lastPosition) > 2 then
			updateTarget()
			if not targetPosition then
				return false, {pathfinding = mcontroller.pathfinding(), direction = mcontroller.facingDirection(), targetReachable = false}
			end
			path = world.findPlatformerPath(mcontroller.position(),targetPosition,mcontroller.baseParameters(),pathCheck)
		end
		if result == false or result == true then
			return result, {pathfinding = mcontroller.pathfinding(), direction = mcontroller.facingDirection(), targetReachable = targetReachable}
		end
		result = mcontroller.controlPathMove(targetPosition, args.run, pathOptions)
		if not self.setFacingDirection then 
			if not mcontroller.groundMovement() then
				controlFace(mcontroller.velocity()[1])
			elseif mcontroller.running() or mcontroller.walking() then
				controlFace(mcontroller.movingDirection())
			end
		end
		if path then
			targetReachable = true
			unreachableCount = 0
		else
			targetReachable = false
			unreachableCount = unreachableCount + 1
			if unreachableCount > 5 then
				return false
			end
		end
		if entity.entityType() == "npc" then
			--openDoorsAhead()
			if args.closeDoors then
				closeDoorsBehind()
			end
		end
		coroutine.yield(nil, {pathfinding = mcontroller.pathfinding(), direction = mcontroller.facingDirection(), targetReachable = targetReachable, targetPosition = targetPosition})
	end

	return true
end

-- param checkCollision
-- param entity
-- param turnSpeed
-- param minRange
-- output angle
-- output direction
function approachTurn(args, output, _, dt)
	local targetPosition = world.entityPosition(args.entity)
	local distance = world.magnitude(targetPosition, mcontroller.position())
	while true do
		local toTarget = world.distance(targetPosition, mcontroller.position())
		local angle = mcontroller.rotation()
	
	if args.minRange < distance then
		local targetAngle = vec2.angle(toTarget)
		local diff = util.angleDiff(angle, targetAngle)
		if diff ~= 0 then
			angle = angle + (util.toDirection(diff) * args.turnSpeed) * dt
			if util.angleDiff(angle, targetAngle) * diff < 0 then
			angle = targetAngle
			end
		end
		if args.checkCollision then
			local collisionRect = rect.translate(mcontroller.boundBox(), vec2.add(mcontroller.position(), vec2.withAngle(angle, 0.25)))
			if world.rectTileCollision(collisionRect) then
				angle = angle + math.pi
				mcontroller.setVelocity(vec2.mul(mcontroller.velocity(), -1))
			end
		end

		mcontroller.setRotation(angle)
		local speedRatio = math.max(0.2, vec2.dot(vec2.norm(toTarget), vec2.withAngle(angle)) ^ 3)
		local speed = speedRatio * mcontroller.baseParameters().flySpeed
		mcontroller.controlApproachVelocity(vec2.withAngle(angle, speed), mcontroller.baseParameters().airForce, true)
		mcontroller.controlApproachVelocityAlongAngle(angle + math.pi * 0.5, 0, 50, false)
	end
		coroutine.yield(nil, {angle = angle, direction = diff})

		targetPosition = world.entityPosition(args.entity)
		distance = world.magnitude(targetPosition, mcontroller.position())
	end
end

