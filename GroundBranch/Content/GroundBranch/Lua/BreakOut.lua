--[[
	Break Out
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes/wiki/game-mode-break-out
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


local MTeams               = require('Players.Teams')
local MSpawnsGroups        = require('Spawns.Groups')
local MSpawnsCommon        = require('Spawns.Common')
local MObjectiveExfiltrate = require('Objectives.Exfiltrate')

--#region Properties

local BreakOut = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = {'BreakOut'},
	GameModeAuthor = "(c) eelSkillz <https://gbgmc.github.io/>\n[Solo/Co-Op] Break out from captivity.",
	GameModeType = "PVE",
	Settings = {
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
		ExfiltrateSome = {
			Score = 250,
			OneOff = false,
			Description = 'Some team members exfiltrated'
		},
		ExfiltrateAll = {
			Score = 1000,
			OneOff = false,
			Description = 'All team members exfiltrated'
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
			Loadout = 'BreakOut',
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
		Exfiltrate = nil
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
		CheckSpawnedAi ={
			Name = 'CheckSpawnedAi',
			TimeStep = 4.1
		}
	}
}

--#endregion

--#region Preparation

function BreakOut:PreInit()
	print('Initializing Break Out')
	-- Initalize game message broker
	self.PlayerTeams.BluFor.Script = MTeams:Create(
		self.PlayerTeams.BluFor.TeamId,
		false,
		self.PlayerScoreTypes,
		self.TeamScoreTypes
	)
	-- Gathers all OpFor spawn points by groups
	self.AiTeams.OpFor.Spawns = MSpawnsGroups:Create()
	-- Initialize Exfiltration objective
	self.Objectives.Exfiltrate = MObjectiveExfiltrate:Create(
		self,
		self.OnExfiltrated,
		self.PlayerTeams.BluFor.Script,
		5.0,
		1.0
	)
end

function BreakOut:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateBluFor', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateAll', 2)
	print('Added game mode objectives')
end

--#endregion

--#region Common

function BreakOut:OnRoundStageSet(RoundStage)
	print('Started round stage ' .. RoundStage)
	timer.ClearAll()
	if RoundStage == 'WaitingForReady' then
		self:PreRoundCleanUp()
		self.Objectives.Exfiltrate:SelectPoint(true)
	elseif RoundStage == 'PreRoundWait' then
		gamemode.SetDefaultRoundStageTime('InProgress', self.Settings.RoundTime.Value)
		self:SetUpOpForSpawns()
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

function BreakOut:OnCharacterDied(Character, CharacterController, KillerController)
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
				print('OpFor eliminated')
				if killerTeam ~= killedTeam then
					self.PlayerTeams.BluFor.Script:AwardPlayerScore(KillerController, 'KillStandard')
				end
			else
				print('BluFor eliminated')
				if CharacterController == KillerController then
					self.PlayerTeams.BluFor.Script:AwardPlayerScore(CharacterController, 'Accident')
				elseif killerTeam == killedTeam then
					self.PlayerTeams.BluFor.Script:AwardPlayerScore(KillerController, 'TeamKill')
				end
				self.PlayerTeams.BluFor.Script:PlayerDied(CharacterController)
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

function BreakOut:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
	else
		timer.Set(
			self.Timers.CheckReadyUp.Name,
			self,
			self.CheckReadyUpTimer,
			self.Timers.CheckReadyUp.TimeStep,
			false
		)
	end
end

function BreakOut:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= 'DeclaredReady' then
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
		gamemode.EnterPlayArea(PlayerState)
	end
end

function BreakOut:CheckReadyUpTimer()
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

function BreakOut:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == 'ReadyCountdown' then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage('WaitingForReady')
		end
	end
end

function BreakOut:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == 'InProgress' then
		return true
	end
	return false
end

function BreakOut:PlayerCanEnterPlayArea(PlayerState)
	print('PlayerCanEnterPlayArea')
	if
		gamemode.GetRoundStage() == 'InProgress' or
		player.GetInsertionPoint(PlayerState) ~= nil
	then
		return true
	end
	return false
end

function BreakOut:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	if gamemode.GetRoundStage() == 'InProgress' then
		self.PlayerTeams.BluFor.Script:RespawnCleanUp(PlayerState)
	end
end

function BreakOut:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')
	player.SetInsertionPoint(PlayerState, nil)
end

function BreakOut:LogOut(Exiting)
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

function BreakOut:SetUpOpForSpawns()
	print('Setting up AI spawns by groups')
	local maxAiCount = math.min(
		self.AiTeams.OpFor.Spawns:GetTotalSpawnPointsCount(),
		ai.GetMaxCount()
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
	-- Select groups guarding extraction and add their spawn points to spawn list
	print('Adding group closest to exfil')
	local aiCountPerExfilGroup = MSpawnsCommon.GetAiCountWithDeviationNumber(
		3,
		10,
		gamemode.GetPlayerCount(true),
		1,
		self.Settings.OpForPreset.Value,
		1,
		0
	)
	local exfilLocation = actor.GetLocation(self.Objectives.Exfiltrate:GetSelectedPoint())
	self.AiTeams.OpFor.Spawns:AddSpawnsFromClosestGroup(aiCountPerExfilGroup, exfilLocation)
	print('Adding random spawns from remaining')
	self.AiTeams.OpFor.Spawns:AddRandomSpawns()
	print('Adding random spawns from reserve')
	self.AiTeams.OpFor.Spawns:AddRandomSpawnsFromReserve()
end

function BreakOut:SpawnOpFor()
	self.AiTeams.OpFor.Spawns:Spawn(4.0, self.AiTeams.OpFor.CalculatedAiCount, self.AiTeams.OpFor.Tag)
	timer.Set(
		self.Timers.CheckSpawnedAi.Name,
		self,
		self.CheckSpawnedAiTimer,
		self.Timers.CheckSpawnedAi.TimeStep,
		false
	)
end

function BreakOut:CheckSpawnedAiTimer()
	local aiControllers = ai.GetControllers(
		'GroundBranch.GBAIController',
		self.AiTeams.OpFor.Tag,
		255,
		255
	)
	print('Spawned ' .. #aiControllers .. ' AI')
end

--#endregion

--#region Objective: Extraction

function BreakOut:OnGameTriggerBeginOverlap(GameTrigger, Player)
	if self.Objectives.Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		self.Objectives.Exfiltrate:PlayerEnteredExfiltration(true)
	end
end

function BreakOut:OnGameTriggerEndOverlap(GameTrigger, Player)
	if self.Objectives.Exfiltrate:CheckTriggerAndPlayer(GameTrigger, Player) then
		self.Objectives.Exfiltrate:PlayerLeftExfiltration()
	end
end

function BreakOut:OnExfiltrated()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	gamemode.AddGameStat('Result=Team1')
	local alivePlayers = self.PlayerTeams.BluFor.Script:GetAlivePlayers()
	for _, alivePlayer in ipairs(alivePlayers) do
		self.PlayerTeams.BluFor.Script:AwardPlayerScore(alivePlayer, 'Survived')
	end
	if
		self.PlayerTeams.BluFor.Script:GetAlivePlayersCount() >=
		self.PlayerTeams.BluFor.Script:GetAllPlayersCount()
	then
		self.PlayerTeams.BluFor.Script:AwardTeamScore('ExfiltrateAll')
		gamemode.AddGameStat('CompleteObjectives=ExfiltrateBluFor,ExfiltrateAll')
		gamemode.AddGameStat('Summary=BluForExfilSuccess')
	else
		self.PlayerTeams.BluFor.Script:AwardTeamScore('ExfiltrateSome')
		gamemode.AddGameStat('CompleteObjectives=ExfiltrateBluFor')
		gamemode.AddGameStat('Summary=BluForExfilPartialSuccess')
	end
	gamemode.SetRoundStage('PostRoundWait')
end

--#endregion

--#region Fail condition

function BreakOut:CheckBluForCountTimer()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	if self.PlayerTeams.BluFor.Script:IsWipedOut() then
		timer.Clear(self, 'CheckBluForExfil')
		gamemode.AddGameStat('Result=None')
		gamemode.AddGameStat('Summary=BluForEliminated')
		gamemode.SetRoundStage('PostRoundWait')
	end
end

--#endregion

--region Helpers

function BreakOut:PreRoundCleanUp()
	ai.CleanUp(self.AiTeams.OpFor.Tag)
	self.Objectives.Exfiltrate:Reset()
end

function BreakOut:GetPlayerTeamScript()
	return self.PlayerTeams.BluFor.Script
end

--#endregion

return BreakOut
