--!strict

local LoomRoot = script.Parent.Parent.Parent.Parent -- Loom/Types/Public/Controller/<script>
local Logger = require(LoomRoot.Types.Public.Utils.Logger)

-- selene: allow(unused_variable)
local Enums = require(LoomRoot.Enums)
local LoomMemberModule = require(LoomRoot.Types.Private.LoomCoreTypes.LoomMember)
local ByteNetLib = require(LoomRoot.Types.Private.Vendors.ByteNetLib)

export type Controller<T = any> = LoomMemberModule.LoomMember<T> & {
	Net: { [string]: ByteNetLib.Packet<any> }?,
	_loom_type: typeof(Enums.LoomTypeEnum.Controller),
	Debugger: Logger.LogItem,
	[any]: any,
}

return nil
