--!strict

local Types = require(script.Parent.Parent.Types)

type LastCalls = { [unknown]: number }

-- The key used when there's no `keyOf`: one cooldown for the whole object.
local WHOLE_OBJECT = table.freeze({})
-- Stands in for a nil key, which a table can't hold.
local NIL_KEY = table.freeze({})

--- Runs the method at most once every `seconds` per object; calls in between are ignored.
--- Pass `keyOf` to keep a separate cooldown per key instead, e.g. per player:
--- `Cooldown(1, function(player) return player end)` (it receives the method's arguments, without `self`).
return function(seconds: number, keyOf: ((...any) -> unknown)?): Types.AnyDecorator
	if type(seconds) ~= "number" or seconds < 0 then
		error("Cooldown expects a number of seconds, 0 or more", 2)
	elseif keyOf ~= nil and type(keyOf) ~= "function" then
		error("Cooldown's keyOf must be a function", 2)
	end
	-- object -> key -> time of its last allowed call.
	local lastCalls = setmetatable({} :: { [unknown]: LastCalls }, { __mode = "k" })

	return function(self, callback, ...)
		local calls = lastCalls[self]
		if not calls then
			calls = setmetatable({} :: LastCalls, { __mode = "k" })
			lastCalls[self] = calls
		end

		local key = if keyOf then keyOf(...) else WHOLE_OBJECT
		if key == nil then
			key = NIL_KEY
		end
		local now = os.clock()
		local last = calls[key]
		if last and now - last < seconds then
			return
		end

		calls[key] = now
		return callback(self, ...)
	end
end
