--[[
Kill Confirmed (Semi-Permissive)
PvE Ground Branch game mode by Bob/AT

https://github.com/JakBaranowski/ground-branch-game-modes/issues/26

Notes for Mission Editing:

  1. Start with a regular 'Kill Confirmed' mission
  2. Add non-combatants
  - use team id = 10
  - one of the unarmed 'Civ*' kits)
]]--

local Tables = require("Common.Tables")
local AvoidFatality = require("Objectives.AvoidFatality")
local NoSoftFail = require("Objectives.NoSoftFail")

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("KillConfirmed"))

-- Use a separate loadout
super.PlayerTeams.BluFor.Loadout='KillConfirmedSemiPermissive'
super.Settings.RespawnCost.Value = 100000

-- Add new score types
super.PlayerScoreTypes.CollateralDamage = {
	Score = -250,
	OneOff = false,
	Description = 'Killed a non-combatant'
}
super.TeamScoreTypes.CollateralDamage = {
	Score = -250,
	OneOff = false,
	Description = 'Killed a non-combatant'
}
-- Add additional objectives
super.Objectives.AvoidFatality = AvoidFatality.new('NoCollateralDamage')
super.Objectives.NoSoftFail = NoSoftFail.new()

-- The max. amount of collateral damage before failing the mission
super.CollateralDamageThreshold = 3

-- Our sub-class of the singleton
local KillConfirmedSP = setmetatable({}, { __index = super })

function KillConfirmedSP:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'NeutralizeHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ConfirmEliminatedHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'NoCollateralDamage', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateBluFor', 1)
end

function KillConfirmedSP:OnRoundStageSet(RoundStage)
	if RoundStage == 'PostRoundWait' or RoundStage == 'TimeLimitReached' then
		-- Make sure the 'SOFT FAIL' message is cleared
		gamemode.BroadcastGameMessage('Blank', 'Center', -1)
	end
	super.OnRoundStageSet(self, RoundStage)
end

function KillConfirmedSP:PreRoundCleanUp()
	super.PreRoundCleanUp(self)
	gamemode.SetTeamAttitude(1, 10, 'Neutral')
	gamemode.SetTeamAttitude(10, 1, 'Neutral')
	gamemode.SetTeamAttitude(10, 100, 'Friendly')
	gamemode.SetTeamAttitude(100, 10, 'Friendly')
end

function KillConfirmedSP:OnCharacterDied(Character, CharacterController, KillerController)
	local goodKill = true

	if gamemode.GetRoundStage() == 'PreRoundWait' or gamemode.GetRoundStage() == 'InProgress'
	then
		if CharacterController ~= nil then
			local killedTeam = actor.GetTeamId(CharacterController)
			local killerTeam = nil
			if KillerController ~= nil then
				killerTeam = actor.GetTeamId(KillerController)
			end
			if killedTeam == 10 and killerTeam == self.PlayerTeams.BluFor.TeamId then
				goodKill = false
				self.Objectives.AvoidFatality:ReportFatality()
				self.PlayerTeams.BluFor.Script:AwardPlayerScore(KillerController, 'CollateralDamage')
				self.PlayerTeams.BluFor.Script:AwardTeamScore('CollateralDamage')

				local message = 'Collateral damage by ' .. player.GetName(KillerController)
				self.PlayerTeams.BluFor.Script:DisplayMessageToAllPlayers(message, 'Engine', 5.0, 'ScoreMilestone')

				if self.Objectives.AvoidFatality:GetFatalityCount() >= self.CollateralDamageThreshold then
					self.Objectives.NoSoftFail:Fail()
					self.PlayerTeams.BluFor.Script:DisplayMessageToAlivePlayers('SoftFail', 'Upper', 10.0, 'Always')
				end
			end
		end
	end

	if goodKill then
		super.OnCharacterDied(self, Character, CharacterController, KillerController)
	end
end

function KillConfirmedSP:OnExfiltrated()
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
	if self.Objectives.NoSoftFail:IsOK() then
		gamemode.AddGameStat('Summary=HVTsConfirmed')
		gamemode.AddGameStat('Result=Team1')
	else
		gamemode.AddGameStat('Summary=SoftFail')
		gamemode.AddGameStat('Result=None')
	end
	gamemode.SetRoundStage('PostRoundWait')
end

return KillConfirmedSP
