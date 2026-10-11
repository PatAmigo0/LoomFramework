--!strict
--[[
	Built-in decorators. Use them in a component's `Decorators` table or with `Loom.Decorate`:

	    function MyService:Reward(player: Player) ... end
	    Loom.Decorate(MyService, "Reward", Decorators.Cooldown(1, function(player) return player end))

	A decorator is just `function(self, callback, ...) ... return callback(self, ...) end` (see Types.Decorator),
	so writing your own is easy.
]]

return table.freeze({
	CanCall = require(script.CanCall),
	Compose = require(script.Compose),
	Cooldown = require(script.Cooldown),
	Debounce = require(script.Debounce),
	IsBusy = require(script.IsBusy),
	IsPlayer = require(script.IsPlayer),
	Once = require(script.Once),
	Profile = require(script.Profile),
	Safe = require(script.Safe),
	Spawn = require(script.Spawn),
})
