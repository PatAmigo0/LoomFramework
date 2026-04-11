--!strict

local LoomRoot = script.Parent.Parent.Parent.Parent

local ByteNetLib = require(LoomRoot.Types.Private.Vendors.ByteNetLib)

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
