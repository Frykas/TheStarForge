require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

--Tactical planner script for NPC Combat
function npcCombat(dt)
	if not world.entityExists(self.goal) then
		self.success = true
		return
	end
	local entityPosition = world.entityPosition(self.goal)
	self.groupResources:set("targetPosition", entityPosition)

	if not self.npcBounds or not self.npcPoly then
		if self.group.members[1] then
			self.npcBounds = world.callScriptedEntity(self.group.members[1], "mcontroller.boundBox")
			self.npcPoly = world.callScriptedEntity(self.group.members[1], "mcontroller.collisionPoly")
		end
	end
	if not self.updatedDt then
		script.setUpdateDelta(30)
		self.updatedDt = true
	end
	setMeleeAttackerPositions()
	setRangedAttackerPositions()
end

function rangedWeaponData(npcId)
	local item = world.entityHandItem(npcId, "primary")
	local weaponData = root.itemConfig(item)
	if weaponData then
		weaponData = weaponData.config.starforgeNpcWeaponData
	end
	if not weaponData then
		weaponData = config.getParameter("npcCombat.rangedWeaponRanges")
		weaponData = weaponData[item] or weaponData.default
	end
	if weaponData.primaryArcProjectile and not (weaponData.primaryArcGravity and weaponData.primaryArcSpeed) then
		local primaryArcProjectileData = root.projectileConfig(weaponData.primaryArcProjectile)
		if not weaponData.primaryArcSpeed then
			weaponData.primaryArcSpeed = primaryArcProjectileData.speed or 50
		end
		if not weaponData.primaryArcGravity then
			weaponData.primaryArcGravity = (primaryArcProjectileData.movementSettings and primaryArcProjectileData.movementSettings.gravityMultiplier) or root.projectileGravityMultiplier(weaponData.primaryArcProjectile)
		end
	end
	if weaponData.altArcProjectile and not (weaponData.altArcGravity and weaponData.altArcSpeed) then
		local altArcProjectileData = root.projectileConfig(weaponData.altArcProjectile)
		if not weaponData.altArcSpeed then
			weaponData.altArcSpeed = altArcProjectileData.speed or 50
		end
		if not weaponData.altArcGravity then
			weaponData.altArcGravity = (altArcProjectileData.movementSettings and altArcProjectileData.movementSettings.gravityMultiplier) or root.projectileGravityMultiplier(weaponData.altArcProjectile)
		end
	end
	return weaponData
end

function meleeWeaponData(npcId)
	local item = world.entityHandItem(npcId, "primary")
	local weaponData = root.itemConfig(item)
	if weaponData then
		weaponData = weaponData.config.starforgeNpcWeaponData
	end
	if not weaponData then
		weaponData = config.getParameter("npcCombat.meleeWeaponRanges")
		weaponData = weaponData[item] or weaponData.default
	end
	return weaponData
end

--Sets attack positions for all melee attackers
function setMeleeAttackerPositions()
	if self.tasks["melee"] and #self.tasks["melee"].members > 0 then
		local usedPositions = {}
		local targetPosition = world.entityPosition(self.goal)

		local memberRanges = util.map(self.tasks["melee"].members, function(memberId)
			local weaponData = meleeWeaponData(memberId)			
			self.memberResources[memberId]:set("maxRange", weaponData.maxRange + 1)
			self.memberResources[memberId]:set("maxYRange", (weaponData.maxYRange or 4) + 1)
			self.memberResources[memberId]:set("primaryCharge", (weaponData.primaryCharge or 0))
			self.memberResources[memberId]:set("altRange", (weaponData.altRange or nil))
			self.memberResources[memberId]:set("altCharge", (weaponData.altCharge or 0))
			self.memberResources[memberId]:set("altChance", (weaponData.altChance or 0))
			self.memberResources[memberId]:set("permaChargePrimary", weaponData.permaChargePrimary or nil)
			self.memberResources[memberId]:set("permaChargeAlt", weaponData.permaChargeAlt or nil)
			return {memberId, weaponData}
		end)

		table.sort(memberRanges, function(a,b) return a[2].maxRange > b[2].maxRange end)
		local maxRange = memberRanges[1][2].maxRange
		table.sort(memberRanges, function(a,b) return a[2].minRange < b[2].minRange end)
		local minRange = memberRanges[1][2].minRange

		local validPositions = attackPositionsAlongGround(minRange, maxRange, targetPosition)
		local forceSuccess
		if not validPositions or not validPositions[1] then
			validPositions = attackPositionsAlongGround(1, maxRange + 10, targetPosition)
			forceSuccess = true
		end
		for _,pair in pairs(memberRanges) do
			local npcPosition = world.entityPosition(pair[1])
			table.sort(validPositions, function(a,b)
				local aToTarget = world.magnitude(targetPosition, a)
				local bToTarget = world.magnitude(targetPosition, b)

				-- For two positions at very similar distance to the target, pick the one closest to the npc
				if math.abs(aToTarget - bToTarget) < 0.5 then
					return world.magnitude(npcPosition, a) < world.magnitude(npcPosition, b)
				end

				-- In all other cases, closer to target is better
				return aToTarget < bToTarget
			end)

			local movePosition = util.find(validPositions, function(position)
				local distance = math.abs(world.distance(position, targetPosition)[1])
				if not forceSuccess and (distance > pair[2].maxRange or distance < pair[2].minRange) then return false end

				return util.find(usedPositions, function(usedPosition) return world.magnitude(position, usedPosition) < 1 end) == nil
			end)

			table.insert(usedPositions, movePosition)
			self.memberResources[pair[1]]:set("meleePosition", movePosition)
		end
	end
end

--Sets attack positions for all ranged attackers
function setRangedAttackerPositions()
	local targetPosition = world.entityPosition(self.goal)

	if self.tasks["ranged"] and self.tasks["ranged"].members then
		local usedPositions = {}

		local memberRanges = util.map(self.tasks["ranged"].members, function(memberId)
			local weaponData = rangedWeaponData(memberId, true)
			util.debugCircle(world.entityPosition(memberId), weaponData.minRange, "red", 50)
			util.debugCircle(world.entityPosition(memberId), weaponData.maxRange, "green", 50)
			util.debugCircle(world.entityPosition(memberId), weaponData.forceMoveRange, "blue", 50)
			
			self.memberResources[memberId]:set("maxRange", weaponData.forceMoveRange)
			self.memberResources[memberId]:set("minRange", weaponData.minRange)
			self.memberResources[memberId]:set("maxAltRange", weaponData.maxAltRange or nil)
			self.memberResources[memberId]:set("minAltRange", weaponData.minAltRange or nil)
			self.memberResources[memberId]:set("altCharge", weaponData.altCharge or 0)
			self.memberResources[memberId]:set("primaryCharge", weaponData.primaryCharge or 0)
			self.memberResources[memberId]:set("altChance", weaponData.altChance or 0)
			self.memberResources[memberId]:set("permaChargePrimary", weaponData.permaChargePrimary or nil)
			self.memberResources[memberId]:set("permaChargeAlt", weaponData.permaChargeAlt or nil)
			self.memberResources[memberId]:set("primaryArcGravity", weaponData.primaryArcGravity or nil)
			self.memberResources[memberId]:set("altArcGravity", weaponData.altArcGravity or nil)
			self.memberResources[memberId]:set("primaryArcSpeed", weaponData.primaryArcSpeed or nil)
			self.memberResources[memberId]:set("altArcSpeed", weaponData.altArcSpeed or nil)
			return {memberId, weaponData}
		end)

		-- Filter out npcs that are already in a good ranged position
		local needPosition = util.filter(memberRanges, function(pair)
			local positions = {
				--self.memberResources[pair[1]]:get("movePosition"),
				world.entityPosition(pair[1])
			}
			for _,position in pairs(positions) do
				local targetDistance = world.magnitude(targetPosition, position)
				if targetDistance < (pair[2].forceMoveRange or 100) and targetDistance > (pair[2].minRange - 1) and not world.lineTileCollision(position, targetPosition) then
					table.insert(usedPositions, position)
					self.memberResources[pair[1]]:set("movePosition", position)
					return false
				end
			end
			return true
		end)

		if #needPosition > 0 then
			-- Get biggest and smallest ranges for attackers
			table.sort(needPosition, function(a,b) return a[2].maxRange > b[2].maxRange end)
			local maxRange = needPosition[1][2].maxRange
			table.sort(needPosition, function(a,b) return a[2].minRange < b[2].minRange end)
			local minRange = needPosition[1][2].minRange

			local rangedPositions = attackPositionsInRange(maxRange, minRange, targetPosition)
			local i = 1
			local forceSuccess
			while (not rangedPositions or not rangedPositions[1]) and i <= 10 do
				rangedPositions = attackPositionsInRange(i * 10, i-1 * 10, targetPosition)
				i = i + 1
				forceSuccess = true
			end

			-- Find a good position for npcs that need one
			for _,pair in pairs(needPosition) do
				local npcPosition = world.entityPosition(pair[1])
				table.sort(rangedPositions, function(a,b)
					return world.magnitude(a, npcPosition) < world.magnitude(b, npcPosition)
				end)

				-- Get closest open position
				local movePosition = util.find(rangedPositions, function(position)
					local magnitude = world.magnitude(targetPosition, position)
					-- make sure the position is in range
					if not forceSuccess and (magnitude < (pair[2].minRange - 1) or magnitude > pair[2].maxRange) then return false end

					-- If we can't find a close position in the already used positions, it's available
					return util.find(usedPositions, function(used) return world.magnitude(position, used) < 2 end) == nil
				end)
				table.insert(usedPositions, movePosition)
				self.memberResources[pair[1]]:set("movePosition", movePosition)
			end
		end
	end
end

function attackPositionsAlongGround(minRange, maxRange, targetPosition)
	local positions = {}

	for range = math.floor(minRange), math.ceil(maxRange) do
		range = math.max(minRange, math.min(maxRange, range))

		for _,dir in pairs({1,-1}) do
			local groundPosition = findGroundAttackPosition(vec2.add(targetPosition, {dir * range, 0}), -range, range, targetPosition, self.npcBounds)
			if groundPosition then
				world.debugPoint(groundPosition, "green")
				table.insert(positions, groundPosition)
			end
		end
	end

	return positions
end

function attackPositionAlongLine(startLine, endLine)
	local toEnd = world.distance(endLine, startLine)
	local dir = util.toDirection(toEnd[1])

	while toEnd[1] * dir > 0 do
		local groundPosition = findGroundAttackPosition(startLine, -4, 4, endLine, self.npcBounds, self.npcPoly)
		if groundPosition then
			return groundPosition
		end
		startLine[1] = startLine[1] + dir
		toEnd = world.distance(endLine, startLine)
	end

	return endLine
end


function validAttackPosition(position, bounds, avoidLiquid)
	local groundRegion = {
		position[1] + bounds[1], position[2] + bounds[2] - 1,
		position[1] + bounds[3], position[2] + bounds[2]
	}
	if avoidLiquid then
		local liquidLevel = world.liquidAt(rect.translate(bounds, position))
		if liquidLevel and liquidLevel[2] >= 0.1 then
			return false
		end
	end
	
	if not world.rectTileCollision(rect.translate(bounds, position), {"Null", "Block"}) and world.rectTileCollision(groundRegion, {"Null", "Block", "Dynamic", "Platform"}) then
		return true
	else
		return false
	end
end

--Find a valid ground position
function findGroundAttackPosition(position, minHeight, maxHeight, losPosition, bounds)
	position[2] = math.ceil(position[2]) - (bounds[2] % 1)
	for y = maxHeight, minHeight, -1 do
		local testPosition = {position[1], position[2] + y}
		if validAttackPosition(testPosition, bounds) and not world.lineTileCollision(testPosition, losPosition) then
			return testPosition
		end
	end
end

function attackPositionsInRange(maxRange, minRange, center)
	local positions = {}
	local range = maxRange
	while range >= minRange do
		local step = (math.pi / 2) / range
		local maxSteps = math.min(range, 25)
		for i = 0, maxSteps do
			local yStep = (range / maxSteps)
			local y = i * yStep
			local x = range * math.cos(math.asin(i/maxSteps))

			for _,xDir in ipairs({1, -1}) do
				for _,yDir in ipairs({1, -1}) do
					local position = {center[1] + xDir * x, center[2] + yDir * y}
					position[2] = math.ceil(position[2]) - (self.npcBounds[2] % 1)
					if validAttackPosition(position, self.npcBounds, true) and not world.lineTileCollision(position, vec2.add(center, {0, -1})) then
						world.debugPoint(position, "green")
						table.insert(positions, position)
					end
				end
			end
		end

		range = range - 1
	end
	return positions
end
