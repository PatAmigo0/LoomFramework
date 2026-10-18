--!strict

local Types = require(script.Parent.Parent.Types)

--- Runs the method only while `self[flag]` is false. True, unset or any other value blocks it, so set the flag to
--- false (in LoomInit, say) before the first call.
return function(flag: string): Types.AnyDecorator
	return function<Self>(self: Self, callback: (Self, ...any) -> ...any, ...: any): ...any
		if (self :: { [string]: unknown })[flag] ~= false then
			return
		end
		return callback(self, ...)
	end
end
