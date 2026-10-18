--!strict
--[[
	Packets, sent with QuickNet. `Loom.Packet` returns the packet right away: `listen` and `wait` work at once, and
	the send functions work once `Loom.Spin` has connected the service or controller that owns the packet. Sending
	before that errors.

	Each packet is one QuickNet event named "Namespace_Key", and QuickNet allows 255 events per game. The server
	registers its packets during `Loom.Spin`. A client waits for the server's (up to `LoomConfig.Net.NamespaceTimeout`
	seconds), then registers its own. A client has to know an event before data for it arrives: when the server sends
	a packet the client hasn't connected, QuickNet drops it and everything after it in that frame's batch. So a
	service that sends to clients needs a controller woven on the client. The client loads QuickNet only when it
	connects its first packet, because QuickNet starts reading server traffic as soon as it loads; until then Roblox
	holds the traffic back.

	On the server every incoming packet runs through its checks in this order: its rate limit (`RateLimit`, or
	`LoomConfig.Net.RateLimit`), the NaN/inf check (`LoomConfig.Security.RejectNonFinite`),
	`LoomConfig.Net.Middleware`, then its own `Middleware`. The first check that returns false drops the packet and
	reports it to Security; otherwise every listener gets it, each in a thread of its own. Packets from a player
	Security has blocked are dropped before any check. QuickNet's per-event rate limit is off, since its drops
	wouldn't reach Security.
]]

local RunService = game:GetService("RunService")

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Signal = require(LoomRoot.Vendors.Signal)
local Config = require(script.Parent.Config)
local Debugger = require(script.Parent.Debugger)
local Schema = require(script.Parent.Schema)
local Security = require(script.Parent.Security)
local Finite = require(LoomRoot.Middleware.Finite)
local RateLimit = require(LoomRoot.Middleware.RateLimit)

--#region TYPES
type Packet<T> = Types.Packet<T>
type PacketDef<T> = Types.PacketDef<T>
type Connection = Types.Connection

-- `Packet<T>` while Loom is still filling it in.
type MutablePacket<T> = {
	sendToAll: (data: T) -> (),
	sendTo: (data: T, target: Player) -> (),
	sendToList: (data: T, targets: { Player }) -> (),
	sendToAllExcept: (data: T, except: Player) -> (),
	send: (data: T) -> (),
	listen: (callback: (data: T, player: Player?) -> ()) -> Connection,
	wait: () -> (T, Player?),
}

-- What Loom uses of QuickNet. Every Loom event carries one value, the packet's payload.
type ServerSignal = { Connect: (self: ServerSignal, callback: (player: Player, data: unknown) -> ()) -> unknown }
type ClientSignal = { Connect: (self: ClientSignal, callback: (data: unknown) -> ()) -> unknown }
type Event = {
	FireAllClients: (self: Event, data: unknown) -> (),
	FireClient: (self: Event, player: Player, data: unknown) -> (),
	FireClients: (self: Event, players: { Player }, data: unknown) -> (),
	FireAllExcept: (self: Event, except: Player, data: unknown) -> (),
	FireServer: (self: Event, data: unknown) -> (),
	Unreliable: (self: Event) -> Event,
	OnServerEvent: ServerSignal,
	OnClientEvent: ClientSignal,
}
type Library = {
	register: (self: Library, name: string, schema: unknown) -> Event,
	addEnumItems: (self: Library, enums: { EnumItem }) -> (),
}
-- QuickNet's Config module, which its main module reads once, when it loads.
type Settings = {
	DebugMode: boolean,
	DefaultRateLimit: { Max: number, Time: number },
}

-- What Loom remembers about a packet until it's registered.
type PacketState = {
	schema: unknown,
	reliability: Types.Reliability?,
	attach: (event: Event, label: string) -> (),
	attached: boolean,
}
--#endregion

--#region STATE
local IS_SERVER = RunService:IsServer()
local QUICKNET = LoomRoot.Vendors.QuickNet
-- QuickNet keeps each event's id in an attribute named after the event, so names follow Roblox's attribute rules.
local MAX_NAME_LENGTH = 100

-- Loom.Packet -> its state.
local states: { [unknown]: PacketState } = {}
local library: Library? = nil
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
	local schemaProblem = Schema.problem(fields.Schema)
	if schemaProblem then
		error(`Loom.Packet: QuickNet rejects the Schema: {schemaProblem}`, 4)
	end
	-- Anything else, typos included, would quietly mean "reliable".
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
	if Config.get().Security.RejectNonFinite then
		table.insert(checks, Finite)
		table.insert(names, "NaN or inf (Security.RejectNonFinite)")
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

-- QuickNet, loaded with Loom's settings on the first call.
local function load(): Library
	local current = library
	if current then
		return current
	end

	local settings = (require(QUICKNET.Config) :: unknown) :: Settings
	-- QuickNet's own warnings (oversized or malformed batches, a full send buffer) follow Loom's Warn level.
	settings.DebugMode = Debugger.new("Loom"):IsEnabled("Warn")
	settings.DefaultRateLimit = { Max = math.huge, Time = 0 }

	local loaded = (require(QUICKNET) :: unknown) :: Library
	local enumItems = Config.get().Net.EnumItems
	if #enumItems > 0 then
		loaded:addEnumItems(enumItems)
	end
	library = loaded
	return loaded
end

-- Waits for the server to register every name in `names`. Returns the first one still missing after `timeout`
-- seconds, or nil once all of them are there.
local function waitForServer(names: { string }, timeout: number): string?
	local deadline = os.clock() + timeout
	local remote = QUICKNET:WaitForChild("QuickNetRemote", timeout)
	if not remote then
		return names[1]
	end
	for _, name in names do
		while remote:GetAttribute(name) == nil do
			if os.clock() >= deadline then
				return name
			end
			task.wait()
		end
	end
	return nil
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
	local received: Types.Signal<T, Player?> = Signal.new()

	local function listen(callback: (data: T, player: Player?) -> ()): Connection
		if type(callback) ~= "function" then
			error("listen expects a function", 2)
		end
		return received:Connect(callback)
	end

	local function wait(): (T, Player?)
		return received:Wait()
	end

	local function dispatch(data: unknown, player: Player?)
		-- QuickNet decoded `data` with this packet's schema, so it is a `T`.
		local value = data :: T

		if player then
			if Security.IsBlocked(player) then
				return
			end
			if checks then
				for i, check in checks do
					if not check(player, value) then
						local log = dropLog
						if log then
							log:Warn("Dropped %s from %s: %s", label, player.Name, checkNames[i])
						end
						Security.Dropped(player, label, checkNames[i])
						return
					end
				end
			end
		end

		received:Fire(value, player)
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
		attach = function(event: Event, key: string)
			state.attached = true
			label = key

			if IS_SERVER then
				checks, checkNames = buildChecks(definition)
				if checks and Config.get().Net.LogDrops then
					dropLog = Debugger.new("Loom")
				end
				packet.sendToAll = function(data)
					event:FireAllClients(data)
				end
				packet.sendTo = function(data, target)
					event:FireClient(target, data)
				end
				packet.sendToList = function(data, targets)
					event:FireClients(targets, data)
				end
				packet.sendToAllExcept = function(data, except)
					event:FireAllExcept(except, data)
				end
				packet.send = failing("send is client -> server; on the server use sendTo/sendToList/sendToAll")
				event.OnServerEvent:Connect(function(player, data)
					dispatch(data, player)
				end)
			else
				local serverOnly = failing("sendTo/sendToList/sendToAll(Except) are server -> client; use send")
				packet.sendToAll = serverOnly
				packet.sendTo = serverOnly
				packet.sendToList = serverOnly
				packet.sendToAllExcept = serverOnly
				packet.send = function(data)
					event:FireServer(data)
				end
				event.OnClientEvent:Connect(function(data)
					dispatch(data, nil)
				end)
			end

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

--- Errors, pointing at the caller's caller, unless `net` is a `Loom.Define` Net table and `forServer` matches the side
--- this code runs on. `name` is the Loom function being called, for the message.
function Net.CheckView(net: unknown, name: string, forServer: boolean)
	if forServer ~= IS_SERVER then
		local other = if forServer then "Loom.ClientNet" else "Loom.ServerNet"
		error(`{name} is for {if forServer then "services" else "controllers"}; use {other} here`, 3)
	elseif type(net) ~= "table" then
		error(`{name} expects a definition's Net table (MyServiceDef.Net), got {typeof(net)}`, 3)
	end
	for key, value in net :: { [unknown]: unknown } do
		if not states[value] then
			error(`{name} expects a definition's Net table (MyServiceDef.Net); {key} isn't a Loom.Packet`, 3)
		end
	end
end

--- Server only: loads QuickNet and has Security watch its remotes. The client loads QuickNet in `Net.Attach`.
function Net.Start()
	if not IS_SERVER then
		return
	end
	load()
	local remotes: { Instance } = {}
	for _, name in { "QuickNetRemote", "QuickNetUnreliable" } do
		local remote = QUICKNET:FindFirstChild(name)
		if remote then
			table.insert(remotes, remote)
		end
	end
	Security.Start(remotes)
end

--- Registers a service or controller's packets with QuickNet. On the client, waits for the server's first.
function Net.Attach(namespace: string, net: { [string]: unknown })
	local names: { string } = {}
	local labels: { [string]: string } = {}
	local packetStates: { [string]: PacketState } = {}

	for key, value in net do
		local state = states[value]
		if not state then
			error(`{namespace}.Net.{key} isn't a Loom.Packet`)
		elseif state.attached then
			error(`{namespace}.Net.{key} is already connected (two services share one packet?)`)
		end
		local name = `{namespace}_{key}`
		if #name > MAX_NAME_LENGTH or not string.match(name, "^[%w_]+$") or string.match(name, "^RBX") then
			error(
				`{namespace}.Net.{key} would be QuickNet event "{name}". Event names take letters, digits and _ `
					.. `only, at most {MAX_NAME_LENGTH} characters, and can't start with RBX`
			)
		end
		table.insert(names, name)
		labels[name] = `{namespace}.{key}`
		packetStates[name] = state
	end
	table.sort(names)

	if not IS_SERVER then
		local missing = waitForServer(names, Config.get().Net.NamespaceTimeout)
		if missing then
			error(`The server never registered QuickNet event '{missing}'. Is {namespace} woven on the server?`)
		end
	end

	local quickNet = load()
	for _, name in names do
		local state = packetStates[name]
		local event = quickNet:register(name, Schema.copy(state.schema))
		if state.reliability == "unreliable" then
			event = event:Unreliable()
		end
		state.attach(event, labels[name])
	end
end

--#endregion

return table.freeze(Net)
