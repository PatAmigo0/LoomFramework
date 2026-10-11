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
	defining its methods, since sleitnick's Component defers construction).
]]

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Component = require(LoomRoot.Vendors.Component)
local Trove = require(LoomRoot.Vendors.Trove)
local createDebugger = require(script.Parent.Debugger)
local Decorate = require(script.Parent.Decorate)
local Util = require(script.Util)

-- A component instance, as far as Loom is concerned.
type Object = {
	Instance: Instance,
	Trove: Types.Trove,
	Debugger: Types.LogItem,
}
type Hook = (self: Object) -> ()
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

local function set(keys: { string }): { [string]: true }
	local result: { [string]: true } = {}
	for _, key in keys do
		result[key] = true
	end
	return table.freeze(result)
end

-- Definition keys that configure the class instead of becoming members.
local CONFIG_KEYS = set({ "Tag", "Ancestors", "Extensions" })

-- Functions on the class that are plumbing, so `"*"` decorators skip them.
local NOT_METHODS =
	set({ "LoomInit", "LoomStart", "LoomDestroy", "Construct", "Start", "Stop", "__index", "__tostring" })

local function applyDecorators(members: { [string]: unknown }, decorators: Decorators)
	for name, list in decorators do
		if name ~= "*" then
			Decorate.member(members, name, list)
		end
	end

	local everyMethod = decorators["*"]
	if not everyMethod then
		return
	end
	for name, value in members do
		if type(value) == "function" and not NOT_METHODS[name] then
			members[name] = Decorate.chain(value :: (...any) -> ...any, everyMethod)
		end
	end
end

local LoomComponent = {}

function LoomComponent.Define<S>(definition: S): S
	local config = definition :: Definition
	if type(config) ~= "table" or type(config.Tag) ~= "string" then
		error("Loom.Component expects a definition with a Tag", 3)
	end

	local class = Component.new({
		Tag = config.Tag,
		Ancestors = config.Ancestors,
		Extensions = config.Extensions,
	})
	local members = class :: { [string]: unknown }
	local hooks = class :: ClassHooks

	for key, value in definition :: { [string]: unknown } do
		if not CONFIG_KEYS[key] then
			members[key] = value
		end
	end
	members.Util = Util

	local decorated = false

	local function construct(self: Object)
		if not decorated then
			decorated = true
			if hooks.Decorators then
				applyDecorators(members, hooks.Decorators)
			end
		end

		self.Trove = Trove.new()
		self.Debugger = createDebugger(`{config.Tag} [{self.Instance.Name}]`)

		if hooks.LoomInit then
			hooks.LoomInit(self)
		end
	end

	local function start(self: Object)
		if hooks.LoomStart then
			hooks.LoomStart(self)
		end
	end

	local function stop(self: Object)
		if hooks.LoomDestroy then
			hooks.LoomDestroy(self)
		end
		self.Trove:Clean()
	end

	members.Construct = construct
	members.Start = start
	members.Stop = stop

	return (class :: unknown) :: S
end

return table.freeze(LoomComponent)
