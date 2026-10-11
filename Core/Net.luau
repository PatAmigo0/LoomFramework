--!strict
--[[
	Packets. `Loom.Packet` returns the packet right away: `listen` and `wait` work at once, and the send functions
	work once `Loom.Spin` has connected the service or controller that owns the packet. Sending before that errors.

	On the server every incoming packet runs through its checks in this order: its rate limit (`RateLimit`, or
	`LoomConfig.Net.RateLimit`), `LoomConfig.Net.Middleware`, then its own `Middleware`. The first check that
	returns false drops the packet; otherwise it goes to every listener.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local ByteNet = require(LoomRoot.Vendors.ByteNet)
local Config = require(script.Parent.Config)
local Debugger = require(script.Parent.Debugger)
local Schema = require(script.Parent.Schema)
local RateLimit = require(LoomRoot.Middleware.RateLimit)

--#region TYPES
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
	attach: (raw: RawPacket, label: string) -> (),
	attached: boolean,
}
--#endregion

--#region STATE
local IS_SERVER = RunService:IsServer()

-- Loom.Packet -> its state.
local states: { [unknown]: PacketState } = {}
--#endregion

--#region LOCAL
-- A function that always errors with `message`, for send functions that can't be used (yet).
local function failing(message: string): (...unknown) -> ()
	return function()
		error(message, 2)
	end
end

-- Errors, pointing at the `Loom.Packet` call, when a packet definition is invalid.
local function checkDefinition(definition: unknown)
	if type(definition) ~= "table" then
		error("Loom.Packet expects a table", 4)
	end
	local fields = definition :: { Schema: unknown, ReliabilityType: unknown, Middleware: unknown, RateLimit: unknown }

	if fields.Schema == nil then
		error("Loom.Packet: Schema is missing", 4)
	end
	-- ByteNet would treat any other value, typos included, as "unreliable".
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
	local rateLimit = fields.RateLimit
	if rateLimit ~= nil and rateLimit ~= false then
		local problem = Config.rateLimitProblem(rateLimit)
		if problem then
			error(`Loom.Packet: RateLimit {problem}`, 4)
		end
	end
end

-- A packet's server-side checks in the order they run, and a name for each (for drop warnings).
local function buildChecks<T>(definition: PacketDef<T>): ({ Types.Middleware<T> }?, { string })
	local net = Config.get().Net
	local checks: { Types.Middleware<T> } = {}
	local names: { string } = {}

	local limit = if definition.RateLimit == nil then net.RateLimit else definition.RateLimit or nil
	if limit then
		table.insert(checks, RateLimit(limit.Requests, limit.Window))
		table.insert(names, `rate limit ({limit.Requests} per {limit.Window}s)`)
	end
	for i, check in net.Middleware do
		table.insert(checks, check)
		table.insert(names, `LoomConfig.Net.Middleware[{i}]`)
	end
	for i, check in definition.Middleware or {} do
		table.insert(checks, check)
		table.insert(names, `Middleware[{i}]`)
	end

	return if #checks > 0 then checks else nil, names
end
--#endregion

--#region API
local Net = {}

--- Creates a packet. Its send functions start working when `Net.Attach` connects it.
function Net.CreatePacket<T>(definition: PacketDef<T>): Packet<T>
	checkDefinition(definition)
	-- Set when the packet is attached (checks only on the server).
	local checks: { Types.Middleware<T> }? = nil
	local checkNames: { string } = {}
	local label = "" -- "Namespace.Key"
	local dropLog: Types.Debugger? = nil
	-- Replaced on every (dis)connect instead of changed in place, so a dispatch already running isn't affected.
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

		if checks and player then
			for i, check in checks do
				if not check(player, value) then
					local log = dropLog
					if log then
						log:Warn("Dropped %s from %s: %s", label, player.Name, checkNames[i])
					end
					return
				end
			end
		end

		local current = listeners
		if #current == 1 then
			current[1](value, player)
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
		attach = function(raw: RawPacket, key: string)
			state.attached = true
			label = key

			if IS_SERVER then
				checks, checkNames = buildChecks(definition)
				if checks and Config.get().Net.LogDrops then
					dropLog = Debugger.new("Loom")
				end
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

--- Whether `value` was made by `Loom.Packet`.
function Net.IsPacket(value: unknown): boolean
	return states[value] ~= nil
end

--- Connects a service or controller's packets under its name. On the client, waits for the server to publish them.
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
		-- ByteNet doesn't wait for the server's namespace itself.
		local storage = ReplicatedStorage:WaitForChild("BytenetStorage")
		if not storage:WaitForChild(namespace, Config.get().Net.NamespaceTimeout) then
			error(`The server never published ByteNet namespace '{namespace}'. Is its service woven?`)
		end
	end

	-- ByteNet numbers structs in creation order, so both sides must build packets in the same (sorted) order.
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
		packetStates[key].attach(raws[key], `{namespace}.{key}`)
	end
end

--#endregion

return table.freeze(Net)
