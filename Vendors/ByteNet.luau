--!strict

local LoomRoot = script.Parent.Parent
local ByteNetLib = require(LoomRoot.Types.Public.Vendors.ByteNetLib)

local OriginalByteNet = require(LoomRoot.roblox_packages.bytenet) :: any

local CustomByteNet = table.clone(OriginalByteNet)

-- patching bytenet
CustomByteNet.struct = function(format)
	local lazyStruct = function()
		return OriginalByteNet.struct(format)
	end

	return (lazyStruct :: any) :: ByteNetLib.dataTypeInterface<any>
end

return table.freeze(CustomByteNet :: any) :: ByteNetLib.ByteNet
