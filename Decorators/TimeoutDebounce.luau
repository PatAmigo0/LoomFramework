--!strict

return function(timeout: number)
	return function(self: { _lastTouched: number, [any]: any }, callback: (...any) -> ...any, ...: any)
		local now = os.clock()
		if now - self._lastTouched >= timeout then
			self._lastTouched = now
			callback(self, ...)
		end
	end
end
