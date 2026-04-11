--!strict

local LoomTypeEnum = require(script.LoomTypeEnum)
local ReliabilityTypeEnum = require(script.ReliabilityTypeEnum)
local NetworkNamespaceEnum = require(script.NetworkNamespaceEnum)

local Enums = {
	ReliabilityTypeEnum = ReliabilityTypeEnum,
	NetworkNamespaceEnum = NetworkNamespaceEnum,
	LoomTypeEnum = LoomTypeEnum,
}

return table.freeze(Enums)
