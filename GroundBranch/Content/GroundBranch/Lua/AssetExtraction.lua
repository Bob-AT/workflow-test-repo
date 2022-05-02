--[[
  Asset Extraction
  PvE Ground Branch game mode by Bob/AT

  Notes for Mission Editing:

    1. Start with a regular 'Kill Confirmed' mission
	...
]]--

local Teams = require('Players.Teams')
local SpawnsGroups = require('Spawns.Groups')
local ObjectiveExfiltrate = require('Objectives.Exfiltrate')
local Logger = require("Common.Logger")
local AvoidFatality = require("Objectives.AvoidFatality")
local NoSoftFail = require("Objectives.NoSoftFail")

local log = Logger.new('AExtr')
log:SetLogLevel('DEBUG')

-- clear cache for development
package.loaded['SecurityDetail'] = nil

local Tables = require("Common.Tables")

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("SecurityDetail"))

-- Rename the logger
super.Logger.name = 'AExtrBase'

-- Use separate settings
super.Settings = {
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
	},
	Location = {
		Min = 0,
		Max = 10, -- hard max
		Value = 0,
		AdvancedSetting = true
	}
}
-- Use separate MissionTypeDescription and StringTables
super.MissionTypeDescription = '[Solo/Co-Op] Extract the asset'
super.StringTables = {'AssetExtraction'}
super.IsSemiPermissive = true -- TODO

-- Our sub-class of the singleton
local Mode = setmetatable({}, { __index = super })

-- New properties
Mode.VipStarts = {}
Mode.VipStartForThisRound = nil

--#region Helpers
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
		if actor.HasTag(ip, 'Hidden') or actor.HasTag(ip, 'VIP-Exfil') or actor.HasTag(ip, 'VIP-Escort') then
			-- Hide 'SecurityDetail' spawns
			actor.SetActive(ip, false)
		else
			actor.SetActive(ip, true)
		end
	end

	self.VipStarts = gameplaystatics.GetAllActorsOfClassWithTag('GroundBranch.GBPlayerStart', 'Asset')

	if #self.VipStarts < 10 then
		self.Settings.Location.Max = #self.VipStarts
	end
end
--#endregion

--#region Common
function Mode:IsVipInsertionPoint(ip)
	return actor.HasTag(ip, 'DummyIP')
end

function Mode:GetSpawnInfo(PlayerState)
	log:Info('GetSpawnInfo', player.GetName(PlayerState))

	if player.GetName(PlayerState) == self.VipPlayerId then
		log:Info('Special pick for ', player.GetName(PlayerState))
		return self.VipStartForThisRound
	end
	return nil
end

function Mode:OnMissionSettingChanged(Setting, NewValue)
	print('Setting ' .. Setting)
	self:RandomizeObjectives()
end

function Mode:RandomizeObjectives()
	log:Debug('RandomizeObjectives')
	self.Objectives.Exfiltrate:SelectPoint(true)

	local index = self.Settings.Location.Value
	if index == 0 then
		index = math.random(#self.VipStarts)
	end
	self.VipStartForThisRound = self.VipStarts[index]
end
--#endregion

return Mode
