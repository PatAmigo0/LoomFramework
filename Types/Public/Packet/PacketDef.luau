--!strict

local LoomRoot = script.Parent.Parent.Parent.Parent
--selene: allow(unused_variable)
local Enums = require(LoomRoot.Enums)

local ByteNetLib = require(LoomRoot.Types.Private.Vendors.ByteNetLib)

export type ReliabilityEnumModule = typeof(Enums.ReliabilityTypeEnum)
export type ReliabilityType = "reliable" | "unreliable"

export type CallbackBehavior = {
	spawnThread: boolean?,
	allowMultiple: boolean?,
}

export type PacketDef<T> = {
	ReliabilityType: ReliabilityType,
	Schema: ByteNetLib.dataTypeInterface<T>,
	CallbackBehavior: CallbackBehavior?,
}

return nil
