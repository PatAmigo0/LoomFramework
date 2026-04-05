--!strict
local LoomRoot = script.Parent.Parent.Parent -- script.Service.Core.Loom

local LoomTypes = require(LoomRoot.Types)
local ManagerBuilder = require(LoomRoot.Core.Builders).ManagerBuilder

local ServiceManager = ManagerBuilder.new({
	Name = "Service",
	InitMethod = "LoomInit",
	StartMethod = "LoomStart",
}) :: LoomTypes.LoomManager<LoomTypes.Service>

return ServiceManager -- table is already frozen
