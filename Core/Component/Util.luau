--!strict

local utils = {}

function utils.GetPlayerFromPart(part: BasePart): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return utils.GetPlayerFromModel(model)
end

function utils.GetPlayerFromModel(model: Model): Player?
	return game:GetService("Players"):GetPlayerFromCharacter(model)
end

function utils.IsAlive(player: Player): boolean
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

return table.freeze(utils)
