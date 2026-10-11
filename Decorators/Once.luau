--!strict

local Types = require(script.Parent.Parent.Types)

type ObjectSet = { [unknown]: true }

-- method -> objects that already ran it. Weak, so it never keeps a method or an object alive.
local ran = setmetatable({} :: { [unknown]: ObjectSet }, { __mode = "k" })

--- Runs the method only the first time it's called on each object; later calls are ignored.
local Once: Types.AnyDecorator = function(self, callback, ...)
	local objects = ran[callback]
	if not objects then
		objects = setmetatable({} :: ObjectSet, { __mode = "k" })
		ran[callback] = objects
	end
	if objects[self] then
		return
	end

	objects[self] = true
	return callback(self, ...)
end

return Once
