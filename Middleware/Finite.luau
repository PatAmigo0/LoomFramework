--!strict
--[[
	Drops packets with NaN or ±inf anywhere in them. ByteNet's float types decode whatever bits a client sends, so a
	`float32` can arrive as NaN; NaN fails every comparison, which gets it past checks like `if damage > 100`, and it
	spreads through any arithmetic it touches.

	Walks numbers, Vector2, Vector3, CFrame and Color3, and tables (both keys and values) recursively.
]]

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function check(value: unknown): boolean
	local kind = typeof(value)
	if kind == "number" then
		return finite(value :: number)
	elseif kind == "Vector3" then
		local v = value :: Vector3
		return finite(v.X) and finite(v.Y) and finite(v.Z)
	elseif kind == "Vector2" then
		local v = value :: Vector2
		return finite(v.X) and finite(v.Y)
	elseif kind == "CFrame" then
		for _, component in { (value :: CFrame):GetComponents() } do
			if not finite(component) then
				return false
			end
		end
		return true
	elseif kind == "Color3" then
		local c = value :: Color3
		return finite(c.R) and finite(c.G) and finite(c.B)
	elseif kind == "table" then
		for key, item in value :: { [unknown]: unknown } do
			if not check(key) or not check(item) then
				return false
			end
		end
	end
	return true
end

return function(_player: Player, data: unknown): boolean
	return check(data)
end
