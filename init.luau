--!strict

-- ==========================================
-- DEPENDENCIES
-- ==========================================
local RunService = game:GetService("RunService")

local PrivateTypes = require(script.Types.Private)
--selene: allow(unused_variable)
local PublicTypes = require(script.Types.Public)
local Enums = require(script.Enums)
local Middleware = require(script.Middleware)
local Vendors = require(script.Vendors)
local Core = require(script.Core)

local Logger = Vendors.Logger
local Promise = Vendors.Promise
local ByteNet = Vendors.ByteNet
local Sift = Vendors.Sift
local Signal = Vendors.Signal
local Trove = Vendors.Trove

local ControllerManager = Core.ControllerManager
local ServiceManager = Core.ServiceManager
local Service = Core.Service
local Controller = Core.Controller
local ComponentCore = Core.Component
-- ==========================================
-- ENVIRONMENT & EXPORTS
-- ==========================================
local IS_STUDIO = RunService:IsStudio()
local IS_SERVER = RunService:IsServer()

local Loom = {}

Loom.Util = {
	ByteNet = ByteNet,
	Promise = Promise,
	Sift = Sift,
	Logger = Logger,
	Signal = Signal,
	Trove = Trove,
}

Loom.Enums = {
	Reliability = Enums.ReliabilityTypeEnum,
	Network = Enums.NetworkNamespaceEnum,
	LoomType = Enums.LoomTypeEnum,
}

Loom.Middleware = Middleware

Loom.IS_STUDIO = IS_STUDIO
Loom.IS_SERVER = IS_SERVER

-- ==========================================
-- INTERNAL UTILITIES
-- ==========================================
local function initializeByteNet(def: any, namespace: "Client" | "Net")
	if not def.Client then
		return
	end

	local clientMap = def.Client :: any
	local registeredPackets = ByteNet.defineNamespace(def.Name, function()
		return Sift.Dictionary.map(clientMap, function(packetDef)
			return ByteNet.definePacket({
				value = packetDef.Schema,
				reliabilityType = packetDef.ReliabilityType,
				callbackBehavior = packetDef.CallbackBehavior,
			} :: PrivateTypes.ByteNetPacket<any>)
		end) :: { [string]: PrivateTypes.Packet<any> }
	end)

	clientMap = Sift.Dictionary.map(registeredPackets, function(packet, methodName)
		local originalDef = clientMap[methodName] :: PrivateTypes.PacketDef<any>
		local normalizedPacket: PrivateTypes.Packet<any> = type(packet) == "function" and packet() or packet
		local customPacket = table.clone(normalizedPacket)

		if IS_SERVER and originalDef.Middleware then
			local originalListen = customPacket.listen
			customPacket.listen = function(callback)
				originalListen(function(data, player)
					for _, middlewareFilter in ipairs(originalDef.Middleware) do
						local sender = player :: Player
						if not middlewareFilter(sender, data) then
							return
						end
					end
					callback(data, player)
				end)
			end
		end

		return table.freeze(customPacket)
	end)

	def[namespace] = clientMap
	if namespace ~= Enums.NetworkNamespaceEnum.Client then
		Sift.Dictionary.removeKey(def, Enums.NetworkNamespaceEnum.Client)
	end
end

local function injectUtilities(item: any)
	local newLogger = Logger.new() :: any
	newLogger._name = item.Name
	item.Debugger = table.freeze(newLogger:AtDebug())
	item.Trove = Trove.new()
end

-- ==========================================
-- PUBLIC API: SCHEMAS & DEFINITIONS
-- ==========================================

--- Use with **!strict** enabled
--- Helps to make sure that your schema definition is correct
function Loom.Define<T>(def: T & PrivateTypes.LoomDef): T & PrivateTypes.LoomDef
	return def :: any
end

function Loom.Packet<T>(packetDef: PrivateTypes.PacketDef<T>): PrivateTypes.Packet<T>
	return packetDef :: any
end

-- ==========================================
-- PUBLIC API: LIFECYCLE & INJECTION
-- ==========================================

function Loom.Weave<T, P>(def: T & PrivateTypes.LoomDef, additionalParams: P?): any
	if IS_SERVER then
		initializeByteNet(def :: any, Enums.NetworkNamespaceEnum.Client)
		local newService = Service.new(def)
		injectUtilities(newService)

		return ServiceManager.Register(newService, additionalParams :: any)
	else
		initializeByteNet(def, Enums.NetworkNamespaceEnum.Net)
		local newController = Controller.new(def)
		injectUtilities(newController)

		return ControllerManager.Register(newController, additionalParams :: any)
	end
end

function Loom.Component<T>(def: T & PublicTypes.ComponentDef): PublicTypes.ComponentClass<T, Instance>
	return ComponentCore.Define(def :: any) :: any
end

function Loom.Resolve(name: string): any
	if IS_SERVER then
		return ServiceManager.Get(name)
	end
	return ControllerManager.Get(name)
end

--
function Loom.Spin()
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
