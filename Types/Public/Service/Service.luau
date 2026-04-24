--!strict
local LoomRoot = script.Parent.Parent.Parent.Parent -- Loom/Types/Public/Service/<script>
local Logger = require(LoomRoot.Types.Public.Vendors.Logger)

-- selene: allow(unused_variable)
local Enums = require(LoomRoot.Enums)
local LoomMember = require(LoomRoot.Types.Private.LoomCoreTypes.LoomMember)

export type Service<T = any> = LoomMember.LoomMember<T> & {
	Debugger: Logger.LogItem,
	_loom_type: typeof(Enums.LoomTypeEnum.Service),
	[any]: any,
}

return nil
