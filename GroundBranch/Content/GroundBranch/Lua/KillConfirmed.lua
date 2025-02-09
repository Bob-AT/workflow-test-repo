--[[
	Kill Confirmed
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes/wiki/game-mode-kill-confirmed
]]--

--[[
Copyright © 2021 Jakub Baranowski <https://github.com/JakBaranowski>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]--

local MTeams                = require('Players.Teams')
local MSpawnsGroups         = require('Spawns.Groups')
local MSpawnsCommon         = require('Spawns.Common')
local MObjectiveExfiltrate  = require('Objectives.Exfiltrate')
local MObjectiveConfirmKill = require('Objectives.ConfirmKill')

--#region Properties

local KillConfirmed = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {'KillConfirmed'},
	GameModeAuthor = "(c) eelSkillz <https://gbgmc.github.io/>\n[Solo/Co-Op] Locate, neutralize and confirm elimination of all HVTs in the AO.",
	GameModeType = "PVE",
	Settings = {
		HVTCount = {
			Min = 1,
			Max = 5,
			Value = 1,
			AdvancedSetting = false,
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
			Min = 5,
			Max = 60,
			Value = 60,
			AdvancedSetting = false,
		},
		RespawnCost = {
			Min = 0,
			Max = 10000,
			Value = 10000,
			AdvancedSetting = true,
		},
		DisplayScoreMessage = {
			Min = 0,
			Max = 1,
			Value = 0,
			AdvancedSetting = true,
		},
		DisplayScoreMilestones = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
		DisplayObjectiveMessages = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
		DisplayObjectivePrompts = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
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
			Loadout = 'NoTeam',
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
		ConfirmKill = nil,
		Exfiltrate = nil,
	},
	HVT = {
		Tag = 'HVT',
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
}

--#endregion

--#region Preparation

function KillConfirmed:PreInit()
	print('Pre initialization')
	print('Initializing Kill Confirmed')
	self.PlayerTeams.BluFor.Script = MTeams:Create(
		1,
		false,
		self.PlayerScoreTypes,
		self.TeamScoreTypes
	)
	-- Gathers all OpFor spawn points by groups
	self.AiTeams.OpFor.Spawns = MSpawnsGroups:Create()
	-- Gathers all HVT spawn points
	self.Objectives.ConfirmKill = MObjectiveConfirmKill:Create(
		self,
		self.OnAllKillsConfirmed,
		self.PlayerTeams.BluFor.Script,
		self.HVT.Tag,
		self.Settings.HVTCount.Value
	)
	-- Gathers all extraction points placed in the mission
	self.Objectives.Exfiltrate = MObjectiveExfiltrate:Create(
		self,
		self.OnExfiltrated,
		self.PlayerTeams.BluFor.Script,
		5.0,
		1.0
	)
	-- Set maximum HVT count and ensure that HVT value is within limit
	self.Settings.HVTCount.Max = math.min(
		ai.GetMaxCount(),
		self.Objectives.ConfirmKill:GetAllSpawnPointsCount()
	)
	self.Settings.HVTCount.Value = math.min(
		self.Settings.HVTCount.Value,
		self.Settings.HVTCount.Max
	)
end

function KillConfirmed:PostInit()
	print('Post initialization')
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'NeutralizeHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ConfirmEliminatedHVTs', 1)
    print('Added Kill Confirmation objectives')
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateBluFor', 1)
	print('Added exfiltration objective')
end

--#endregion

--#region Common

function KillConfirmed:OnRoundStageSet(RoundStage)
	print('Started round stage ' .. RoundStage)
	timer.ClearAll()
	if RoundStage == 'WaitingForReady' then
		self:PreRoundCleanUp()
		self.Objectives.Exfiltrate:SelectPoint(false)
		self.Objectives.ConfirmKill:SetHvtCount(self.Settings.HVTCount.Value)
		self.Objectives.ConfirmKill:ShuffleSpawns()
	elseif RoundStage == 'PreRoundWait' then
		gamemode.SetDefaultRoundStageTime('InProgress', self.Settings.RoundTime.Value)
		self:SetUpOpForStandardSpawns()
		self:SpawnOpFor()
	elseif RoundStage == 'InProgress' then
		self.PlayerTeams.BluFor.Script:RoundStart(
			self.Settings.RespawnCost.Value,
			self.Settings.DisplayScoreMessage.Value == 1,
			self.Settings.DisplayScoreMilestones.Value == 1,
			self.Settings.DisplayObjectiveMessages.Value == 1,
			self.Settings.DisplayObjectivePrompts.Value == 1
		)
	end
end

function KillConfirmed:OnCharacterDied(Character, CharacterController, KillerController)
	print('OnCharacterDied')
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
			if actor.HasTag(CharacterController, self.HVT.Tag) then
				self.Objectives.ConfirmKill:Neutralized(Character, KillerController)
			elseif actor.HasTag(CharacterController, self.AiTeams.OpFor.Tag) then
				print('OpFor standard eliminated')
				if killerTeam == self.PlayerTeams.BluFor.TeamId then
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

--#endregion

--#region Player Status

function KillConfirmed:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	print('PlayerInsertionPointChanged')
	if InsertionPoint == nil then
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
	end
end

function KillConfirmed:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	print('PlayerReadyStatusChanged ' .. ReadyStatus)
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

function KillConfirmed:CheckReadyUpTimer()
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

function KillConfirmed:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == 'ReadyCountdown' then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage('WaitingForReady')
		end
	end
end

function KillConfirmed:ShouldCheckForTeamKills()
	print('ShouldCheckForTeamKills')
	if gamemode.GetRoundStage() == 'InProgress' then
		return true
	end
	return false
end

function KillConfirmed:PlayerCanEnterPlayArea(PlayerState)
	print('PlayerCanEnterPlayArea')
	if
		gamemode.GetRoundStage() == 'InProgress' or
		player.GetInsertionPoint(PlayerState) ~= nil
	then
		return true
	end
	return false
end

function KillConfirmed:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	if gamemode.GetRoundStage() == 'InProgress' then
		self.PlayerTeams.BluFor.Script:RespawnCleanUp(PlayerState)
	end
end

function KillConfirmed:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')
	player.SetInsertionPoint(PlayerState, nil)
end

function KillConfirmed:LogOut(Exiting)
	print('Player left the game ')
	print(Exiting)
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

function KillConfirmed:SetUpOpForStandardSpawns()
	print('Setting up AI spawn points by groups')
	local maxAiCount = math.min(
		self.AiTeams.OpFor.Spawns.Total,
		ai.GetMaxCount() - self.Settings.HVTCount.Value
	)
	self.AiTeams.OpFor.CalculatedAiCount = MSpawnsCommon.GetAiCountWithDeviationPercent(
		5,
		maxAiCount,
		gamemode.GetPlayerCount(true),
		5,
		self.Settings.OpForPreset.Value,
		5,
		0.1
	)
	local missingAiCount = self.AiTeams.OpFor.CalculatedAiCount
	-- Select groups guarding the HVTs and add their spawn points to spawn list
	local maxAiCountPerHvtGroup = math.floor(
		missingAiCount / self.Settings.HVTCount.Value
	)
	local aiCountPerHvtGroup = MSpawnsCommon.GetAiCountWithDeviationNumber(
		3,
		maxAiCountPerHvtGroup,
		gamemode.GetPlayerCount(true),
		1,
		self.Settings.OpForPreset.Value,
		1,
		0
	)
	print('Adding group spawns closest to HVTs')
	for i = 1, self.Objectives.ConfirmKill:GetHvtCount() do
		local hvtLocation = actor.GetLocation(
			self.Objectives.ConfirmKill:GetShuffledSpawnPoint(i)
		)
		self.AiTeams.OpFor.Spawns:AddSpawnsFromClosestGroup(aiCountPerHvtGroup, hvtLocation)
	end
	missingAiCount = self.AiTeams.OpFor.CalculatedAiCount -
		self.AiTeams.OpFor.Spawns:GetSelectedSpawnPointsCount()
	-- Select random groups and add their spawn points to spawn list
	print('Adding random group spawns')
	while missingAiCount > 0 do
		if self.AiTeams.OpFor.Spawns:GetRemainingGroupsCount() <= 0 then
			break
		end
		local aiCountPerGroup = MSpawnsCommon.GetAiCountWithDeviationNumber(
			2,
			10,
			gamemode.GetPlayerCount(true),
			0.5,
			self.Settings.OpForPreset.Value,
			1,
			1
		)
		if aiCountPerGroup > missingAiCount	then
			print('Remaining AI count is not enough to fill group')
			break
		end
		self.AiTeams.OpFor.Spawns:AddSpawnsFromRandomGroup(aiCountPerGroup)
		missingAiCount = self.AiTeams.OpFor.CalculatedAiCount -
			self.AiTeams.OpFor.Spawns:GetSelectedSpawnPointsCount()
	end
	-- Select random spawns
	self.AiTeams.OpFor.Spawns:AddRandomSpawns()
	self.AiTeams.OpFor.Spawns:AddRandomSpawnsFromReserve()
end

function KillConfirmed:SpawnOpFor()
	self.Objectives.ConfirmKill:Spawn(0.4)
	timer.Set(
		self.Timers.SpawnOpFor.Name,
		self,
		self.SpawnStandardOpForTimer,
		self.Timers.SpawnOpFor.TimeStep,
		false
	)
end

function KillConfirmed:SpawnStandardOpForTimer()
	self.AiTeams.OpFor.Spawns:Spawn(3.5, self.AiTeams.OpFor.CalculatedAiCount, self.AiTeams.OpFor.Tag)
end

--#endregion

--#region Objective: Kill confirmed

function KillConfirmed:OnAllKillsConfirmed()
	self.Objectives.Exfiltrate:SelectedPointSetActive(true)
end

--#endregion

--#region Objective: Extraction

function KillConfirmed:OnGameTriggerBeginOverlap(GameTrigger, Player)
	print('OnGameTriggerBeginOverlap')
	if self.Objectives.Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		self.Objectives.Exfiltrate:PlayerEnteredExfiltration(
			self.Objectives.ConfirmKill:AreAllConfirmed()
		)
	end
end

function KillConfirmed:OnGameTriggerEndOverlap(GameTrigger, Player)
	print('OnGameTriggerEndOverlap')
	if self.Objectives.Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		self.Objectives.Exfiltrate:PlayerLeftExfiltration()
	end
end

function KillConfirmed:OnExfiltrated()
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
	gamemode.AddGameStat('Summary=HVTsConfirmed')
	gamemode.SetRoundStage('PostRoundWait')
end

--#endregion

--#region Fail Condition

function KillConfirmed:CheckBluForCountTimer()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	if self.PlayerTeams.BluFor.Script:IsWipedOut() then
		gamemode.AddGameStat('Result=None')
		self:UpdateCompletedObjectives()
		if self.Objectives.ConfirmKill:AreAllNeutralized() then
			gamemode.AddGameStat('Summary=BluForExfilFailed')
		elseif self.Objectives.ConfirmKill:AreAllConfirmed() then
			gamemode.AddGameStat('Summary=BluForExfilFailed')
		else
			gamemode.AddGameStat('Summary=BluForEliminated')
		end
		gamemode.SetRoundStage('PostRoundWait')
	end
end

--#endregion

--#region Helpers

function KillConfirmed:PreRoundCleanUp()
	ai.CleanUp(self.HVT.Tag)
	ai.CleanUp(self.AiTeams.OpFor.Tag)
	for name, objective in pairs(self.Objectives) do
		print('Resetting ' .. name)
		objective:Reset()
	end
end

function KillConfirmed:OnMissionSettingsChanged(ChangedSettingsTable)
	for k, v in pairs(ChangedSettingsTable) do
		if v ~= nil then
			self:OnMissionSettingChanged(k, v)
		end
	end
end

function KillConfirmed:OnMissionSettingChanged(Setting, NewValue)
	-- print("OnMissionSettingChanged " .. Setting .. " -> " .. NewValue)
	if Setting == 'HVTCount' then
		print('HVT count set to ' .. NewValue .. ', updating spawns & objective markers.')
		self.Objectives.ConfirmKill:SetHvtCount(self.Settings.HVTCount.Value)
		self.Objectives.ConfirmKill:ShuffleSpawns()
	end
end

function KillConfirmed:GetPlayerTeamScript()
	return self.PlayerTeams.BluFor.Script
end

function KillConfirmed:UpdateCompletedObjectives()
	local completedObjectives = {}

	for _, objective in pairs(self.Objectives) do
		for _, completed in ipairs(objective:GetCompletedObjectives()) do
			table.insert(completedObjectives, completed)
		end
	end

	if #completedObjectives > 0 then
		gamemode.AddGameStat(
				'CompleteObjectives=' .. table.concat(completedObjectives, ',')
		)
	end
end

--#endregion

return KillConfirmed
