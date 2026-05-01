--!strict

local LoomCoreTypes = require(script.LoomCoreTypes)
local BuilderTypes = require(script.Builder)
local VendorTypes = require(script.Vendors)

-- Core
export type LoomManager<T> = LoomCoreTypes.LoomManager<T>
export type PacketDef<T> = LoomCoreTypes.PacketDef<T>

export type AnyTable = LoomCoreTypes.AnyTable
export type AnyGenericTable<T> = LoomCoreTypes.AnyGenericTable<T>

-- Builders
export type BuilderOptions = BuilderTypes.BuilderOptions

-- Vendors
export type ByteNetSchema = VendorTypes.ByteNetSchema
export type ByteNetPacket<T> = VendorTypes.ByteNetPacket<T>
export type ByteNet = VendorTypes.ByteNet
export type Packet<T> = VendorTypes.Packet<T>

return nil
