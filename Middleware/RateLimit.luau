--!strict

--- Allows each player at most `maxRequests` packets per `window` seconds; extra packets are dropped.
--- Every `RateLimit(...)` call has its own counters, so limits on different packets don't add up.
return function(maxRequests: number, window: number): (player: Player, data: unknown) -> boolean
	local usage = setmetatable({} :: { [Player]: { count: number, windowStart: number } }, { __mode = "k" })

	return function(player, _data)
		local now = os.clock()
		local record = usage[player]

		if not record or now - record.windowStart > window then
			usage[player] = { count = 1, windowStart = now }
			return true
		elseif record.count < maxRequests then
			record.count += 1
			return true
		end
		return false
	end
end
