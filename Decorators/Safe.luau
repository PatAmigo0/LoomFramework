--!strict

local Types = require(script.Parent.Parent.Types)

-- Fields Safe looks at to say which object failed.
type Describable = { Name: unknown?, Instance: Instance? }

local function describe(object: unknown): string
	if type(object) ~= "table" then
		return tostring(object)
	end
	local fields = object :: Describable
	if typeof(fields.Instance) == "Instance" then
		return `{object} on {(fields.Instance :: Instance):GetFullName()}`
	elseif type(fields.Name) == "string" then
		return fields.Name :: string
	end
	return tostring(object)
end

local function withTraceback(err: unknown): string
	return debug.traceback(tostring(err), 2)
end

--- Catches errors from the method and warns (with a traceback) instead of throwing, so one bad call can't kill
--- the thread that made it. The method returns nothing when it fails.
local Safe: Types.AnyDecorator = function<Self>(self: Self, callback: (Self, ...any) -> ...any, ...: any): ...any
	local results = table.pack(xpcall(callback, withTraceback, self, ...))
	if not results[1] then
		warn(`[Loom.Decorators.Safe] {describe(self)} errored: {results[2]}`)
		return
	end
	return table.unpack(results, 2, results.n)
end

return Safe
