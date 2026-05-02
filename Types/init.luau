--!strict

local PublicTypes = require(script.Public)
-- local PrivateTypes = require(script.Private)

-- Public
export type LoomSchema<T = {}, N = nil> = PublicTypes.LoomSchema<T, N>
export type LoomClass<T = {}, N = nil> = PublicTypes.LoomClass<T, N>
export type LoomNet<Net> = PublicTypes.LoomNet<Net>

export type ComponentInstance<T, I = Instance> = PublicTypes.ComponentInstance<T, I>
export type ComponentClass<T, I = Instance> = PublicTypes.ComponentClass<T, I>
export type ComponentDef<T = {}, I = Instance> = PublicTypes.ComponentDef<T, I>

export type ReliabilityEnum = PublicTypes.ReliabilityEnum
export type NetworkNamespaceEnum = PublicTypes.NetworkNamespaceEnum

export type Logger = PublicTypes.Logger
export type LogItem = PublicTypes.LogItem

export type Signal<T...> = PublicTypes.Signal<T...>
export type Connection = PublicTypes.Connection

export type Promise = PublicTypes.Promise
export type TypedPromise<T> = PublicTypes.TypedPromise<T>

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
