--!strict
local LoomRoot = script.Parent.Parent.Parent -- script.Controller.Core.Loom

local LoomTypes = require(LoomRoot.Types)
local ManagerBuilder = require(LoomRoot.Core.Builders).ManagerBuilder

local ControllerManager = ManagerBuilder.new({
	Name = "Controller",
	InitMethod = "LoomInit",
	StartMethod = "LoomStart",
}) :: LoomTypes.LoomManager<LoomTypes.Controller>

return ControllerManager -- table is already frozen
