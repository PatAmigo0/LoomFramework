--!strict

local LoomRoot = script.Parent.Parent.Parent
local Logger = require(LoomRoot.Types.Public.Vendors.Logger)
local Trove = require(LoomRoot.Vendors.Trove)
local ByteNetLibTypes = require(LoomRoot.Types.Public.Vendors.ByteNetLib)

export type LoomNet<Net> = {
	Middleware: { (player: Player, data: any) -> boolean }?,
	[string]: ByteNetLibTypes.Packet<any>?,
}

export type LoomSchema<T = {}, N = nil> = T & {
	Name: string,
	Priority: number?,
	Net: N?,
	LoomInit: ((self: LoomClass<T, N>) -> ())?,
	LoomStart: ((self: LoomClass<T, N>) -> ())?,
}

export type LoomClass<T = {}, N = nil> = T & {
	Name: string,
	Net: N,
	Debugger: Logger.LogItem,
	Trove: Trove.Trove,
}

return nil
