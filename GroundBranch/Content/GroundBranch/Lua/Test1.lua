x =  loadfile("Common/SiteConfig.lua")()


local log = require('Common.Logger').new('STDIN')

log:Info('x', x)