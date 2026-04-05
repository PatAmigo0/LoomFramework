--!strict

local ByteNetLib = require(script.ByteNetLib)

export type ByteNetSchema = ByteNetLib.Schema
export type ByteNetPacket<T> = ByteNetLib.packetProps<T>
export type Packet<T> = ByteNetLib.Packet<T>
export type ByteNet = ByteNetLib.ByteNet

return nil
