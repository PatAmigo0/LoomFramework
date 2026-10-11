--!strict
--[[
	Every public Loom type lives here, and only here.

	    local Types = require(Shared.Loom.Types)
	    export type MyService = Types.Service<{ ... }, typeof(MyServiceDef.Net)>

	Types that only Loom's internals need are plain (non-exported) `type`s inside the module that uses them.
]]

local LoomRoot = script.Parent
local Packages = LoomRoot.roblox_packages

local PromisePackage = require(Packages["typed-promise"])
local SignalPackage = require(Packages.signal)
local TrovePackage = require(Packages.trove)
-- selene: allow(unused_variable) -- only used in a type position (`typeof`), which selene doesn't see
local ComponentUtil = require(LoomRoot.Core.Component.Util)

-- ==========================================
-- VENDORS
-- ==========================================
export type Signal<T...> = SignalPackage.Signal<T...>
export type Connection = SignalPackage.Connection
export type Trove = TrovePackage.Trove
export type Promise = PromisePackage.Promise
export type TypedPromise<T...> = PromisePackage.TypedPromise<T...>

-- ==========================================
-- DEBUGGER
-- ==========================================
export type LogLevel = "Trace" | "Debug" | "Info" | "Warn" | "Error" | "None"

--- `self.Debugger` on services, controllers and component instances (see Core/Debugger). With extra arguments
--- the message is a `string.format` pattern, formatted only when the level is on.
export type Debugger = {
	read Name: string,
	read Trace: (self: Debugger, message: string, ...unknown) -> (),
	read Debug: (self: Debugger, message: string, ...unknown) -> (),
	read Info: (self: Debugger, message: string, ...unknown) -> (),
	read Warn: (self: Debugger, message: string, ...unknown) -> (),
	--- Warns with a traceback. Doesn't throw.
	read Error: (self: Debugger, message: string, ...unknown) -> (),
	--- Whether a log at `level` would be written; use it to skip work that only feeds a log.
	read IsEnabled: (self: Debugger, level: LogLevel) -> boolean,
}

-- ==========================================
-- CONFIG
-- ==========================================
--- What `ReplicatedStorage.LoomConfig` returns. Every field is optional. It's a module, so branch on
--- `RunService:IsStudio()` for different test and live values. It can require Loom (e.g. for `Loom.Middleware`).
export type LoomConfig = {
	Log: {
		--- Default: "Debug" in Studio, "Warn" in live games.
		Level: LogLevel?,
		--- Levels by service/controller Name or component Tag; "Loom" is Loom's own messages.
		Overrides: { [string]: LogLevel }?,
	}?,
	Net: {
		--- Applied to every client -> server packet that doesn't set its own `RateLimit`. Default: off.
		RateLimit: (RateLimitConfig | false)?,
		--- Runs on the server for every client -> server packet, before the packet's own Middleware.
		Middleware: { (player: Player, data: unknown) -> boolean }?,
		--- Warn when a rate limit or middleware drops a packet. Default: false.
		LogDrops: boolean?,
		--- Seconds a client waits for the server to publish a service's packets. Default: 30.
		NamespaceTimeout: number?,
	}?,
	Spin: {
		--- Seconds before Loom warns about a LoomInit that hasn't returned. Default: 10.
		SlowInitWarning: number?,
	}?,
}

-- ==========================================
-- NETWORKING
-- ==========================================
export type Reliability = "reliable" | "unreliable"

--- Runs on the server for every packet a client sends, before any listener sees it.
--- Return false to drop the packet.
export type Middleware<T> = (player: Player, data: T) -> boolean

--- At most `Requests` packets per player every `Window` seconds; extra packets are dropped.
export type RateLimitConfig = { Requests: number, Window: number }

--- What you pass to `Loom.Packet`.
export type PacketDef<T> = {
	--- What the packet carries, built from `Loom.Util.ByteNet`, e.g. `ByteNet.struct({ hp = ByteNet.uint8 })`.
	Schema: T,
	ReliabilityType: Reliability?,
	--- Runs on the server after `LoomConfig.Net.Middleware`, in order.
	Middleware: { Middleware<T> }?,
	--- This packet's limit for client -> server sends. Leave it out to use `LoomConfig.Net.RateLimit`; `false`
	--- turns the default off for this packet.
	RateLimit: (RateLimitConfig | false)?,
}

export type Packet<T> = {
	-- server -> client
	read sendToAll: (data: T) -> (),
	read sendTo: (data: T, target: Player) -> (),
	read sendToList: (data: T, targets: { Player }) -> (),
	read sendToAllExcept: (data: T, except: Player) -> (),
	-- client -> server
	read send: (data: T) -> (),
	--- `player` is the sender on the server and nil on the client.
	read listen: (callback: (data: T, player: Player?) -> ()) -> Connection,
	read wait: () -> (T, Player?),
}

--- `Loom.Util.ByteNet`. Every data type is typed as the value it carries, so the type checker sees
--- `ByteNet.struct({ hp = ByteNet.uint8 })` as `{ hp: number }` and infers packet payloads for you.
export type ByteNet = {
	struct: <T>(format: T) -> T,
	array: <T>(value: T) -> { T },
	optional: <T>(value: T) -> T?,
	map: <K, V>(key: K, value: V) -> { [K]: V },

	bool: boolean,
	string: string,
	buff: buffer,
	inst: Instance,
	cframe: CFrame,
	vec2: Vector2,
	vec3: Vector3,

	uint8: number,
	uint16: number,
	uint32: number,
	int8: number,
	int16: number,
	int32: number,
	float32: number,
	float64: number,

	nothing: nil,
	unknown: unknown,
}

--- Rebuilds every packet in a `Net` table with only the members named in `Keep` (a union of string
--- singletons). A service and a controller share one `Net` definition, but each side may only call its own
--- half of a packet; this is what keeps the other half out of autocomplete.
type function PacketView(net: type, keep: type): type
	if net.tag ~= "table" then
		return net -- a service without a Net
	end

	local members = if keep.tag == "union" then keep:components() else { keep }
	local view = types.newtable()
	for name, property in net:properties() do
		local packet = property.read
		if packet and packet.tag == "table" then
			local trimmed = types.newtable()
			for _, member in members do
				local memberType = packet:readproperty(member)
				if memberType then
					trimmed:setreadproperty(member, memberType)
				end
			end
			view:setreadproperty(name, trimmed)
		end
	end
	return view
end

--- A `Net` table as the server sees it: no `send`, which is client -> server only.
export type ServerNet<N> = PacketView<N, "sendToAll" | "sendTo" | "sendToList" | "sendToAllExcept" | "listen" | "wait">

--- A `Net` table as the client sees it: only `send`, `listen` and `wait`.
export type ClientNet<N> = PacketView<N, "send" | "listen" | "wait">

-- ==========================================
-- SERVICES & CONTROLLERS
-- ==========================================
--- A service (server): your members `M` plus everything Loom injects.
--- `N` is its networking table, usually `typeof(MyServiceDef.Net)`.
export type Service<M, N = nil> = M & {
	Name: string,
	Priority: number,
	Net: ServerNet<N>,
	Debugger: Debugger,
	Trove: Trove,

	-- Lifecycle hooks are optional; Loom skips the ones you don't write. They're typed as required because
	-- the type solver only gives `function MyService:LoomInit()` a typed `self` from a non-optional field.
	LoomInit: (self: Service<M, N>) -> (),
	LoomStart: (self: Service<M, N>) -> (),
}

--- A controller (client): like `Service`, but its packets show only what a client can call.
export type Controller<M, N = nil> = M & {
	Name: string,
	Priority: number,
	Net: ClientNet<N>,
	Debugger: Debugger,
	Trove: Trove,

	LoomInit: (self: Controller<M, N>) -> (),
	LoomStart: (self: Controller<M, N>) -> (),
}

-- ==========================================
-- DECORATORS
-- ==========================================
--- Wraps a method: call `callback(self, ...)` to run it (and pass its results on), or don't, to block the call.
export type Decorator<Self> = (self: Self, callback: (Self, ...any) -> ...any, ...any) -> ...any

--- A decorator that fits a method of any object (most built-in decorators are this).
export type AnyDecorator = <Self>(self: Self, callback: (Self, ...any) -> ...any, ...any) -> ...any

-- ==========================================
-- COMPONENTS
-- ==========================================
export type ComponentUtil = typeof(ComponentUtil)

--- `self` inside a component method: your members `T` plus what Loom gives every component instance.
export type ComponentInstance<T, I = Instance> = T & {
	Instance: I,
	Trove: Trove,
	Debugger: Debugger,
	Util: ComponentUtil,

	--- This instance's component of another class, if the Roblox instance has one.
	GetComponent: <C>(
		self: ComponentInstance<T, I>,
		component: { read FromInstance: (never, Instance) -> C? }
	) -> C?,
}

--- Hooks into how instances of one component class are built. See sleitnick's Component docs.
export type ComponentExtension<Self> = {
	ShouldExtend: ((component: Self) -> boolean)?,
	ShouldConstruct: ((component: Self) -> boolean)?,
	Constructing: ((component: Self) -> ())?,
	Constructed: ((component: Self) -> ())?,
	Starting: ((component: Self) -> ())?,
	Started: ((component: Self) -> ())?,
	Stopping: ((component: Self) -> ())?,
	Stopped: ((component: Self) -> ())?,
}

--- A component class: your members `T` (methods take `self: ComponentInstance<T, I>`), its configuration,
--- and the class API you get back from `Loom.Component`.
export type Component<T, I = Instance> = T & {
	Tag: string,
	Ancestors: { Instance }?,
	Extensions: { ComponentExtension<ComponentInstance<T, I>> }?,
	--- Method name -> decorators, outermost first. The `"*"` key decorates every method.
	Decorators: { [string]: { Decorator<ComponentInstance<T, I>> } }?,
	RenderPriority: number?,

	-- Optional hooks, typed as required for the same reason as on `Service`.
	LoomInit: (self: ComponentInstance<T, I>) -> (),
	LoomStart: (self: ComponentInstance<T, I>) -> (),
	LoomDestroy: (self: ComponentInstance<T, I>) -> (),
	HeartbeatUpdate: (self: ComponentInstance<T, I>, dt: number) -> (),
	SteppedUpdate: (self: ComponentInstance<T, I>, dt: number) -> (),
	RenderSteppedUpdate: (self: ComponentInstance<T, I>, dt: number) -> (),

	Started: Signal<ComponentInstance<T, I>>,
	Stopped: Signal<ComponentInstance<T, I>>,
	GetAll: (self: Component<T, I>) -> { ComponentInstance<T, I> },
	FromInstance: (self: Component<T, I>, instance: Instance) -> ComponentInstance<T, I>?,
	WaitForInstance: (
		self: Component<T, I>,
		instance: Instance,
		timeout: number?
	) -> TypedPromise<ComponentInstance<T, I>>,
}

return nil
