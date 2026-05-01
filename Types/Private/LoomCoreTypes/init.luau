--!strict

local LoomManager = require(script.LoomManager)
local PacketDef = require(script.PacketDef)
local Table = require(script.Table)

export type LoomManager<T> = LoomManager.LoomManager<T>
export type PacketDef<T> = PacketDef.PacketDef<T>

export type AnyTable = Table.AnyTable
export type AnyGenericTable<T> = Table.AnyGenericTable<T>

return nil
