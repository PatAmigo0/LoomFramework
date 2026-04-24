--!strict

local LoomRoot = script.Parent.Parent

local PrivateTypes = require(LoomRoot.Types.Private)
local PublicTypes = require(LoomRoot.Types.Public)
local LoomEnums = require(LoomRoot.Enums)

local Service = {}
Service.__index = Service

function Service.new(def: PrivateTypes.LoomDef): PublicTypes.Service
	local self = setmetatable(def, Service) :: PublicTypes.Service
	self._loomType = LoomEnums.LoomTypeEnum.Service
	return self
end

return Service
