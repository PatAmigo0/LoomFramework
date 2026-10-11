--!strict

local Types = require(script.Parent.Parent.Types)

--- Runs the method only when `predicate(self, ...)` returns true.
return function<Self>(predicate: (self: Self, ...any) -> boolean): Types.Decorator<Self>
	return function(self, callback, ...)
		if predicate(self, ...) then
			return callback(self, ...)
		end
		return
	end
end
