--!strict
--[[
	Packets. `Loom.Packet` returns the real packet straight away: `listen`/`wait` work immediately, and the send
	functions start working when the service/controller that owns the packet is spun up (`Loom.Spin`), which is
	when its ByteNet namespace gets built. Until then they error with a clear message instead of failing silently.

	Each packet has a single ByteNet listener. It runs the middleware once per packet, then hands the data to
	Loom's listeners: called directly when there is only one (no extra thread), spawned when there are several.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local ByteNet = require(LoomRoot.Vendors.ByteNet)
local Schema = require(script.Parent.Schema)

type Packet<T> = Types.Packet<T>
type PacketDef<T> = Types.PacketDef<T>
type Connection = Types.Connection
type Listener<T> = (data: T, player: Player?) -> ()

-- `Packet<T>` while Loom is still filling it in.
type MutablePacket<T> = {
	sendToAll: (data: T) -> (),
	sendTo: (data: T, target: Player) -> (),
	sendToList: (data: T, targets: { Player }) -> (),
	sendToAllExcept: (data: T, except: Player) -> (),
	send: (data: T) -> (),
	listen: (callback: Listener<T>) -> Connection,
	wait: () -> (T, Player?),
}

-- A packet as ByteNet's `defineNamespace` hands it back (only what Loom uses).
type RawPacket = {
	read sendToAll: (data: unknown) -> (),
	read sendTo: (data: unknown, target: Player) -> (),
	read sendToList: (data: unknown, targets: { Player }) -> (),
	read sendToAllExcept: (data: unknown, except: Player) -> (),
	read send: (data: unknown, target: Player?) -> (),
	read listen: (callback: (data: unknown, player: Player?) -> ()) -> (),
}

-- What Loom remembers about a packet until its namespace is built.
type PacketState = {
	schema: unknown,
	reliability: Types.Reliability?,
	attach: (raw: RawPacket) -> (),
	attached: boolean,
}

local IS_SERVER = RunService:IsServer()
-- How long a client waits for the server to publish a namespace before giving up on that controller.
local NAMESPACE_TIMEOUT = 30

local states: { [unknown]: PacketState } = {}

local function failing(message: string): (...unknown) -> ()
	return function()
		error(message, 2)
	end
end

local Net = {}

-- Checks what the type checker already does, for code it doesn't see (nonstrict files, casts). Errors point at the
-- `Loom.Packet` call.
local function checkDefinition(definition: unknown)
	if type(definition) ~= "table" then
		error("Loom.Packet expects a table", 4)
	end
	local fields = definition :: { Schema: unknown, ReliabilityType: unknown, Middleware: unknown }

	if fields.Schema == nil then
		error("Loom.Packet: Schema is missing", 4)
	end
	-- ByteNet treats anything other than "reliable" as unreliable, so a typo would silently drop reliability.
	local reliability = fields.ReliabilityType
	if reliability ~= nil and reliability ~= "reliable" and reliability ~= "unreliable" then
		error(`Loom.Packet: ReliabilityType must be "reliable" or "unreliable", got {reliability}`, 4)
	end
	local middleware = fields.Middleware
	if middleware ~= nil then
		if type(middleware) ~= "table" then
			error("Loom.Packet: Middleware must be a list of functions", 4)
		end
		for i, check in middleware :: { [unknown]: unknown } do
			if type(check) ~= "function" then
				error(`Loom.Packet: Middleware[{i}] isn't a function`, 4)
			end
		end
	end
end

function Net.CreatePacket<T>(definition: PacketDef<T>): Packet<T>
	checkDefinition(definition)
	local middleware = if IS_SERVER then definition.Middleware else nil
	-- Replaced (never mutated) on connect/disconnect, so a dispatch in progress keeps a stable list.
	local listeners: { Listener<T> } = {}

	local function listen(callback: Listener<T>): Connection
		if type(callback) ~= "function" then
			error("listen expects a function", 2)
		end
		local updated = table.clone(listeners)
		table.insert(updated, callback)
		listeners = updated

		local connection: Connection
		local function disconnect(_: Connection)
			if not connection.Connected then
				return
			end
			connection.Connected = false

			local remaining = table.clone(listeners)
			local index = table.find(remaining, callback)
			if index then
				table.remove(remaining, index)
			end
			listeners = remaining
		end

		connection = {
			Connected = true,
			Disconnect = disconnect,
			Destroy = disconnect,
		}
		return connection
	end

	local function wait(): (T, Player?)
		local thread = coroutine.running()
		local connection: Connection
		connection = listen(function(data, player)
			connection:Disconnect()
			task.spawn(thread, data, player)
		end)

		local data, player = coroutine.yield()
		return data :: T, player :: Player?
	end

	local function dispatch(data: unknown, player: Player?)
		-- ByteNet decoded `data` with this packet's schema, so it is a `T`.
		local value = data :: T

		if middleware and player then
			for _, check in middleware do
				if not check(player, value) then
					return
				end
			end
		end

		local current = listeners
		if #current == 1 then
			current[1](value, player) -- already running on a ByteNet listener thread
		else
			for _, listener in current do
				task.spawn(listener, value, player)
			end
		end
	end

	local notReady = failing(
		"This packet isn't connected yet. It connects when its service/controller is spun up (Loom.Spin), "
			.. "so send from LoomInit/LoomStart or later."
	)

	local packet: MutablePacket<T> = {
		sendToAll = notReady,
		sendTo = notReady,
		sendToList = notReady,
		sendToAllExcept = notReady,
		send = notReady,
		listen = listen,
		wait = wait,
	}

	local state: PacketState
	state = {
		schema = definition.Schema,
		reliability = definition.ReliabilityType,
		attached = false,
		attach = function(raw: RawPacket)
			state.attached = true

			if IS_SERVER then
				packet.sendToAll = raw.sendToAll
				packet.sendTo = raw.sendTo
				packet.sendToList = raw.sendToList
				packet.sendToAllExcept = raw.sendToAllExcept
				packet.send = failing("send is client -> server; on the server use sendTo/sendToList/sendToAll")
			else
				local serverOnly = failing("sendTo/sendToList/sendToAll(Except) are server -> client; use send")
				packet.sendToAll = serverOnly
				packet.sendTo = serverOnly
				packet.sendToList = serverOnly
				packet.sendToAllExcept = serverOnly
				local send = raw.send
				packet.send = function(data)
					send(data)
				end
			end

			raw.listen(dispatch)
			table.freeze(packet)
		end,
	}
	states[packet] = state

	return packet
end

function Net.IsPacket(value: unknown): boolean
	return states[value] ~= nil
end

--- Builds the ByteNet namespace for a service/controller's `Net` and connects its packets. Yields on the
--- client until the server has published the namespace.
function Net.Attach(namespace: string, net: { [string]: unknown })
	local keys = Schema.sortedKeys(net)
	local packetStates: { [string]: PacketState } = {}

	for _, key in keys do
		local state = states[net[key]]
		if not state then
			error(`{namespace}.Net.{key} isn't a Loom.Packet`)
		elseif state.attached then
			error(`{namespace}.Net.{key} is already connected (two services share one packet?)`)
		end
		packetStates[key] = state
	end

	if not IS_SERVER then
		-- ByteNet reads the namespace the server published without waiting for it, so wait here.
		local storage = ReplicatedStorage:WaitForChild("BytenetStorage")
		if not storage:WaitForChild(namespace, NAMESPACE_TIMEOUT) then
			error(`The server never published ByteNet namespace '{namespace}'. Is its service woven?`)
		end
	end

	-- ByteNet numbers structs in creation order, so packets are built in the same (sorted) order on both sides.
	local raws = ByteNet.defineNamespace(namespace, function()
		local definitions = {}
		for _, key in keys do
			local state = packetStates[key]
			definitions[key] = ByteNet.definePacket({
				value = Schema.resolve(state.schema),
				reliabilityType = state.reliability,
			})
		end
		return definitions
	end)

	for _, key in keys do
		packetStates[key].attach(raws[key])
	end
end

return table.freeze(Net)
