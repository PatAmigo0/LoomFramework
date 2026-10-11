--!strict

local Types = require(script.Parent.Parent.Types)

--- Blocks the method while `self[flag]` is true or unset; set the flag to false to allow calls.
return function(flag: string): Types.AnyDecorator
	return function(self, callback, ...)
		local value = (self :: { [string]: unknown })[flag]
		if value == nil or value == true then
			return
		end
		return callback(self, ...)
	end
end
