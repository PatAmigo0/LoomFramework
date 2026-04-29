--!strict

return function(keyToCheck: string)
	return function(self: any, callback: (...any) -> ...any, ...: any)
		if keyToCheck == nil or self[keyToCheck] == nil or self[keyToCheck] == true then
			return
		end
		callback(self, ...)
	end
end
