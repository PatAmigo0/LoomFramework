--!strict

local LoomRoot = script.Parent.Parent
local Signal = require(LoomRoot.roblox_packages.signal)

export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection

return Signal
