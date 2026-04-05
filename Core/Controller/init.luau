--!strict

local LoomRoot = script.Parent.Parent

local LoomTypes = require(LoomRoot.Types)
local LoomEnums = require(LoomRoot.Enums)

local Controller = {}
Controller.__index = Controller

function Controller.new(def: LoomTypes.ControllerDef): LoomTypes.Controller
	local self = setmetatable(def, Controller) :: LoomTypes.Controller
	self._loomType = LoomEnums.LoomTypeEnum.Controller
	return self
end

return Controller
