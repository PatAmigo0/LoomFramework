--!strict

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Decorate = require(LoomRoot.Core.Decorate)

--- Bundles several decorators into one, applied in the given order (first = outermost). Handy for reusing a
--- combination, e.g. `local PlayerTouch = Compose(IsPlayer(true), Cooldown(0.5))`.
return function<Self>(...: Types.Decorator<Self>): Types.Decorator<Self>
	local decorators = { ... }
	Decorate.check(decorators, "Compose", 2)
	-- callback -> that callback wrapped in the whole chain.
	local chains = setmetatable({} :: { [unknown]: (...any) -> ...any }, { __mode = "k" })

	return function(self, callback, ...)
		local chain = chains[callback]
		if not chain then
			chain = Decorate.chain(callback, decorators)
			chains[callback] = chain
		end
		return chain(self, ...)
	end
end
