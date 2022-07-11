--[[
	Asset Extraction
	PvE Ground Branch game mode by Bob/AT

	Notes for Mission Editing:

		1. Start with a regular 'SecurityDetail' mission
		2. Add an InsertionPoint with tag 'Asset'
		3. Add PlayerStarts to InsertionPoint via Editor button.
				Note that there must be EXACTLY one PlayerStart.
				Therefore, delete 7 of the 8 PlayerStarts.
		4. Add orphaned (Group=None) PlayerStarts with tag 'Asset'
]]--

--[[
Copyright © 2022 "Bob/AT" <https://github.com/Bob-AT>
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

local AvoidFatality = require('Objectives.AvoidFatality')
local Logger = require('Common.Logger')
local NoSoftFail = require('Objectives.NoSoftFail')
local ObjectiveExfiltrate = require('Objectives.Exfiltrate')
local SpawnsGroups = require('Spawns.Groups')
local Tables = require('Common.Tables')
local Teams = require('Players.Teams')

local log = Logger.new('AExtr')
log:SetLogLevel('DEBUG')

-- clear cache for development
package.loaded['SecurityDetail'] = nil

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require('SecurityDetail'))

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
}
-- Use separate MissionTypeDescription and StringTables
super.MissionTypeDescription = '[Solo/Co-Op] Extract the asset'
super.StringTables = {'AssetExtraction'}
super.IsSemiPermissive = false

-- Our sub-class of the singleton
local Mode = setmetatable({}, { __index = super })

local function DecorateUserData(userdata)
	local mt = getmetatable(userdata) or {}
	mt.__tostring = function(obj)
		return actor.GetName(obj)
	end
end

--#region Preparation
function Mode:PreInit()
	log:Debug('PreInit')

	self.Hello = 'Hello'
	self.VipStartForThisRound = {}
	self.VipStarts = {}
	local vipStarts = gameplaystatics.GetAllActorsOfClassWithTag('GroundBranch.GBPlayerStart', 'Asset')
	table.sort(vipStarts, function(a,b)
		return actor.GetName(a) < actor.GetName(b)
	end)

	for _, start in ipairs(vipStarts) do
		DecorateUserData(start)
		table.insert(self.VipStarts, start)
		log:Debug('VIP start', start)
	end
	self.NumberOfLocations = #self.VipStarts
	self.SelectedLocationNumber = 0

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

	self.NonAssetInsertionPoints = {}
	for _, ip in ipairs(gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')) do
		DecorateUserData(ip)
		if actor.HasTag(ip, 'Hidden') or actor.HasTag(ip, 'VIP-Exfil') or actor.HasTag(ip, 'VIP-Travel') then
			-- Hide 'SecurityDetail' spawns
			actor.SetActive(ip, false)
		elseif actor.HasTag(ip, 'Asset') then
			actor.SetActive(ip, true)
		else
			actor.SetActive(ip, true)
			table.insert(self.NonAssetInsertionPoints, ip)
		end
	end
	self.FallbackInsertionPoint = self.NonAssetInsertionPoints[1]
end
--#endregion

function Mode:Validate(ensure)
	local assetInsertionPoints = {}
	for _, ip in ipairs(gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')) do
		DecorateUserData(ip)
		if actor.HasTag(ip, 'Asset') then
			table.insert(assetInsertionPoints, ip)
		end
	end
	ensure('Has one Asset InsertionPoint', #assetInsertionPoints == 1, assetInsertionPoints)
	ensure('Has none-Asset InsertionPoints', #self.NonAssetInsertionPoints > 0, self.NonAssetInsertionPoints)
end

--#region Common
function Mode:IsVipInsertionPoint(ip)
	return actor.HasTag(ip, 'Asset')
end

function Mode:GetSpawnInfo(PlayerState)
	log:Info('GetSpawnInfo', player.GetName(PlayerState))

	if player.GetName(PlayerState) == self.VipPlayerName then
		log:Info('Special pick for ', player.GetName(PlayerState))
		return self.VipStartForThisRound
	end
	return nil
end

function Mode:OnMissionSettingChanged()
	self.config.AutoSelectVip = true
	self:RandomizeObjectives()
end

function Mode:EnsureVipPlayerPresent(isLate)
	if self.VipPlayerName then
		return
	end

	local vipPlayer = self:GetRandomVipPlayer()
	self.VipPlayerName = player.GetName(vipPlayer)

	local message = 'Picked random Asset.'
	if isLate then
		message = message .. '..'
	end
	gamemode.BroadcastGameMessage(message, 'Engine', 11.5)
end

function Mode:RandomizeObjectives()
	if self.SelectedLocationNumber == 0 then
		self.SelectedLocationNumber = Tables.RandomKey(self.VipStarts)
	end
	self.VipStartForThisRound = self.VipStarts[self.SelectedLocationNumber]
	log:Debug('RandomizeObjectives', self.VipStartForThisRound)
	self:RandomizeExfil()
end

function Mode:RandomizeExfil()
	self.Objectives.Exfiltrate:SelectPoint(true)
end

--#endregion

return Mode
