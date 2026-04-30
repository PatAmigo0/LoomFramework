--!strict

return function(predicate: (...any) -> boolean)
	return function(self: any, callback: (...any) -> ...any, ...: any)
		if predicate == nil or predicate(self, ...) == false then
			return
		end
		callback(self, ...)
	end
end
