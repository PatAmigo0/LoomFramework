--!strict

local PublicTypes = require(script.Public)
local PrivateTypes = require(script.Private)

-- Public
export type Service<T = any> = PublicTypes.Service<T>
export type Controller<T = any> = PublicTypes.Controller<T>

export type ServiceDef = PublicTypes.ServiceDef
export type ControllerDef = PublicTypes.ControllerDef
export type PacketDef<T> = PublicTypes.PacketDef<T>

export type Logger = PublicTypes.Logger

export type ReliabilityEnum = PublicTypes.ReliabilityEnum
export type NetworkNamespaceEnum = PublicTypes.NetworkNamespaceEnum

-- Private
export type LoomMember = PrivateTypes.LoomMember
export type LoomManager<T> = PrivateTypes.LoomManager<T>
export type BuilderOptions = PrivateTypes.BuilderOptions

-- Lib Types
export type ByteNetSchema = PrivateTypes.ByteNetSchema
export type ByteNetPacket<T> = PrivateTypes.ByteNetPacket<T>
export type ByteNet = PrivateTypes.ByteNet
export type Packet<T> = PrivateTypes.Packet<T>

return nil
