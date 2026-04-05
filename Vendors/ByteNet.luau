--!strict

local LoomRoot = script.Parent.Parent
local ByteNetLib = require(LoomRoot.Types.Private.Vendors.ByteNetLib)

local ByteNet = require(LoomRoot.roblox_packages.bytenet) :: any

return ByteNet :: ByteNetLib.ByteNet -- bytenet is already frozen via table.freeze
