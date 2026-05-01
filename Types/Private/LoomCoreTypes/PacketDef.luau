--!strict

local LoomRoot = script.Parent.Parent.Parent.Parent

local ByteNetLib = require(LoomRoot.Types.Private.Vendors.ByteNetLib)

export type ReliabilityType = "reliable" | "unreliable"

export type CallbackBehavior = {
	spawnThread: boolean?,
	allowMultiple: boolean?,
}

export type PacketDef<T> = {
	Schema: ByteNetLib.dataTypeInterface<T>,
	ReliabilityType: ReliabilityType?,
	CallbackBehavior: CallbackBehavior?,

	RateLimit: number?,
	Middleware: { (player: Player, data: T) -> boolean }?,
}

return nil
