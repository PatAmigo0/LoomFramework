--!strict

local Types = require(script.Parent.Parent.Types)

-- Keeps the traceback of where the method failed in the error it rethrows.
local function withTraceback(err: unknown): string
	return debug.traceback(tostring(err), 2)
end

--- Shows each call as `label` in the MicroProfiler (Ctrl+F6). Only for methods that don't yield: a yield
--- inside a profiler label breaks the measurement.
return function(label: string): Types.AnyDecorator
	return function<Self>(self: Self, callback: (Self, ...any) -> ...any, ...: any): ...any
		debug.profilebegin(label)
		local results = table.pack(xpcall(callback, withTraceback, self, ...))
		debug.profileend()

		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
end
