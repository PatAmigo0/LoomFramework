--!strict

local LoomRoot = script.Parent.Parent
local Promise = require(LoomRoot.roblox_packages["typed-promise"])

export type Status = Promise.Status
export type Promise = Promise.Promise
export type TypedPromise<T...> = Promise.TypedPromise<T...>

return table.freeze(Promise)
