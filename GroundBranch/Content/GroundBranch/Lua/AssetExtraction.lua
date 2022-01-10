-- WIP

local m = require('TerroristHunt')
m.StringTables = { "AssetExtraction" }
m.VipPlayerStarts = {}
m.ExtractionPoints = {}
m.ExtractionPointMarkers = {}
m.VipSpawned = false
m.VipDead = false

function m:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpForTeamTag) then
				timer.Set("CheckOpForCount", self, self.CheckOpForCountTimer, 1.0, false)
			else
				player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
				--#region New code
				local ps = player.GetPlayerState(CharacterController)
				if ps and actor.HasTag(ps, 'VIP') then
					print('VIP KIA!')
					self.VipDead = true
				else 
					print('Regular player KIA.')
				end
				--#endregion

				local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
				if #PlayersWithLives == 0 then
					self:CheckBluForCountTimer()
					-- call immediately because round is about to end and nothing more can happen
				else
					timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
				end
				
			end
		end
	end
end


function m:PreInit()
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	local PriorityIndex = 1
	
	local TotalSpawns = 0

	local CurrentPriorityGroup = 1
	local CurrentGroupTotal = 0
	local CurrentPriorityGroupSpawns = {}
	-- this needs to be outside the loop
	
	self.SpawnPriorityGroups = {}
	
	--gamemode.SetPlayerTeamRole(PlayerTeams.BluFor.TeamId, "Attackers")
	-- only need to set this once

	-- Orders spawns by priority while allowing spawns of the same priority to be randomised.
	for i, PriorityTag in ipairs(self.PriorityTags) do
		local bFoundTag = false

		if CurrentPriorityGroup <= #self.SpawnPriorityGroupIDs then
			if PriorityTag == self.SpawnPriorityGroupIDs[CurrentPriorityGroup] then
				-- we found the priority tag corresponding to the start of the next priority group
				self.SpawnPriorityGroups[CurrentPriorityGroup] = self:DumbTableCopy(CurrentPriorityGroupSpawns)
				print("PreInit(): " .. CurrentGroupTotal .. " total spawns found for priority group " .. CurrentPriorityGroup )
				CurrentPriorityGroup = CurrentPriorityGroup + 1
				CurrentGroupTotal = 0
				CurrentPriorityGroupSpawns = {}
			end
		end

		
		for j, SpawnPoint in ipairs(AllSpawns) do
			if actor.HasTag(SpawnPoint, PriorityTag) then
						--print("X ".. SpawnPoint.Loadout)
				bFoundTag = true
				if self.PriorityGroupedSpawns[PriorityIndex] == nil then
					self.PriorityGroupedSpawns[PriorityIndex] = {}
				end
				-- Ensures we can't spawn more AI then this map can handle.
				TotalSpawns = TotalSpawns + 1 
				table.insert(self.PriorityGroupedSpawns[PriorityIndex], SpawnPoint)
				-- this is the table for the old method, which we may still want to use e.g. at low T counts

				table.insert(CurrentPriorityGroupSpawns, SpawnPoint)
				CurrentGroupTotal = CurrentGroupTotal + 1
				-- also store in the table of spawnpoints for the new method
			end
		end

		-- Ensures we don't create empty tables for unused priorities.
		if bFoundTag then
			PriorityIndex = PriorityIndex + 1
			self.LastSpawnPriorityGroup = CurrentPriorityGroup
		end
	end
	
	self.SpawnPriorityGroups[CurrentPriorityGroup] = CurrentPriorityGroupSpawns
	print("PreInit(): " .. CurrentGroupTotal .. " total spawns found for priority group " .. CurrentPriorityGroup )
	self.TotalNumberOfSpawnsFound = TotalSpawns
	
	TotalSpawns = math.min(ai.GetMaxCount(), TotalSpawns)
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)

	self.Settings.ShowRemaining.Max = TotalSpawns
	self.Settings.ShowRemaining.Value = math.min(self.Settings.ShowRemaining.Value, TotalSpawns)

	--#region New code
	self.VipPlayerStarts = gameplaystatics.GetAllActorsOfClassWithTag('GroundBranch.GBPlayerStart', 'VipPlayerStart')
	self.NonVipPlayerStarts = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	self.ExtractionPoints = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C')
	--#endregion
end

function m:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		ai.CleanUp(self.OpForTeamTag)
		self.BumRushMode = false
		self:RandomiseObjectives()
	elseif RoundStage == "PreRoundWait" then
		self.VipSpawned = false
		gamemode.SetTeamAttitude(0, 100, 'Friendly')
		gamemode.SetTeamAttitude(100, 0, 'Friendly')
		self:SpawnOpFor()
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
	elseif RoundStage == "InProgress" then
		actor.SetActive(self.ExtractionPoints[self.ExtractionPointIndex], true)
		--gamemode.SetRoundStageTime(self.Settings.RoundTime.Value * 60.0)
		--does not work because round stage time is set immediately afterwards based on RoundTime
	end
end


--#region New code
function m:GetSpawnInfo(PlayerState)
	--actor.SetTeamId(PlayerState, 1)
	local insertionPoint = player.GetInsertionPoint(PlayerState)
	local isVipInsertion = actor.HasTag(insertionPoint, 'VipInsertionPoint')

	print("Insertion point")
	local item = insertionPoint
	print(actor.GetName(item) .. " " .. table.concat(actor.GetTags(item), ", "))

	local x = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
	for _i, item in ipairs(x) do
		print(actor.GetName(item) .. " " .. table.concat(actor.GetTags(item), ", "))
	end
	print("-- Done")

	actor.RemoveTag(PlayerState, 'VIP')

	if not isVipInsertion then
		return nil
	end

	if self.VipSpawned then
		print("Tagging " .. player.GetName(PlayerState) .. " as not VIP")
		player.SetInsertionPoint(PlayerState, self.NonVipPlayerStarts[1])
		return nil
	end

	m.VipSpawned = true

	print("Tagging " .. player.GetName(PlayerState) .. " as VIP")
	-- actor.SetTeamId(PlayerState, 0) (to allow TK-ing, but needs to be reset)
	actor.AddTag(PlayerState, 'VIP')
	local i = #self.VipPlayerStarts
	return self.VipPlayerStarts[ umath.random(i) ]
end
--#endregion

function m:RandomiseObjectives()
	gamemode.ClearGameObjectives()
	gamemode.ClearSearchLocations()
	self.VipDead = false

	for i = 1, #self.ExtractionPoints do
		local Location = actor.GetLocation(self.ExtractionPoints[i])
		local ExtractionMarkerName = "Exfil"
		self.ExtractionPointMarkers[i] = gamemode.AddObjectiveMarker(Location, self.PlayerTeams.BluFor.TeamId, ExtractionMarkerName, "Extraction", false)
		-- NB new penultimate parameter of MarkerType ("Extraction" or "MissionLocation", at present)
	end
	self.ExtractionPointIndex = umath.random(#self.ExtractionPoints)
	print("Index is " .. self.ExtractionPointIndex)
	-- this is the current extraction point

	for i = 1, #self.ExtractionPoints do
		local bActive = (i == self.ExtractionPointIndex)
		actor.SetActive(self.ExtractionPointMarkers[i], bActive)
		actor.SetActive(self.ExtractionPoints[i], false)
		-- set extraction marker to active but don't turn on flare yet
	end
	actor.SetActive(self.ExtractionPoints[self.ExtractionPointIndex], true)
end

function m:CheckBluForCountTimer()
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
	if #PlayersWithLives == 0 or self.VipDead then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
	if self.VipDead then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=VipEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

return m

