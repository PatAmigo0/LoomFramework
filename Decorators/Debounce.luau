--!strict

--- Wraps a method to prevent it from being called again while it is still executing.
--- **Note:** The component **must** have a `Debounce: boolean` field (defaulting to `false`).
---
--- @param self The component instance (must contain the Debounce field)
--- @param callback The original method we are wrapping
--- @param ... The arguments passed to the method
return function(self: { _debounce: boolean, [any]: any }, callback: (...any) -> ...any, ...: any)
	if self._debounce == nil or self._debounce == true then
		return
	end

	self._debounce = true
	callback(self, ...)
	self._debounce = false
end
