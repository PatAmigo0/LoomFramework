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

--#region VENDORS
export type Signal<T...> = SignalPackage.Signal<T...>
export type Connection = SignalPackage.Connection
export type Trove = TrovePackage.Trove
export type Promise = PromisePackage.Promise
export type TypedPromise<T...> = PromisePackage.TypedPromise<T...>

--#endregion

--#region DEBUGGER
export type LogLevel = "Trace" | "Debug" | "Info" | "Warn" | "Error" | "None"

--- `self.Debugger` on services, controllers and component instances (see Core/Debugger). With extra arguments
--- the message is a `string.format` pattern.
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

--#endregion

--#region CONFIG
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
		--- Seconds a client waits for the server to register a service's packets. Default: 30.
		NamespaceTimeout: number?,
		--- The EnumItems `QuickNet.EnumItem` can carry, at most 255. Both sides read this list, so keep it the
		--- same for server and client. Default: none.
		EnumItems: { EnumItem }?,
	}?,
	Spin: {
		--- Seconds before Loom warns about a LoomInit that hasn't returned. Default: 10.
		SlowInitWarning: number?,
	}?,
	--- Server-side protection for client -> server traffic. Everything here is off by default.
	Security: {
		--- Drop client packets with NaN or ±inf anywhere in them (numbers, Vector2/3, CFrame, Color3). Default: false.
		RejectNonFinite: boolean?,
		--- A per-player budget for everything sent to QuickNet's remotes, counted before QuickNet decodes it. A
		--- player over budget has every packet dropped until the window ends. Default: off.
		Traffic: TrafficConfig?,
		--- What to do with a player who keeps causing violations. Default: off (violations only drop packets).
		Strikes: StrikesConfig?,
		--- Called on the server for every violation, e.g. for your own logs or bans. Errors in it are caught.
		OnViolation: ((player: Player, violation: Violation) -> ())?,
	}?,
}

--- At least one of `Calls` (remote calls) and `Bytes` (buffer bytes) per player every `Window` seconds.
export type TrafficConfig = { Calls: number?, Bytes: number?, Window: number }

--- After `Limit` violations within `Window` seconds: `"Kick"` kicks the player (with `KickMessage`), `"Block"` drops
--- all of their packets for `BlockTime` seconds (default 30).
export type StrikesConfig = {
	Limit: number,
	Window: number,
	Action: "Kick" | "Block",
	BlockTime: number?,
	KickMessage: string?,
}

--- Something a client sent that Loom rejected.
--- - `"Drop"`: a rate limit, middleware or `RejectNonFinite` dropped a packet (`Packet` names it).
--- - `"Traffic"`: the player went over `Security.Traffic`.
--- - `"Payload"`: a call to QuickNet's remotes that wasn't a QuickNet buffer. The real client never sends one.
export type Violation = {
	read Kind: "Drop" | "Traffic" | "Payload",
	--- "Namespace.Key", for drops.
	read Packet: string?,
	read Reason: string,
}

--#endregion

--#region NETWORKING
export type Reliability = "reliable" | "unreliable"

--- Runs on the server for every packet a client sends, before any listener sees it.
--- Return false to drop the packet. Don't yield: QuickNet waits for it before reading the sender's next packet.
export type Middleware<T> = (player: Player, data: T) -> boolean

--- At most `Requests` packets per player every `Window` seconds; extra packets are dropped.
export type RateLimitConfig = { Requests: number, Window: number }

--- What you pass to `Loom.Packet`.
export type PacketDef<T> = {
	--- What the packet carries, built from `Loom.Util.QuickNet`, e.g. `{ hp = QuickNet.NumberU8 }`.
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
	--- `player` is the sender on the server and nil on the client. Every listener runs in a thread of its own, so
	--- it can yield.
	read listen: (callback: (data: T, player: Player?) -> ()) -> Connection,
	read wait: () -> (T, Player?),
}

--- `Loom.Util.QuickNet`: QuickNet's data types. A schema is a plain table of them, nested as deep as you like:
--- `{ hp = QuickNet.NumberU8 }` is a struct, `{ QuickNet.String }` an array, `{ [QuickNet.String] = QuickNet.NumberU8 }`
--- a map. Each type is typed as the value it carries, so the checker sees that first schema as `{ hp: number }`.
--- The QuickNet docs list every type's size and range.
export type QuickNet = {
	optional: <T>(value: T) -> T?,
	union: <A, B>(a: A, b: B) -> A | B,
	--- Typed as `unknown`; cast the payload where you use it.
	unionMany: (...unknown) -> unknown,
	--- One byte on the wire for any of the given values (strings, numbers, booleans or Vector3s).
	literal: <T>(...T) -> T,
	--- Your own encoder. `encode` writes at `offset` and returns the bytes written; `decode` returns the value and
	--- the bytes read. `metadata` is passed to both as is.
	custom: <T>(
		encode: (buff: buffer, offset: number, value: T, instances: { Instance }, metadata: unknown) -> number,
		decode: (buff: buffer, offset: number, instances: { Instance }?, metadata: unknown) -> (T, number),
		metadata: unknown?
	) -> T,

	NumberU4: number,
	NumberU8: number,
	NumberU16: number,
	NumberU32: number,
	NumberI8: number,
	NumberI16: number,
	NumberI32: number,
	NumberF16: number,
	NumberF32: number,
	NumberF64: number,

	CFrameFX8: CFrame,
	CFrameI16FX16: CFrame,
	CFrameFX16: CFrame,
	CFrameF16: CFrame,
	CFrameF32Aligned: CFrame,
	CFrameF32FX16: CFrame,
	CFrameF32: CFrame,

	Vector3FX8: Vector3,
	Vector3I16: Vector3,
	Vector3FX16: Vector3,
	Vector3F16: Vector3,
	Vector3F32: Vector3,

	Vector2FX8: Vector2,
	Vector2I16: Vector2,
	Vector2FX16: Vector2,
	Vector2F16: Vector2,
	Vector2F32: Vector2,

	--- At most 255 characters; use `StringLong` for more.
	String: string,
	StringLong: string,
	Color3: Color3,
	BrickColor: BrickColor,
	Boolean: boolean,
	Nil: nil,
	Buffer: buffer,
	--- Only items listed in `LoomConfig.Net.EnumItems`.
	EnumItem: EnumItem,
	Instance: Instance,
	Player: Player,
	DateTime32: DateTime,
	DateTime64: DateTime,
	TweenInfo: TweenInfo,
	ColorSequence: ColorSequence,
	NumberSequence: NumberSequence,
	NumberRange: NumberRange,
	UDim: UDim,
	UDim2: UDim2,
	Region3: Region3,
	PhysicalProperties: PhysicalProperties,
	Rect: Rect,
	Font: Font,
	Ray: Ray,
	Any: unknown,
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

--#endregion

--#region SERVICES & CONTROLLERS
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

--- What `Loom.Weave` adds to a service or controller written as a plain table. Intersect it with the table's own
--- type for `self`, and return the table as that type:
---
---     type Self = typeof(MyService) & Loom.Woven
---     function MyService.Foo(self: Self) ... end
---     return MyService :: Self
export type Woven = {
	Priority: number,
	Debugger: Debugger,
	Trove: Trove,
}

--#endregion

--#region DECORATORS
--- Wraps a method: call `callback(self, ...)` to run it (and pass its results on), or don't, to block the call.
export type Decorator<Self> = (self: Self, callback: (Self, ...any) -> ...any, ...any) -> ...any

--- A decorator that fits a method of any object (most built-in decorators are this).
export type AnyDecorator = <Self>(self: Self, callback: (Self, ...any) -> ...any, ...any) -> ...any

--#endregion

--#region COMPONENTS
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
--#endregion

return nil
