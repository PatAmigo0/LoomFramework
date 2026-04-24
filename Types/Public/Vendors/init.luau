--!strict
local Logger = require(script.Logger)
local Signal = require(script.Signal)

export type Logger = Logger.Logger
export type LogItem = Logger.LogItem

export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection

return nil
