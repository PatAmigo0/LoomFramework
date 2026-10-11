--!strict

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Util = require(LoomRoot.Core.Component.Util)

--- For touch-style handlers whose first argument is a part or a character model: runs the method only when it
--- belongs to a player (alive, if `aliveOnly`), and passes that player as the next argument:
--- `method(self, hit, player, ...)`.
return function(aliveOnly: boolean?): Types.AnyDecorator
	return function(self, callback, hit: BasePart | Model, ...)
		local player = if hit:IsA("Model") then Util.GetPlayerFromModel(hit) else Util.GetPlayerFromPart(hit)
		if not player or (aliveOnly and not Util.IsAlive(player)) then
			return
		end
		return callback(self, hit, player, ...)
	end
end
