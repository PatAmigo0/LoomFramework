--!strict

local LoomRoot = script.Parent.Parent
local Sift = require(LoomRoot.roblox_packages.sift)

export type Array<T> = Sift.Array<T>
export type Set<T> = Sift.Set<T>
export type Dictionary<K, V> = Sift.Dictionary<K, V>

return table.freeze(Sift)
