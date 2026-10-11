--!strict
--[[
	Components: sleitnick's Component classes with Loom's lifecycle names, a Trove and a Debugger per instance,
	and method decorators.

	`Loom.Component(definition)` creates the class and returns it; define methods on what it returns:

	    local Lamp = Loom.Component({ Tag = "Lamp" } :: API.LampComponent)
	    function Lamp:LoomStart() ... end
	    return Lamp

	Definition fields other than Tag/Ancestors/Extensions become class members (defaults for every instance).
	`Decorators` are applied when the first instance is constructed (always after the module has finished
	defining its methods, since sleitnick's Component defers construction). Named entries wrap their method first,
	then `"*"` wraps the result.

	Every instance whose LoomInit ran gets LoomDestroy and a cleaned Trove exactly once: when it stops, or, if it
	was removed before it could start (the Component library never stops those), right after its start would have
	run. If LoomInit throws, the Trove is cleaned and the instance isn't created.
]]

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Component = require(LoomRoot.Vendors.Component)
local Trove = require(LoomRoot.Vendors.Trove)
local Debugger = require(script.Parent.Debugger)
local Decorate = require(script.Parent.Decorate)
local Util = require(script.Util)

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

local function set(keys: { string }): { [string]: true }
	local result: { [string]: true } = {}
	for _, key in keys do
		result[key] = true
	end
	return table.freeze(result)
end

-- Definition keys that configure the class instead of becoming members.
local CONFIG_KEYS = set({ "Tag", "Ancestors", "Extensions" })

-- Functions on the class that `"*"` decorators skip: lifecycle hooks, per-frame updates (a `"*"` Cooldown or
-- Once would throttle or stop them) and the Component library's plumbing. Decorate them by name if you mean to.
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

-- Runs a hook; returns its error with a traceback if it threw. (xpcall's own results are typed from the hook's
-- returns, and a hook returns nothing, so there would be no typed slot for the error.)
local function try(hook: Hook, self: Object): string?
	local failure: string? = nil
	xpcall(hook, function(err: unknown)
		failure = debug.traceback(tostring(err), 2)
	end, self)
	return failure
end

-- Works out every decorated method before replacing any, so a bad entry fails the same way for every instance
-- instead of leaving the class half decorated.
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

local LoomComponent = {}

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
	-- Weak, so instances that are gone don't stay in here.
	local started = setmetatable({} :: { [Object]: true }, { __mode = "k" })
	local finished = setmetatable({} :: { [Object]: true }, { __mode = "k" })

	-- LoomDestroy and the Trove clean-up, at most once per instance. The Trove is cleaned even if LoomDestroy throws.
	local function finish(self: Object)
		if finished[self] then
			return
		end
		finished[self] = true

		local loomDestroy = hooks.LoomDestroy
		local failure = if loomDestroy then try(loomDestroy, self) else nil
		self.Trove:Clean()
		if failure then
			error(failure, 0)
		end
	end

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

		-- The library schedules Start with task.defer once this returns. Deferring twice runs the check after
		-- that, when an instance that was removed in between is known never to start.
		task.defer(function()
			task.defer(finishIfNeverStarted, self)
		end)
	end

	local function start(self: Object)
		started[self] = true
		local loomStart = hooks.LoomStart
		if loomStart then
			loomStart(self)
		end
	end

	members.Construct = construct
	members.Start = start
	members.Stop = finish

	return (class :: unknown) :: S
end

return table.freeze(LoomComponent)
