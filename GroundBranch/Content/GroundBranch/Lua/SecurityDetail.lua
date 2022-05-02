--[[
Security Detail
PvE Ground Branch game mode

Based on 'Kill Confirmed'

Notes for Mission Editing:

  1. Start with a regular 'Kill Confirmed' mission
  ...

]]--

local Teams = require('Players.Teams')
local SpawnsGroups = require('Spawns.Groups')
local SpawnsCommon = require('Spawns.Common')
local ObjectiveExfiltrate = require('Objectives.Exfiltrate')
local Logger = require("Common.Logger")
local AvoidFatality = require("Objectives.AvoidFatality")
local NoSoftFail = require("Objectives.NoSoftFail")

local SCENARIO_OFFSET = 2

local log = Logger.new('SecDet')
log:SetLogLevel('DEBUG')


--#region Properties

local Mode = {
	UseReadyRoom = true,
	UseRounds = true,
	MissionTypeDescription = '[Solo/Co-Op] Extract the principal',
	StringTables = {'SecurityDetail'},
	Settings = {
		Scenario = {
			Min = 0,
			Max = 10, -- hard max
			Value = 0,
			AdvancedSetting = true,
		},
		AvailableForces = {
			Min = 0,
			Max = 2,
			Value = 1,
			AdvancedSetting = false
		},
		OpForPreset = {
			Min = 0,
			Max = 4,
			Value = 2,
			AdvancedSetting = false,
		},
		Difficulty = {
			Min = 0,
			Max = 4,
			Value = 2,
			AdvancedSetting = false,
		},
		RoundTime = {
			Min = 10,
			Max = 60,
			Value = 60,
			AdvancedSetting = false,
		}
	},
	PlayerScoreTypes = {
		KillStandard = {
			Score = 100,
			OneOff = false,
			Description = 'Eliminated threat'
		},
		KillHvt = {
			Score = 250,
			OneOff = false,
			Description = 'Eliminated HVT'
		},
		ConfirmHvt = {
			Score = 750,
			OneOff = false,
			Description = 'Confirmed HVT elimination'
		},
		Survived = {
			Score = 200,
			OneOff = false,
			Description = 'Made it out alive'
		},
		TeamKill = {
			Score = -250,
			OneOff = false,
			Description = 'Killed a teammate'
		},
		Accident = {
			Score = -50,
			OneOff = false,
			Description = 'Killed oneself'
		}
	},
	TeamScoreTypes = {
		KillHvt = {
			Score = 250,
			OneOff = false,
			Description = 'Eliminated HVT'
		},
		ConfirmHvt = {
			Score = 750,
			OneOff = false,
			Description = 'Confirmed HVT elimination'
		},
		Respawn = {
			Score = -1,
			OneOff = false,
			Description = 'Respawned'
		}
	},
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = 'NoTeamCamouflage',
			Script = nil
		},
	},
	AiTeams = {
		OpFor = {
			Tag = 'OpFor',
			CalculatedAiCount = 0,
			Spawns = nil
		},
	},
	Objectives = {
		ProtectVIP = nil,
		Exfiltrate = nil,
	},
	Timers = {
		-- Delays
		CheckBluForCount = {
			Name = 'CheckBluForCount',
			TimeStep = 1.0,
		},
		CheckReadyUp = {
			Name = 'CheckReadyUp',
			TimeStep = 0.25,
		},
		CheckReadyDown = {
			Name = 'CheckReadyDown',
			TimeStep = 0.1,
		},
		SpawnOpFor = {
			Name = 'SpawnOpFor',
			TimeStep = 0.5,
		},
	},
	InsertionPoints = {
		All = {},
		VipEscortScenario = {},
		VipExfilScenario = {},
		AnyVipScenario = {},
		NonVip = {}
	},
	ExfilTagToExfils = {},
	ActiveVipInsertionPoint = nil,
	VipPlayerId = nil,
	-- Whether we have non-combatants in the AO
	IsSemiPermissive = false,
	-- The max. amount of collateral damage before failing the mission
	CollateralDamageThreshold = 3,
	-- Ref. to logger
	Logger = log
}

--#endregion

--#region Helpers
function ArrayItemsWithPrefix(array, prefix)
	local len = #prefix
	local result = {}
	for _, item in ipairs(array) do
		if string.sub(tostring(item), 1, len) == prefix then
			table.insert(result, item)
		end
	end
	return result
end

function PickRandom(tbl)
	local len = #tbl

	if len == 0 then
		return nil
	end

	return tbl[math.random(len)]
end
--#endregion

--#region Preparation

function Mode:PreInit()
	log:Debug('PreInit')

	if self.IsSemiPermissive then
		self.Objectives.AvoidFatality = AvoidFatality.new('NoCollateralDamage')
	else
		self.Objectives.AvoidFatality = AvoidFatality.new(nil)
	end
	self.Objectives.NoSoftFail = NoSoftFail.new()

	self.PlayerTeams.BluFor.Script = Teams:Create(
		1,
		false,
		self.PlayerScoreTypes,
		self.TeamScoreTypes
	)
	-- Gathers all OpFor spawn points by groups
	self.AiTeams.OpFor.Spawns = SpawnsGroups:Create()
	-- Gathers all extraction points placed in the mission
	self.Objectives.Exfiltrate = ObjectiveExfiltrate:Create(
		self,
		self.OnExfiltrated,
		self.PlayerTeams.BluFor.Script,
		5.0,
		1.0
	)
	self.Objectives.ProtectVIP = AvoidFatality.new('ProtectVIP')

	for _, ip in ipairs(gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')) do
		getmetatable(ip).__tostring = function(obj)
			return actor.GetName(obj)
		end

		if not actor.HasTag('DummyIP') then
			table.insert(self.InsertionPoints.All, ip)

			if actor.HasTag(ip, 'VIP-Exfil') then
				table.insert(self.InsertionPoints.VipExfilScenario, ip)
			elseif actor.HasTag(ip, 'VIP-Escort') then
				table.insert(self.InsertionPoints.VipEscortScenario, ip)
			else
				table.insert(self.InsertionPoints.NonVip, ip)
			end
		end
	end

	for _, ip in ipairs(self.InsertionPoints.VipExfilScenario) do
		table.insert(self.InsertionPoints.AnyVipScenario, ip)
	end

	for _, ip in ipairs(self.InsertionPoints.VipEscortScenario) do
		table.insert(self.InsertionPoints.AnyVipScenario, ip)
	end

	if #self.InsertionPoints.AnyVipScenario < 10 then
		self.Settings.Scenario.Max = SCENARIO_OFFSET + #self.InsertionPoints.AnyVipScenario
	end

	self.ExfilTagToExfils = {}

	for idx, ip in ipairs(self.Objectives.Exfiltrate.Points.All) do
		local tags = ArrayItemsWithPrefix(actor.GetTags(ip), 'Exfil-')
		for _, tag in ipairs(tags) do
			if not self.ExfilTagToExfils[tag] then
				self.ExfilTagToExfils[tag] = {}
			end
			local item = {Index = idx, Actor = ip}
			table.insert(self.ExfilTagToExfils[tag], item)
		end
	end

	log:Debug('ExfilTags', self.ExfilTagToExfils)
end

function Mode:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ProtectVIP', 1)
	if self.IsSemiPermissive then
		gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'NoCollateralDamage', 1)
	end
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateBluFor', 1)
end

--#endregion

--#region Common

function Mode:OnRoundStageSet(RoundStage)
	log:Debug('Started round stage', RoundStage)

	timer.ClearAll()
	if RoundStage == 'WaitingForReady' then
		self.VipPlayerId = '?none?'
		self:PreRoundCleanUp()
		self:RandomizeObjectives()
	elseif RoundStage == 'PreRoundWait' then
		self:SetUpOpForStandardSpawns()
		self:SpawnOpFor()
	elseif RoundStage == 'InProgress' then
		self.PlayerTeams.BluFor.Script:DisplayMessageToAllPlayers('Protect the VIP', 'Engine', 5.0, 'Always')
		self.Objectives.Exfiltrate:SelectedPointSetActive(true)
		self.PlayerTeams.BluFor.Script:RoundStart(
			10000,
			false,
			false,
			true,
			false
		)
	end
end

function Mode:OnCharacterDied(Character, CharacterController, KillerController)
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		if CharacterController ~= nil then
			local killedTeam = actor.GetTeamId(CharacterController)
			local killerTeam = nil
			if KillerController ~= nil then
				killerTeam = actor.GetTeamId(KillerController)
			end
			if actor.HasTag(CharacterController, self.AiTeams.OpFor.Tag) then
				if killedTeam == 10 and killerTeam == self.PlayerTeams.BluFor.TeamId then
					self.Objectives.AvoidFatality:ReportFatality()
					self.PlayerTeams.BluFor.Script:AwardPlayerScore(KillerController, 'CollateralDamage')
					self.PlayerTeams.BluFor.Script:AwardTeamScore('CollateralDamage')

					local message = 'Collateral damage by player ' .. player.GetName(KillerController)
					self.PlayerTeams.BluFor.Script:DisplayMessageToAllPlayers(message, 'Engine', 5.0, 'Always')

					if self.Objectives.AvoidFatality:GetFatalityCount() >= self.CollateralDamageThreshold then
						self.Objectives.NoSoftFail:Fail()
						self.PlayerTeams.BluFor.Script:DisplayMessageToAlivePlayers('SoftFail', 'Upper', 10.0, 'Always')
					end
				elseif killerTeam == self.PlayerTeams.BluFor.TeamId then
					self.PlayerTeams.BluFor.Script:AwardPlayerScore(KillerController, 'KillStandard')
				end
			else
				print('BluFor eliminated')

				if CharacterController == KillerController then
					self.PlayerTeams.BluFor.Script:AwardPlayerScore(CharacterController, 'Accident')
				elseif killerTeam == killedTeam then
					self.PlayerTeams.BluFor.Script:AwardPlayerScore(KillerController, 'TeamKill')
				end

				self.PlayerTeams.BluFor.Script:PlayerDied(CharacterController, Character)

				local ps = player.GetPlayerState ( CharacterController )
				if player.GetName(ps) == self.VipPlayerId then
					self.Objectives.ProtectVIP:ReportFatality()
				end

				if self.PlayerTeams.BluFor.Script:IsWipedOut() then
					self:CheckBluForCountTimer()
				else
					timer.Set(
							self.Timers.CheckBluForCount.Name,
							self,
							self.CheckBluForCountTimer,
							self.Timers.CheckBluForCount.TimeStep,
							false
					)
				end
			end
		end
	end
end

--#endregion

--#region Player Status

function Mode:PlayerInsertionPointChanged(PlayerState, ip)
	--print('PlayerInsertionPointChanged')
	if ip == nil then
		-- Player unchecked insertion point.
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
	else
		-- Player checked insertion point.
		timer.Set(
			self.Timers.CheckReadyUp.Name,
			self,
			self.CheckReadyUpTimer,
			self.Timers.CheckReadyUp.TimeStep,
			false
		)

		if self:IsVipInsertionPoint(ip) then
			self.VipPlayerId = player.GetName(PlayerState)
			log:Info('VIP Player:', self.VipPlayerId)
		end
	end
end

function Mode:IsVipInsertionPoint(ip)
	return actor.HasTag(ip, 'VIP-Escort') or actor.HasTag(ip, 'VIP-Exfil')
end

function Mode:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	--print('PlayerReadyStatusChanged ' .. ReadyStatus)
	if ReadyStatus ~= 'DeclaredReady' then
		-- Player declared ready.
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
	elseif
		gamemode.GetRoundStage() == 'PreRoundWait' and
		gamemode.PrepLatecomer(PlayerState)
	then
		-- Player did not declare ready, but the timer run out.
		gamemode.EnterPlayArea(PlayerState)
	end
end

function Mode:CheckReadyUpTimer()
	if
		gamemode.GetRoundStage() == 'WaitingForReady' or
		gamemode.GetRoundStage() == 'ReadyCountdown'
	then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BluForReady = ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId]
		if BluForReady >= gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage('PreRoundWait')
		elseif BluForReady > 0 then
			gamemode.SetRoundStage('ReadyCountdown')
		end
	end
end

function Mode:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == 'ReadyCountdown' then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage('WaitingForReady')
		end
	end
end

function Mode:ShouldCheckForTeamKills()
	return (gamemode.GetRoundStage() == 'InProgress')
end

function Mode:PlayerCanEnterPlayArea(PlayerState)
	if
		gamemode.GetRoundStage() == 'InProgress' or
		player.GetInsertionPoint(PlayerState) ~= nil
	then
		return true
	end
	return false
end

function Mode:LogOut(Exiting)
	--print('Player left the game ')
	--print(Exiting)
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		timer.Set(
			self.Timers.CheckBluForCount.Name,
			self,
			self.CheckBluForCountTimer,
			self.Timers.CheckBluForCount.TimeStep,
			false
		)
	end
end

--#endregion

--#region Spawns

function Mode:SetUpOpForStandardSpawns()
	--print('Setting up AI spawns by groups')
	local maxAiCount = math.min(
			self.AiTeams.OpFor.Spawns:GetTotalSpawnPointsCount(),
			ai.GetMaxCount()
	)
	self.AiTeams.OpFor.CalculatedAiCount = SpawnsCommon.GetAiCountWithDeviationPercent(
			5,
			maxAiCount,
			gamemode.GetPlayerCount(true),
			5,
			self.Settings.OpForPreset.Value,
			5,
			0.1
	)
	local missingAiCount = self.AiTeams.OpFor.CalculatedAiCount
	--print('Adding random group spawns')
	while missingAiCount > 0 do
		if self.AiTeams.OpFor.Spawns:GetRemainingGroupsCount() <= 0 then
			break
		end
		local aiCountPerGroup = SpawnsCommon.GetAiCountWithDeviationNumber(
				2,
				10,
				gamemode.GetPlayerCount(true),
				0.5,
				self.Settings.OpForPreset.Value,
				1,
				1
		)
		if aiCountPerGroup > missingAiCount	then
			--print('Remaining AI count is not enough to fill group')
			break
		end
		self.AiTeams.OpFor.Spawns:AddSpawnsFromRandomGroup(aiCountPerGroup)
		missingAiCount = self.AiTeams.OpFor.CalculatedAiCount -
				self.AiTeams.OpFor.Spawns:GetSelectedSpawnPointsCount()
	end
	--print('Adding random spawns from reserve')
	self.AiTeams.OpFor.Spawns:AddRandomSpawnsFromReserve()
end

function Mode:SpawnOpFor()
	timer.Set(
		self.Timers.SpawnOpFor.Name,
		self,
		self.SpawnStandardOpForTimer,
		self.Timers.SpawnOpFor.TimeStep,
		false
	)
end

function Mode:SpawnStandardOpForTimer()
	self.AiTeams.OpFor.Spawns:Spawn(3.5, self.AiTeams.OpFor.CalculatedAiCount, self.AiTeams.OpFor.Tag)
end

--#endregion

--#region Objective: Extraction

function Mode:OnGameTriggerBeginOverlap(GameTrigger, Player)
	--print('OnGameTriggerBeginOverlap')
	if self.Objectives.Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		self.Objectives.Exfiltrate:PlayerEnteredExfiltration(true)
	end
end

function Mode:OnGameTriggerEndOverlap(GameTrigger, Player)
	--print('OnGameTriggerEndOverlap')
	if self.Objectives.Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		self.Objectives.Exfiltrate:PlayerLeftExfiltration()
	end
end

function Mode:OnExfiltrated()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	-- Award surviving players
	local alivePlayers = self.PlayerTeams.BluFor.Script:GetAlivePlayers()
	for _, alivePlayer in ipairs(alivePlayers) do
		self.PlayerTeams.BluFor.Script:AwardPlayerScore(alivePlayer, 'Survived')
	end
	-- Prepare summary
	self:UpdateCompletedObjectives()
	gamemode.AddGameStat('Result=Team1')
	gamemode.AddGameStat('Summary=VIPSurvived')
	gamemode.SetRoundStage('PostRoundWait')
end

--#endregion

--#region Fail Condition

function Mode:CheckBluForCountTimer()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end

	if not self.Objectives.ProtectVIP:IsOK() then
		self:UpdateCompletedObjectives()
		gamemode.AddGameStat('Result=None')
		gamemode.AddGameStat('Summary=VipEliminated')
		gamemode.SetRoundStage('PostRoundWait')
	elseif self.PlayerTeams.BluFor.Script:IsWipedOut() then
		self:UpdateCompletedObjectives()
		gamemode.AddGameStat('Result=None')
		gamemode.AddGameStat('Summary=BluForEliminated')
		gamemode.SetRoundStage('PostRoundWait')
	end
end

--#endregion

--#region Helpers

function Mode:PreRoundCleanUp()
	ai.CleanUp(self.AiTeams.OpFor.Tag)

	gamemode.SetTeamAttitude(1, 10, 'Neutral')
	gamemode.SetTeamAttitude(10, 1, 'Neutral')
	gamemode.SetTeamAttitude(10, 100, 'Friendly')
	gamemode.SetTeamAttitude(100, 10, 'Friendly')

	for _, objective in pairs(self.Objectives) do
		objective:Reset()
	end
end

function Mode:OnMissionSettingChanged(Setting, NewValue)
	--print('Setting ' .. Setting)
	if Setting == 'Scenario' then
		if self.Settings.Scenario.LastValue ~= NewValue then
			self:RandomizeObjectives()
		end
		self.Settings.Scenario.LastValue = NewValue
	end
	if Setting == 'AvailableForces' then
		self:ActivateInsertionPoints()
	end
end

function Mode:GetPlayerTeamScript()
	return self.PlayerTeams.BluFor.Script
end

function Mode:RandomizeObjectives()
	log:Debug('RandomizeObjectives')

	local eligibleVipPoints
	if self.Settings.Scenario.Value == 0 then
		eligibleVipPoints = self.InsertionPoints.AnyVipScenario
	elseif self.Settings.Scenario.Value == 1 then
		eligibleVipPoints = self.InsertionPoints.VipEscortScenario
	elseif self.Settings.Scenario.Value == 2 then
		eligibleVipPoints = self.InsertionPoints.VipExfilScenario
	else
		local index = self.Settings.Scenario.Value - SCENARIO_OFFSET

		if self.Settings.Scenario.Value > #self.InsertionPoints.AnyVipScenario then
			index = SCENARIO_OFFSET + 1
		end

		local ip = self.InsertionPoints.AnyVipScenario[index]
		eligibleVipPoints = { ip }

		log:Debug('Selected insertion', ip)
	end

	-- Pick a random VIP InsertionPoint
	self.ActiveVipInsertionPoint = PickRandom(eligibleVipPoints)

	local tags = actor.GetTags(self.ActiveVipInsertionPoint)

	-- Find possible exfil points
	local exfilTags = ArrayItemsWithPrefix(tags, 'Exfil-')
	-- Select one
	local exfilTag = PickRandom(exfilTags)

	-- Activate exfil
	local eligibleExfils = self.ExfilTagToExfils[exfilTag]
	local exfilActorAndIndex = PickRandom(eligibleExfils)
	log:Debug('Selected exfil', exfilActorAndIndex)
	self.Objectives.Exfiltrate:SelectPoint(true, exfilActorAndIndex.Index)

	self:ActivateInsertionPoints()
end

function Mode:ActivateInsertionPoints()
	local qrfEnabled = true
	local psdEnabled = true

	if self.Settings.AvailableForces.Value == 1 then
		qrfEnabled = false
	elseif self.Settings.AvailableForces.Value == 2 then
		psdEnabled = false
	end

	log:Debug('PSD', psdEnabled)
	log:Debug('QRF', qrfEnabled)

	-- Disable all InsertionPoint
	for _, ip in ipairs(self.InsertionPoints.All) do
		actor.SetActive(ip, false)
	end
	actor.SetActive(self.ActiveVipInsertionPoint, true)

	local selectedVipInsertionTags = actor.GetTags(self.ActiveVipInsertionPoint)
	local ipTags = ArrayItemsWithPrefix(selectedVipInsertionTags, 'IP-')

	-- Enable all linked InsertionPoints
	for _, InsertionPoint in ipairs(self.InsertionPoints.NonVip) do
		local isLinkedIP = false

		-- PSD insertion points
		for _, tag in ipairs(ipTags) do
			if actor.HasTag(InsertionPoint, tag) then
				isLinkedIP = true
				actor.SetActive(InsertionPoint, psdEnabled)
			end
		end

		-- Enable QRF points
		if not isLinkedIP and qrfEnabled then
			if not actor.HasTag(InsertionPoint, 'Hidden') then
				actor.SetActive(InsertionPoint, true)
			end
		end
	end
end


function Mode:UpdateCompletedObjectives()
	local completedObjectives = {}

	for _, objective in pairs(self.Objectives) do
		for _, completed in ipairs(objective:GetCompletedObjectives()) do
			table.insert(completedObjectives, completed)
		end
	end

	if #completedObjectives > 0 then
		gamemode.AddGameStat(
				'CompleteObjectives=' .. table.concat(completedObjectives, ",")
		)
	end
end

--#endregion

return Mode
