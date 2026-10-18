--!strict
--[[
	Components: sleitnick's Component classes with Loom's lifecycle names, a Trove and a Debugger per instance,
	and method decorators.

	`Loom.Component(definition)` creates the class and returns it; define methods on what it returns:

	    local Lamp = Loom.Component({ Tag = "Lamp" } :: API.LampComponent)
	    function Lamp:LoomStart() ... end
	    return Lamp

	Definition fields other than Tag/Ancestors/Extensions become class members (defaults for every instance).
	`Decorators` are applied when the first instance is constructed, after the module has defined its methods.
	Named entries wrap their method first, then `"*"` wraps the result.

	Every instance whose LoomInit ran gets LoomDestroy and a cleaned Trove exactly once, including instances
	removed before they started. If LoomInit throws, the Trove is cleaned and the instance isn't created. If
	LoomStart throws, the error is logged and the instance never counts as started: no per-frame updates, no
	`Started`. An error in LoomDestroy is logged too, after the Trove is cleaned.
]]

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Component = require(LoomRoot.Vendors.Component)
local Trove = require(LoomRoot.Vendors.Trove)
local Debugger = require(script.Parent.Debugger)
local Decorate = require(script.Parent.Decorate)
local Util = require(script.Util)

--#region TYPES
-- A component instance, as far as Loom is concerned.
type Object = {
	Instance: Instance,
	Trove: Types.Trove,
	Debugger: Types.Debugger,
}
type Hook = (self: Object) -> ()
type Method = (...any) -> ...any
type Decorators = { [string]: { Types.Decorator<any> } }

-- The parts of a definition that configure the class.
type Definition = {
	Tag: string,
	Ancestors: { Instance }?,
	Extensions: { Types.ComponentExtension<any> }?,
}

-- The class members Loom reads after the game has defined them.
type ClassHooks = {
	Decorators: Decorators?,
	LoomInit: Hook?,
	LoomStart: Hook?,
	LoomDestroy: Hook?,
}

-- The class API Loom calls.
type Class = {
	FromInstance: (self: Class, instance: Instance) -> unknown,
}
--#endregion

--#region STATE
local function set(keys: { string }): { [string]: true }
	local result: { [string]: true } = {}
	for _, key in keys do
		result[key] = true
	end
	return table.freeze(result)
end

-- Definition keys that configure the class instead of becoming members.
local CONFIG_KEYS = set({ "Tag", "Ancestors", "Extensions" })

-- Functions `"*"` decorators skip: lifecycle hooks, per-frame updates and the Component library's own. Name them
-- in `Decorators` to decorate them.
local NOT_METHODS = set({
	"LoomInit",
	"LoomStart",
	"LoomDestroy",
	"HeartbeatUpdate",
	"SteppedUpdate",
	"RenderSteppedUpdate",
	"Construct",
	"Start",
	"Stop",
	"__index",
	"__tostring",
})
--#endregion

--#region LOCAL
-- Runs a hook; returns its error, with a traceback, if it threw.
local function try(hook: Hook, self: Object): string?
	local failure: string? = nil
	xpcall(hook, function(err: unknown)
		failure = debug.traceback(tostring(err), 2)
	end, self)
	return failure
end

-- Applies a class's `Decorators`. Nothing is replaced unless every entry is valid.
local function applyDecorators(members: { [string]: unknown }, decorators: unknown)
	if type(decorators) ~= "table" then
		error("Decorators must be a table of method name = list of decorators", 0)
	end
	local lists = decorators :: Decorators

	local staged: { [string]: Method } = {}
	for name, list in lists do
		if name ~= "*" then
			staged[name] = Decorate.wrapped(members, name, list, 1)
		end
	end

	local everyMethod = lists["*"]
	if everyMethod then
		Decorate.check(everyMethod, `Decorators["*"]`, 1)
		for name, value in members do
			if type(name) == "string" and type(value) == "function" and not NOT_METHODS[name] then
				staged[name] = Decorate.chain(staged[name] or value :: Method, everyMethod)
			end
		end
	end

	for name, method in staged do
		members[name] = method
	end
end

--#endregion

--#region API
local LoomComponent = {}

--- Creates the component class for `definition` (see the header).
function LoomComponent.Define<S>(definition: S): S
	local config = definition :: Definition
	if type(config) ~= "table" or type(config.Tag) ~= "string" then
		error("Loom.Component expects a definition with a Tag", 3)
	end
	local tag = config.Tag

	local class = Component.new({
		Tag = tag,
		Ancestors = config.Ancestors,
		Extensions = config.Extensions,
	})
	local members = class :: { [string]: unknown }
	local hooks = class :: ClassHooks
	local api = class :: Class

	for key, value in definition :: { [string]: unknown } do
		if not CONFIG_KEYS[key] then
			members[key] = value
		end
	end
	members.Util = Util

	local decorated = false
	local started = setmetatable({} :: { [Object]: true }, { __mode = "k" })
	local finished = setmetatable({} :: { [Object]: true }, { __mode = "k" })

	-- Runs LoomDestroy and cleans the Trove, once per instance. The Trove is cleaned even if LoomDestroy throws.
	-- Errors are logged, not thrown, so the library still fires `Stopped`.
	local function finish(self: Object)
		if finished[self] then
			return
		end
		finished[self] = true

		local loomDestroy = hooks.LoomDestroy
		local failure = if loomDestroy then try(loomDestroy, self) else nil
		self.Trove:Clean()
		if failure then
			self.Debugger:Warn("LoomDestroy failed: %s", failure)
		end
	end

	-- Finishes an instance that was removed before it started; the Component library never stops those.
	local function finishIfNeverStarted(self: Object)
		if not started[self] and api:FromInstance(self.Instance) ~= self then
			finish(self)
		end
	end

	local function construct(self: Object)
		if not decorated then
			if hooks.Decorators ~= nil then
				local ok, err = pcall(applyDecorators, members, hooks.Decorators)
				if not ok then
					error(`Loom.Component {tag}: {err}`, 0)
				end
			end
			decorated = true
		end

		self.Trove = Trove.new()
		self.Debugger = Debugger.new(tag, self.Instance)

		local loomInit = hooks.LoomInit
		if loomInit then
			local failure = try(loomInit, self)
			if failure then
				self.Trove:Clean()
				error(failure, 0)
			end
		end

		-- The library defers Start until after this returns; deferring twice runs the check after that.
		task.defer(function()
			task.defer(finishIfNeverStarted, self)
		end)
	end

	local function start(self: Object)
		started[self] = true
		local loomStart = hooks.LoomStart
		if not loomStart then
			return
		end
		local failure = try(loomStart, self)
		if failure then
			self.Debugger:Warn("LoomStart failed: %s", failure)
			-- The library runs Start in a thread of its own and marks the instance started when Start returns.
			-- Leaving that thread suspended keeps it from doing so; stopping the instance cancels the thread.
			coroutine.yield()
		end
	end

	members.Construct = construct
	members.Start = start
	members.Stop = finish

	return (class :: unknown) :: S
end

--#endregion

return table.freeze(LoomComponent)
