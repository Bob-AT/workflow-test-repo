--[[
Security Detail (Semi-Permissive)

See SecurityDetail.lua
]]--

package.loaded['AssetExtraction'] = nil -- clear cache

local Tables = require("Common.Tables")
local super = Tables.DeepCopy(require("AssetExtraction"))
super.Logger.name = 'AssetExtractionSP'
super.IsSemiPermissive = true
return super
