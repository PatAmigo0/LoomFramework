--!strict

local Players = game:GetService("Players")

local Util = {}

function Util.GetPlayerFromModel(model: Model): Player?
	return Players:GetPlayerFromCharacter(model)
end

function Util.GetPlayerFromPart(part: BasePart): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

function Util.IsAlive(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

return table.freeze(Util)
