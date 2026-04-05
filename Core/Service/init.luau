--!strict

local LoomRoot = script.Parent.Parent

local LoomTypes = require(LoomRoot.Types)
local LoomEnums = require(LoomRoot.Enums)

local Service = {}
Service.__index = Service

function Service.new(def: LoomTypes.ServiceDef): LoomTypes.Service
	local self = setmetatable(def, Service) :: LoomTypes.Service
	self._loomType = LoomEnums.LoomTypeEnum.Service
	return self
end

return Service
