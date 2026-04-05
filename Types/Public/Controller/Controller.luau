--!strict

local LoomRoot = script.Parent.Parent.Parent.Parent -- Loom/Types/Public/Controller/<script>

-- selene: allow(unused_variable)
local Enums = require(LoomRoot.Enums)
local LoomMemberModule = require(LoomRoot.Types.Private.LoomCoreTypes.LoomMember)
local PacketDefModule = require(LoomRoot.Types.Public.Packet.PacketDef)
local ByteNetLib = require(LoomRoot.Types.Private.Vendors.ByteNetLib)

export type ControllerDef = LoomMemberModule.LoomMember & {
	Client: { [string]: PacketDefModule.PacketDef<any> | ByteNetLib.Packet<any> }?,
}

export type Controller<T = any> = LoomMemberModule.LoomMember<T> & {
	_loom_type: typeof(Enums.LoomTypeEnum.Controller),
	[any]: any,
}

return nil
