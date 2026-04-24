local function IsAlive(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	return true
end

return IsAlive
