--!strict

local debs = (setmetatable({}, { __mode = "k" }) :: any) :: { [{ [any]: any }]: boolean }

--- Wraps a method to prevent it from being called again while it is still executing.
---
--- @param self The component instance (must contain the Debounce field)
--- @param callback The original method we are wrapping
--- @param ... The arguments passed to the method
return function(self: { [any]: any }, callback: (...any) -> ...any, ...: any)
	if debs[self] == true then
		return
	end

	debs[self] = true
	callback(self, ...)
	debs[self] = false
end
