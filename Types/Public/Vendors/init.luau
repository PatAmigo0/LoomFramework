--!strict

local Logger = require(script.Logger)
local Signal = require(script.Signal)
local Promise = require(script.Promise)
local ByteNet = require(script.ByteNetLib)

export type Logger = Logger.Logger
export type LogItem = Logger.LogItem

export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection

export type Promise = Promise.Promise
export type TypedPromise<T> = Promise.TypedPromise<T>

export type ByteNetInterface<T> = ByteNet.dataTypeInterface<T>
export type ByteNetSchema = ByteNet.Schema
export type ByteNetPacket<T> = ByteNet.PacketProps<T>
export type ByteNet = ByteNet.ByteNet
export type Packet<T> = ByteNet.Packet<T>

return nil
