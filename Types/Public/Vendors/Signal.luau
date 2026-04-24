--!strict
local LoomRoot = script.Parent.Parent.Parent.Parent
local Signal = require(LoomRoot.Vendors.Signal)

export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection

return nil
