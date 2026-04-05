--!strict

local LoomTypeEnum = require(script.LoomTypeEnum)
local ReliabilityTypeEnum = require(script.ReliabilityTypeEnum)

local Enums = {
	ReliabilityTypeEnum = ReliabilityTypeEnum,
	LoomTypeEnum = LoomTypeEnum,
}

return table.freeze(Enums)
