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
local Decorators = require(script.Decorators)
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

Loom.Decorators = Decorators
Loom.Middleware = Middleware

Loom.IS_STUDIO = IS_STUDIO
Loom.IS_SERVER = IS_SERVER

-- ==========================================
-- INTERNAL UTILITIES
-- ==========================================
local function initializeByteNet(def: any)
	if not def.Net then
		return
	end

	local clientMap = def.Net :: any
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

	def.Net = clientMap
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

function Loom.Define<T, N>(def: PublicTypes.LoomSchema<T, N>, net: N?): PublicTypes.LoomSchema<T, N>
	if net then
		def.Net = net
	end

	return def
end

function Loom.Packet<T>(packetDef: PrivateTypes.PacketDef<T>): PrivateTypes.Packet<T>
	return packetDef :: any
end

function Loom.Unseal<T>(schema: any): T
	return schema :: any
end

function Loom.VerifyNetSchema<N>(net: N): N
	for key, packet in pairs(net :: any) do
		local typedPacket = packet :: PrivateTypes.PacketDef<any>
		if key ~= "Middleware" and (type(typedPacket) ~= "table" or not typedPacket.Schema) then
			error(`Key '{key}' is not a ByteNet Packet, verify failed`)
		end
	end

	return net
end
-- ==========================================
-- PUBLIC API: LIFECYCLE & INJECTION
-- ==========================================

function Loom.Weave<T, N>(schema: PublicTypes.LoomSchema<T, N>): PublicTypes.LoomClass<T, N>
	initializeByteNet(schema)
	injectUtilities(schema)
	if IS_SERVER then
		return ServiceManager.Register(schema) :: any
	else
		return ControllerManager.Register(schema) :: any
	end
end

function Loom.Component<T, I>(def: PublicTypes.ComponentDef<T, I>): PublicTypes.ComponentClass<T, I>
	return ComponentCore.Define(def :: any) :: any
end

function Loom.Resolve(name: string): any
	if IS_SERVER then
		return ServiceManager.Get(name)
	else
		return ControllerManager.Get(name)
	end
end

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
