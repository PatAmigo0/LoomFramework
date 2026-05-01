--!strict
local LoomRoot = script.Parent.Parent.Parent -- script.Controller.Core.Loom

local PublicTypes = require(LoomRoot.Types.Public)
local PrivateTypes = require(LoomRoot.Types.Private)
local ManagerBuilder = require(LoomRoot.Core.Builders).ManagerBuilder

local ControllerManager = ManagerBuilder.new({
	Name = "Controller",
	InitMethod = "LoomInit",
	StartMethod = "LoomStart",
}) :: PrivateTypes.LoomManager<PublicTypes.LoomClass<any, any>>

return ControllerManager -- table is already frozen
