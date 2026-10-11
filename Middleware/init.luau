--!strict
-- Built-in packet middleware (see Types.Middleware). Any `function(player, data): boolean` works too.

local Util = require(script.Parent.Core.Component.Util)

return table.freeze({
	--- Drops packets from players without a living character.
	IsAlive = Util.IsAlive,
	RateLimit = require(script.RateLimit),
})
