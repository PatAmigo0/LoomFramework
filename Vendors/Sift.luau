--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoomRoot = script.Parent.Parent
local sift = require(ReplicatedStorage.RobloxPackages.sift)
local Sift = require(LoomRoot.roblox_packages.sift)

export type Array<T> = sift.Array<T>
export type Set<T> = sift.Set<T>
export type Dictionary<K, V> = sift.Dictionary<K, V>

return Sift
