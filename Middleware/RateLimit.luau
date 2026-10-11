--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type Usage = { count: number, windowStart: number }

--- Allows each player at most `maxRequests` packets per `window` seconds; extra packets are dropped.
--- Every `RateLimit(...)` call has its own counters, so limits on different packets don't add up.
return function(maxRequests: number, window: number): (player: Player, data: unknown) -> boolean
	if type(maxRequests) ~= "number" or maxRequests < 1 then
		error("RateLimit expects at least 1 request per window", 2)
	elseif type(window) ~= "number" or window <= 0 then
		error("RateLimit expects a window above 0 seconds", 2)
	end

	-- player -> their count in the current window. Cleared when they leave.
	local usage: { [Player]: Usage } = {}
	if RunService:IsServer() then
		Players.PlayerRemoving:Connect(function(player)
			usage[player] = nil
		end)
	end

	return function(player, _data)
		local now = os.clock()
		local record = usage[player]

		if not record then
			usage[player] = { count = 1, windowStart = now }
			return true
		elseif now - record.windowStart >= window then
			record.count = 1
			record.windowStart = now
			return true
		elseif record.count < maxRequests then
			record.count += 1
			return true
		end
		return false
	end
end
