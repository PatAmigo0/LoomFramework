--!strict
local LoomRoot = script.Parent.Parent.Parent -- script.Service.Core.Loom

local PublicTypes = require(LoomRoot.Types.Public)
local PrivateTypes = require(LoomRoot.Types.Private)
local ManagerBuilder = require(LoomRoot.Core.Builders).ManagerBuilder

local ServiceManager = ManagerBuilder.new({
	Name = "Service",
	InitMethod = "LoomInit",
	StartMethod = "LoomStart",
}) :: PrivateTypes.LoomManager<PublicTypes.LoomClass<any, any>>

return ServiceManager -- table is already frozen
