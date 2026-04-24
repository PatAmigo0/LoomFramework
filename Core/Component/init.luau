--!strict

local LoomRoot = script.Parent.Parent
local Component = require(LoomRoot.Vendors.Component)
local Trove = require(LoomRoot.Vendors.Trove)
local Logger = require(LoomRoot.Vendors.Logger)
local Sift = require(LoomRoot.Vendors.Sift)

local LoomComponent = {}

function LoomComponent.Define(def: any)
	local Comp = Component.new({
		Tag = def.Tag,
		Ancestors = def.Ancestors,
		Extensions = def.Extensions,
	})

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
		if type(value) == "function" and not Sift.Array.has({ "LoomInit", "LoomStart", "LoomDestroy" }, key) then
			Comp[key] = value
		end
	end

	return Comp
end

return LoomComponent
