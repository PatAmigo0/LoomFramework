--!strict

return function(shouldBeAlive: boolean?)
	return function(self: any, callback: (...any) -> ...any, part: Model | BasePart, ...: any)
		local player = nil
		if typeof(part) == "Model" then
			player = self.Util.GetPlayerFromModel(part) :: Player
		else
			player = self.Util.GetPlayerFromPart(part) :: Player
		end

		if player then
			if shouldBeAlive then
				local character = player.Character :: Model
				local humanoid = character:FindFirstChildOfClass("Humanoid")

				if humanoid and humanoid.Health > 0 then
					callback(self, ...)
				end
			end
		end
	end
end
