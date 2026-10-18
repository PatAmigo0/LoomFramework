--!strict
--[[
	Drops packets with NaN or ±inf anywhere in them. QuickNet's float types decode whatever bits a client sends, so a
	`NumberF32` can arrive as NaN; NaN fails every comparison, which gets it past checks like `if damage > 100`, and it
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
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = (value :: CFrame):GetComponents()
		return finite(x)
			and finite(y)
			and finite(z)
			and finite(r00)
			and finite(r01)
			and finite(r02)
			and finite(r10)
			and finite(r11)
			and finite(r12)
			and finite(r20)
			and finite(r21)
			and finite(r22)
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
