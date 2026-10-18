--!strict

local Types = require(script.Parent.Parent.Types)

type ObjectSet = { [unknown]: true }

-- method -> objects currently running it.
local running = setmetatable({} :: { [unknown]: ObjectSet }, { __mode = "k" })

-- Keeps the traceback of where the method failed in the error it rethrows.
local function withTraceback(err: unknown): string
	return debug.traceback(tostring(err), 2)
end

--- Ignores calls while the same method is already running on the same object (e.g. it's yielding).
local Debounce: Types.AnyDecorator = function<Self>(self: Self, callback: (Self, ...any) -> ...any, ...: any): ...any
	local busy = running[callback]
	if not busy then
		busy = setmetatable({} :: ObjectSet, { __mode = "k" })
		running[callback] = busy
	end
	if busy[self] then
		return
	end

	busy[self] = true
	local results = table.pack(xpcall(callback, withTraceback, self, ...))
	busy[self] = nil

	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

return Debounce
