--!strict
local LoomRoot = script.Parent.Parent.Parent.Parent -- Loom/Types/Public/Service/<script>

-- selene: allow(unused_variable)
local Enums = require(LoomRoot.Enums)
local LoomMemberModule = require(LoomRoot.Types.Private.LoomCoreTypes.LoomMember)
local PacketDefModule = require(LoomRoot.Types.Public.Packet.PacketDef)
local ByteNetLib = require(LoomRoot.Types.Private.Vendors.ByteNetLib)

export type ServiceDef = LoomMemberModule.LoomMember & {
	Client: { [string]: PacketDefModule.PacketDef<any> | ByteNetLib.Packet<any> }?,
}

export type Service<T = any> = LoomMemberModule.LoomMember<T> & {
	Client: { [string]: ByteNetLib.Packet<any> }?,
	_loom_type: typeof(Enums.LoomTypeEnum.Service),
	[any]: any,
}

return nil
