--!strict

local rateLimit = require(script.RateLimit)
local isAlive = require(script.IsAlive)

return table.freeze({
	RateLimit = rateLimit,
	IsAlive = isAlive,
})
