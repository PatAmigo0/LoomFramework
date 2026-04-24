--!strict
local LoomRoot = script.Parent.Parent.Parent.Parent
local LoomMember = require(LoomRoot.Types.Private.LoomCoreTypes.LoomMember)
-- local PacketDef = require(LoomRoot.Types.Private.LoomCoreTypes.PacketDef)
-- local ByteNetLib = require(LoomRoot.Types.Private.Vendors.ByteNetLib)

export type AnyNet = any -- PacketDef.PacketDef<any> | ByteNetLib.Packet<any> | [string]: any]

export type LoomDef = LoomMember.LoomMember & {
	Client: AnyNet?,
}

return nil
