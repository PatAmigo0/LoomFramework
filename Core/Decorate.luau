--!strict
-- How decorators wrap methods. Used by `Loom.Decorate`, component `Decorators` and `Decorators.Compose`.

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)

type Method = (...any) -> ...any
type Decorator = Types.Decorator<any>

local Decorate = {}

--- Wraps `method` so that the first decorator in the list runs first (outermost).
function Decorate.chain(method: Method, decorators: { Decorator }): Method
	local wrapped = method
	for i = #decorators, 1, -1 do
		local decorator = decorators[i]
		local inner = wrapped
		wrapped = function(self, ...)
			return decorator(self, inner, ...)
		end
	end
	return wrapped
end

--- Decorates `target[name]` in place. `name` must already hold a function.
function Decorate.member(target: { [string]: unknown }, name: string, decorators: { Decorator }, level: number?)
	local method = target[name]
	if type(method) ~= "function" then
		error(`Can't decorate '{name}': it isn't a method (define it before decorating it)`, (level or 1) + 1)
	end
	target[name] = Decorate.chain(method :: Method, decorators)
end

return table.freeze(Decorate)
