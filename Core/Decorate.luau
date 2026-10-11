--!strict
-- How decorators wrap methods. Used by `Loom.Decorate`, component `Decorators` and `Decorators.Compose`.

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)

--#region TYPES
type Method = (...any) -> ...any
type Decorator = Types.Decorator<any>
--#endregion

--#region API
local Decorate = {}

--- Errors unless `decorators` is a list of functions. `what` names the list in the message.
function Decorate.check(decorators: unknown, what: string, level: number)
	if type(decorators) ~= "table" then
		error(`{what} must be a list of decorators, got a {typeof(decorators)}`, level + 1)
	end
	for i, decorator in decorators :: { [unknown]: unknown } do
		if type(decorator) ~= "function" then
			error(`{what}[{i}] isn't a decorator (a function), it's a {typeof(decorator)}`, level + 1)
		end
	end
end

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

--- `target[name]` wrapped in `decorators`, without changing `target`. `name` must already hold a function.
function Decorate.wrapped(target: { [string]: unknown }, name: string, decorators: { Decorator }, level: number): Method
	local method = target[name]
	if type(method) ~= "function" then
		error(`Can't decorate '{name}': it isn't a method (define it before decorating it)`, level + 1)
	end
	Decorate.check(decorators, `Decorators for '{name}'`, level + 1)
	return Decorate.chain(method :: Method, decorators)
end

--- Decorates `target[name]` in place. `level` is the stack level errors point at, as in `error`.
function Decorate.member(target: { [string]: unknown }, name: string, decorators: { Decorator }, level: number)
	target[name] = Decorate.wrapped(target, name, decorators, level + 1)
end

--#endregion

return table.freeze(Decorate)
