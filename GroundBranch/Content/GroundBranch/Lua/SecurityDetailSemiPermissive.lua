--[[
Security Detail (Semi-Permissive)

See SecurityDetail.lua
]]--

package.loaded['SecurityDetail'] = nil -- clear cache

local Tables = require("Common.Tables")
local super = Tables.DeepCopy(require("SecurityDetail"))
super.Logger.name = 'SecDetSP'
super.IsSemiPermissive = true
return super
