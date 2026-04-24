--!strict

local LoomRoot = script.Parent.Parent

local PrivateTypes = require(LoomRoot.Types.Private)
local PublicTypes = require(LoomRoot.Types.Public)
local LoomEnums = require(LoomRoot.Enums)

local Controller = {}
Controller.__index = Controller

function Controller.new(def: PrivateTypes.LoomDef): PublicTypes.Controller
	local self = setmetatable(def, Controller) :: PublicTypes.Controller
	self._loomType = LoomEnums.LoomTypeEnum.Controller
	return self
end

return Controller
