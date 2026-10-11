--!strict
-- Built-in packet middleware (see Types.Middleware). Any `function(player, data): boolean` works too.
-- Write middleware with both parameters, even when `data` goes unused: a one-parameter function makes the
-- solver add an error type to the packet's payload type instead of failing loudly.

local Util = require(script.Parent.Core.Component.Util)

return table.freeze({
	--- Drops packets from players without a living character.
	IsAlive = function(player: Player, _data: unknown): boolean
		return Util.IsAlive(player)
	end,
	RateLimit = require(script.RateLimit),
})
