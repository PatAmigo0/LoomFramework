--!strict

local PublicTypes = require(script.Public)
-- local PrivateTypes = require(script.Private)

-- Public
export type Service<T = any> = PublicTypes.Service<T>
export type Controller<T = any> = PublicTypes.Controller<T>

export type ReliabilityEnum = PublicTypes.ReliabilityEnum
export type NetworkNamespaceEnum = PublicTypes.NetworkNamespaceEnum

export type Logger = PublicTypes.Logger
export type LogItem = PublicTypes.LogItem

export type Signal<T...> = PublicTypes.Signal<T...>
export type Connection = PublicTypes.Connection

-- Private
-- export type LoomMember = PrivateTypes.LoomMember
-- export type LoomManager<T> = PrivateTypes.LoomManager<T>
-- export type BuilderOptions = PrivateTypes.BuilderOptions

-- Lib Types
-- export type ByteNetSchema = PrivateTypes.ByteNetSchema
-- export type ByteNetPacket<T> = PrivateTypes.ByteNetPacket<T>
-- export type ByteNet = PrivateTypes.ByteNet
-- export type Packet<T> = PrivateTypes.Packet<T>

return nil
