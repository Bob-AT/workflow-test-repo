--[[
Internal Configuration provider.

For site-specific customization use `SiteConfig.lua`
]]--

local Configuration = {
    Defaults = {
        Foo = false
    }
}

function Configuration.Get()
    local result = {}

    for k,v in pairs(Configuration.Defaults) do
        result[k] = v
    end

    package.loaded['Common.SiteConfig'] = nil
    local siteConfig = require('Common.SiteConfig')

    for k,v in pairs(siteConfig) do
        print('> ' .. k)
        result[k] = v
    end



    return result
end

return Configuration
