--!strict

local LoomRoot = script.Parent.Parent.Parent -- Loom/Types/Public/Service.luau
local Logger = require(LoomRoot.Types.Public.Vendors.Logger)
local Trove = require(LoomRoot.Vendors.Trove)

-- selene: allow(unused_variable)
local Enums = require(LoomRoot.Enums)
local LoomMember = require(LoomRoot.Types.Private.LoomCoreTypes.LoomMember)

export type Service<T = any> = LoomMember.LoomMember<T> & {
	Debugger: Logger.LogItem,
	Trove: Trove.Trove,
	_loom_type: typeof(Enums.LoomTypeEnum.Service),
	[any]: any,
}

return nil
