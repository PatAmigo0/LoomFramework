--!strict

local LoomRoot = script.Parent.Parent
local ReliabilityTypeModule = require(LoomRoot.Types.Public.Enums)

local ReliabilityType: ReliabilityTypeModule.ReliabilityTypeEnum = {
	Reliable = "reliable",
	Unreliable = "unreliable",
}

return table.freeze(ReliabilityType)
