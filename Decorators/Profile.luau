--!strict

local Types = require(script.Parent.Parent.Types)

--- Shows each call as `label` in the MicroProfiler (Ctrl+F6). Only for methods that don't yield: a yield
--- inside a profiler label breaks the measurement.
return function(label: string): Types.AnyDecorator
	return function(self, callback, ...)
		debug.profilebegin(label)
		local results = table.pack(pcall(callback, self, ...))
		debug.profileend()

		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
end
