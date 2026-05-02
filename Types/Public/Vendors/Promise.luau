--!strict

local LoomRoot = script.Parent.Parent.Parent.Parent
local Promise = require(LoomRoot.Vendors.Promise)

export type Promise = Promise.Promise
export type TypedPromise<T> = Promise.TypedPromise<T>

return nil
