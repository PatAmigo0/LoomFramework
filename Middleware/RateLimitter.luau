local storage: { [Player]: { count: number, startTime: number }? } = {}
local playerLimits = setmetatable(storage, { __mode = "k" })

local function RateLimit(maxRequests: number, window: number)
	return function(player: Player): boolean
		local now = os.clock()
		local data = playerLimits[player]

		if not data or (now - data.startTime) > window then
			playerLimits[player] = { count = 1, startTime = os.clock() }
			return true
		end

		if data.count < maxRequests then
			data.count += 1
			return true
		end

		return false
	end
end

return RateLimit
