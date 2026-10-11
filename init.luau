--!strict
--[[
	Loom: services, controllers and components with typed ByteNet networking.

	    -- Shared/Schemas/ShopService.luau: what both sides know (the name and the packets)
	    return Loom.Define({
	        Name = "ShopService",
	        Net = {
	            Bought = Loom.Packet({ Schema = ByteNet.struct({ item = ByteNet.string, price = ByteNet.uint16 }) }),
	        },
	    })

	    -- ServerAPI: the typed contract, one type per service
	    export type ShopService = Types.Service<{
	        Buy: (self: ShopService, player: Player, item: string) -> (),
	    }, typeof(ShopServiceDef.Net)>
	    ...
	    ShopService = ShopServiceDef :: ShopService,

	    -- Services/ShopService.luau: the implementation
	    local ShopService = Loom.Weave(API.ShopService)
	    function ShopService:Buy(player, item) ... end
	    return ShopService

	Every public type is defined in `Loom.Types` and re-exported here (`Loom.Service<...>`).
]]

local RunService = game:GetService("RunService")

local Types = require(script.Types)
local Vendors = require(script.Vendors)
local Enums = require(script.Enums)
local Decorators = require(script.Decorators)
local Middleware = require(script.Middleware)
local Component = require(script.Core.Component)
local Debugger = require(script.Core.Debugger)
local Decorate = require(script.Core.Decorate)
local Net = require(script.Core.Net)
local Registry = require(script.Core.Registry)
local Schema = require(script.Core.Schema)

--#region TYPES
-- Every public type from `Types`, so `require(Loom)` gives `Loom.Service<...>`. pesde's package link forwards only
-- the types this module exports.
export type Signal<T...> = Types.Signal<T...>
export type Connection = Types.Connection
export type Trove = Types.Trove
export type Promise = Types.Promise
export type TypedPromise<T...> = Types.TypedPromise<T...>
export type LogLevel = Types.LogLevel
export type Debugger = Types.Debugger
export type LoomConfig = Types.LoomConfig
export type Reliability = Types.Reliability
export type Middleware<T> = Types.Middleware<T>
export type RateLimitConfig = Types.RateLimitConfig
export type PacketDef<T> = Types.PacketDef<T>
export type Packet<T> = Types.Packet<T>
export type ByteNet = Types.ByteNet
export type ServerNet<N> = Types.ServerNet<N>
export type ClientNet<N> = Types.ClientNet<N>
export type Service<M, N = nil> = Types.Service<M, N>
export type Controller<M, N = nil> = Types.Controller<M, N>
export type Decorator<Self> = Types.Decorator<Self>
export type AnyDecorator = Types.AnyDecorator
export type ComponentUtil = Types.ComponentUtil
export type ComponentInstance<T, I = Instance> = Types.ComponentInstance<T, I>
export type ComponentExtension<Self> = Types.ComponentExtension<Self>
export type Component<T, I = Instance> = Types.Component<T, I>
--#endregion

local Loom = {
	IS_STUDIO = RunService:IsStudio(),
	IS_SERVER = RunService:IsServer(),

	Util = table.freeze({
		ByteNet = Schema.ByteNet,
		Promise = Vendors.Promise,
		Sift = Vendors.Sift,
		Debugger = Debugger,
		Signal = Vendors.Signal,
		Trove = Vendors.Trove,
	}),
	Enums = Enums,
	Decorators = Decorators,
	Middleware = Middleware,
}

--- Declares a service/controller: its `Name`, an optional `Priority` (higher starts first) and an optional `Net`
--- table of `Loom.Packet`s. Returns the table typed exactly as written, so `typeof(Def.Net)` is its Net type.
function Loom.Define<D>(definition: D & { read Name: string }): D
	local fields = definition :: { Name: unknown, Priority: unknown, Net: unknown }

	if type(fields.Name) ~= "string" then
		error("Loom.Define: Name must be a string", 2)
	elseif fields.Priority ~= nil and type(fields.Priority) ~= "number" then
		error(`Loom.Define: {fields.Name}.Priority must be a number`, 2)
	end

	local net = fields.Net
	if net ~= nil then
		if type(net) ~= "table" then
			error(`Loom.Define: {fields.Name}.Net must be a table of Loom.Packet`, 2)
		end
		for key, packet in net :: { [unknown]: unknown } do
			if type(key) ~= "string" then
				error(`Loom.Define: {fields.Name}.Net keys must be strings, got {typeof(key)} {key}`, 2)
			elseif not Net.IsPacket(packet) then
				error(`Loom.Define: {fields.Name}.Net.{key} isn't a Loom.Packet`, 2)
			end
		end
		table.freeze(net)
	end

	return definition
end

--- A packet for a `Net` table. Its payload type comes from `Schema`, e.g. `ByteNet.struct({ hp = ByteNet.uint8 })`.
function Loom.Packet<T>(definition: Types.PacketDef<T>): Types.Packet<T>
	return Net.CreatePacket(definition)
end

--- Registers a service (server) or controller (client) for `Loom.Spin` and gives it its `Debugger` and `Trove`.
--- Returns the same table: define its methods on it.
function Loom.Weave<S>(service: S): S
	return Registry.Weave(service)
end

--- Creates a component class. Returns the class: define its methods on it.
function Loom.Component<S>(definition: S): S
	return Component.Define(definition)
end

--- Decorates a method that's already defined on a service, controller or component class.
--- Decorators run in the order given (the first one is outermost).
function Loom.Decorate<S, Self>(target: S, method: keyof<S>, ...: Types.Decorator<Self>)
	Decorate.member(target :: { [string]: unknown }, method, { ... }, 2)
end

--- Connects every woven Net, runs every LoomInit, then every LoomStart. Require all of your
--- service/controller modules first.
function Loom.Spin(): Types.TypedPromise<()>
	return Registry.Spin()
end

return table.freeze(Loom)
