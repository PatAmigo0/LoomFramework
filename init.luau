--!strict

--[=[
	Basic
]=]
local Types = require(script.Types)
local Enums = require(script.Enums)
local Vendors = require(script.Vendors)

local Logger = Vendors.Logger

--[=[
	Core
]=]
local Core = require(script.Core)
local Promise = Vendors.Promise
local ByteNet = Vendors.ByteNet
local Sift = Vendors.Sift

local ControllerManager = Core.ControllerManager
local ServiceManager = Core.ServiceManager

local Service = Core.Service
local Controller = Core.Controller

local IS_STUDIO = game:GetService("RunService"):IsStudio()
local IS_SERVER = game:GetService("RunService"):IsServer()

--[=[
	Main
]=]
local Loom = {}

Loom.ByteNet = ByteNet
Loom.Promise = Promise
Loom.Sift = Sift
Loom.Logger = Logger

Loom.Enums = {
	Reliability = Enums.ReliabilityTypeEnum,
	Network = Enums.NetworkNamespaceEnum,
	LoomType = Enums.LoomTypeEnum,
}

Loom.IS_STUDIO = IS_STUDIO
Loom.IS_SERVER = IS_SERVER

local function initializeByteNet(def: any, namespace: "Client" | "Net")
	if def.Client then
		local clientMap = def.Client :: any

		local registeredPackets = ByteNet.defineNamespace(def.Name, function()
			local packets = {}
			for methodName, packetDef in pairs(clientMap) do
				local newPacket = ByteNet.definePacket({
					value = packetDef.Schema,
					reliabilityType = packetDef.ReliabilityType,
					callbackBehavior = packetDef.CallbackBehavior,
				})
				packets[methodName] = newPacket
			end

			return packets
		end)

		for methodName, packet in pairs(registeredPackets) do
			local normalizedPacket = type(packet) == "function" and packet() or packet
			clientMap[methodName] = table.freeze(normalizedPacket)
		end

		if namespace ~= Enums.NetworkNamespaceEnum.Client then
			def[Enums.NetworkNamespaceEnum.Net] = clientMap
			def[Enums.NetworkNamespaceEnum.Client] = nil
		end
	end
end

--- Use with **!strict** enabled.
--- Helps to make sure that your schema definition is correct
function Loom.Definition<T>(def: T & Types.ServiceDef): T & Types.ServiceDef
	return def
end

function Loom.RegisterPacket<T>(packetDef: Types.PacketDef<T>): Types.Packet<T>
	return packetDef :: any
end

function Loom.CreateService<T>(def: T & Types.ServiceDef): any
	initializeByteNet(def, Enums.NetworkNamespaceEnum.Client)
	local newService = Service.new(def)

	return ServiceManager.Register(newService) :: any
end

function Loom.CreateController<T>(def: T & Types.ControllerDef): any
	initializeByteNet(def, Enums.NetworkNamespaceEnum.Net)

	local newController = Controller.new(def)
	return ControllerManager.Register(newController) :: any
end

function Loom.GetService(name: string)
	return ControllerManager.Get(name)
end

function Loom.Start()
	return Promise.new(function(resolve)
		if IS_SERVER then
			ServiceManager.Start()
		else
			ControllerManager.Start()
		end

		resolve()
	end)
end

return table.freeze(Loom)
