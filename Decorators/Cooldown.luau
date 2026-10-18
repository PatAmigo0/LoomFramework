--!strict

local Types = require(script.Parent.Parent.Types)

-- One object's cooldowns: key -> time of its last allowed call, and how many keys were added since the last sweep.
type Calls = { times: { [unknown]: number }, added: number }

-- The key used when there's no `keyOf`: one cooldown for the whole object.
local WHOLE_OBJECT = table.freeze({})
-- Stands in for a nil key, which a table can't hold.
local NIL_KEY = table.freeze({})
-- New keys between sweeps of expired ones.
local SWEEP_EVERY = 64

--- Runs the method at most once every `seconds` per object; calls in between are ignored.
--- Pass `keyOf` to keep a separate cooldown per key instead, e.g. per player:
--- `Cooldown(1, function(player) return player end)` (it receives the method's arguments, without `self`).
return function(seconds: number, keyOf: ((...any) -> unknown)?): Types.AnyDecorator
	if type(seconds) ~= "number" or seconds < 0 then
		error("Cooldown expects a number of seconds, 0 or more", 2)
	elseif keyOf ~= nil and type(keyOf) ~= "function" then
		error("Cooldown's keyOf must be a function", 2)
	end
	-- object -> its cooldowns.
	local cooldowns = setmetatable({} :: { [unknown]: Calls }, { __mode = "k" })

	return function<Self>(self: Self, callback: (Self, ...any) -> ...any, ...: any): ...any
		local calls = cooldowns[self]
		if not calls then
			calls = { times = setmetatable({} :: { [unknown]: number }, { __mode = "k" }), added = 0 }
			cooldowns[self] = calls
		end

		local key = if keyOf then keyOf(...) else WHOLE_OBJECT
		if key == nil then
			key = NIL_KEY
		end
		local now = os.clock()
		local times = calls.times
		local last = times[key]
		if last and now - last < seconds then
			return
		end

		if not last then
			calls.added += 1
			-- Weak keys only let Instances and tables go. Keys such as a UserId stay forever unless swept.
			if calls.added >= SWEEP_EVERY then
				calls.added = 0
				for other, time in times do
					if now - time >= seconds then
						times[other] = nil
					end
				end
			end
		end
		times[key] = now
		return callback(self, ...)
	end
end
