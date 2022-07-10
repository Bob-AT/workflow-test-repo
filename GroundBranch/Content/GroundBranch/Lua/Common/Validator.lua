--[[
	Validator class for GameModeXyzValidate.lua scripts.
	If the game mode provides a `Validate` method, it will be called.
	The validator uses an `assert`-based testing strategy.
--]]

if false then
	-- Assert example
	-- assert(message, condition, optional_info)
	assert("X greater 10", x > 10, x)

	-- for x == 15 it will print "OK: X greater 10 (15)"

	--for x = 5 it will print "FAILED: X greater 10 (5)" and add this message to
	-- the listOfErrors

	-- Usage example: GameModeXyzValidate.lua
	local validator = require("Common.Validator").new('GameModeXyz')
	-- Optional: Add Assert-based API
	validator.Add(function(gameMode, assert)
		-- self is the game mode object
		local allSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
		assert("AI spawns present", #allSpawns > 0)

		local insertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
		assert("Insertion points present", #insertionPoints > 0, #insertionPoints)
	end)
	-- Optional: Add Classic GroundBranch API
	validator.Add({ ValidateLevel = function()
		local listOfErrors = {}
		-- ...
		return listOfErrors
	end })
	return validator
end

local Tables = require("Common.Tables")

local Validator = {
	separator = "--------------- ",
	typeTag = 'Common.Validator'
}

function Validator.new(modeName)
	local self = setmetatable({}, { __index = Validator })
	self.validationList = {}
	self.errorList = {}

	-- clear the cache
	package.loaded[modeName] = nil

	self.gameMode = Tables.DeepCopy(require(modeName))

	if self.gameMode['Validate'] then
		self.validationList[1] = function(mode, assert)
			self.gameMode.Validate(mode, assert)
		end
	end

	return self
end

function Validator:Add(validation)
	if type(validation) == 'table' then
		if self.typeTag == validation.typeTag then
			for _, elem in ipairs(validation.validationList) do
				table.insert(self.validationList, elem)
			end
		else
			table.insert(self.validationList, validation)
		end
	else
		table.insert(self.validationList, validation)
	end
end

function Validator:AssertFunction(msg, condition, info)
	local ok
	if type(condition) == 'function' then
		ok = condition()
	else
		ok = condition
	end

	local builder = {}
	if ok then
		table.insert(builder, "OK: ")
	else
		table.insert(builder, "FAILED: ")
	end
	table.insert(builder, msg)

	local info_builder = {}
	if type(info) == 'table' then
		for _, elem in ipairs(info) do
			table.insert(info_builder, tostring(elem))
		end
	elseif info ~= nil then
		info_builder[1] = tostring(info)
	end

	if #info_builder > 0 then
		table.insert(builder, " (")
		table.insert(builder, table.concat(info_builder, ", "))
		table.insert(builder, ")")
	end

	local line = table.concat(builder)
	print(line)
	if not ok then
		table.insert(self.errorList, line)
	end
end

function Validator:ValidateLevel()
	local sep = self.separator

	print(sep .. 'PreInit')
	if self.gameMode.PreInit then
		self.gameMode:PreInit()
	else
		print("(No PreInit method)")
	end

	print(sep .. 'PostInit')
	if self.gameMode.PostInit then
		self.gameMode:PostInit()
	else
		print("(No PostInit method)")
	end

	print(sep .. ' Running validation')
	for _, validation in ipairs(self.validationList) do
		if type(validation) == 'table' then
			local tempList = validation:ValidateLevel()
			for _, elem in ipairs(tempList) do
				table.insert(self.errorList, elem)
			end
		elseif type(validation) == 'function' then
			local gameModeCopy = Tables.DeepCopy(self.gameMode)
			validation(gameModeCopy, function(msg, condition, info)
				self:AssertFunction(msg, condition, info)
			end)
		end
	end

	print(sep .. ' Validation result')
	if #self.errorList == 0 then
		print("(No errors found)")
	else
		for idx, message in ipairs(self.errorList) do
			print('[' .. idx .. '] ' .. message)
		end
	end
	print(sep)

	return self.errorList
end

return Validator
