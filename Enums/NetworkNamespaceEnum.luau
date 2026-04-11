--!strict

local LoomRoot = script.Parent.Parent
local Enums = require(LoomRoot.Types.Public.Enums)

local NetworkNamespaceEnum: Enums.NetworkNamespaceEnum = {
	Client = "Client",
	Net = "Net",
}

return NetworkNamespaceEnum
