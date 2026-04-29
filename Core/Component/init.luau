--!strict

local LoomRoot = script.Parent.Parent
local PublicTypes = require(LoomRoot.Types.Public)
local Component = require(LoomRoot.Vendors.Component)
local Trove = require(LoomRoot.Vendors.Trove)
local Logger = require(LoomRoot.Vendors.Logger)
local Sift = require(LoomRoot.Vendors.Sift)

local LoomComponent = {}

local IGNORED_KEYS = {
	"LoomInit",
	"LoomStart",
	"LoomDestroy",
	"Tag",
	"Ancestors",
	"Extensions",
	"ShouldConstruct",
	"ShouldExtend",
}

local Utils = require(script.Util)

local function wrap(inner, dec)
	return function(self: any, ...)
		return dec(self, inner, ...)
	end
end

function LoomComponent.Define<T>(def: T & PublicTypes.ComponentDef): PublicTypes.ComponentClass<T, Instance>
	local Comp = Component.new({
		Tag = def.Tag,
		Ancestors = def.Ancestors,
		Extensions = def.Extensions,
	})

	Comp.Util = Utils

	local decorators = def.Decorators
	local globalDecorators = nil
	if decorators then
		globalDecorators = decorators["*"]
	end

	function Comp:Construct()
		self.Trove = Trove.new()

		local newLogger = Logger.new() :: any
		newLogger._name = `{def.Tag} [{self.Instance.Name}]`
		self.Debugger = table.freeze(newLogger:AtDebug())

		if type(def.LoomInit) == "function" then
			def.LoomInit(self)
		end
	end

	function Comp:Start()
		if type(def.LoomStart) == "function" then
			def.LoomStart(self)
		end
	end

	function Comp:Stop()
		if type(def.LoomDestroy) == "function" then
			def.LoomDestroy(self)
		end

		self.Trove:Clean()
	end

	for key, value in pairs(def) do
		if not Sift.Array.has(IGNORED_KEYS, key) then
			if type(value) == "function" and decorators then
				local wrappedMethod = value
				local keyDecorators = decorators[key]

				if keyDecorators then
					for i = #keyDecorators, 1, -1 do
						wrappedMethod = wrap(wrappedMethod, keyDecorators[i])
					end
				end

				if globalDecorators then
					for i = #globalDecorators, 1, -1 do
						wrappedMethod = wrap(wrappedMethod, globalDecorators[i])
					end
				end

				value = wrappedMethod
			end
			Comp[key] = value
		end
	end

	return (Comp :: any) :: PublicTypes.ComponentClass<T, Instance>
end

return LoomComponent
