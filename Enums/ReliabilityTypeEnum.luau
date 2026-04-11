--!strict

local LoomRoot = script.Parent.Parent
local Enums = require(LoomRoot.Types.Public.Enums)

local ReliabilityType: Enums.ReliabilityTypeEnum = {
	Reliable = "reliable",
	Unreliable = "unreliable",
}

return table.freeze(ReliabilityType)
