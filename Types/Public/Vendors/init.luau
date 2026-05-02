--!strict

local Logger = require(script.Logger)
local Signal = require(script.Signal)
local Promise = require(script.Promise)

export type Logger = Logger.Logger
export type LogItem = Logger.LogItem

export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection

export type Promise = Promise.Promise
export type TypedPromise<T> = Promise.TypedPromise<T>

return nil
