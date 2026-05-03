--!strict

local LoomCoreTypes = require(script.LoomCoreTypes)
local BuilderTypes = require(script.Builder)

-- Core
export type LoomManager<T> = LoomCoreTypes.LoomManager<T>
export type PacketDef<T> = LoomCoreTypes.PacketDef<T>

export type AnyTable = LoomCoreTypes.AnyTable
export type AnyGenericTable<T> = LoomCoreTypes.AnyGenericTable<T>

-- Builders
export type BuilderOptions = BuilderTypes.BuilderOptions

return nil
