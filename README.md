# Loom

A fast networking and lifecycle framework for Roblox, written in strictly typed Luau. Loom organises a game into services (server), controllers (client) and components (tagged instances), and connects them with typed packets built on [ByteNet](https://github.com/ffrostflame/ByteNet).

Packets are serialised by ByteNet into buffers. Everything sent to the same destination during a frame is batched into one buffer and one remote call on Heartbeat: a thousand `sendToAll` calls in a frame produce a single `FireAllClients`. Payload types are inferred from the schema, and each side sees only the packet functions it can call.

## Requirements

- Luau's new type solver (`LuauSolverV2`). Loom's types use `read` properties, type functions and other features the old solver rejects.
  - Zed: `lsp.luau-lsp.settings.fflags.enable_new_solver = true`
  - VS Code: `luau-lsp.fflags.enableNewSolver = true`
  - CLI: `luau-lsp analyze --flag:LuauSolverV2=true`
- In editors that apply only Roblox's synced flags, also enable `LuauOverloadGetsInstantiated2`. Without it, generic calls such as `Loom.Packet({ Schema = ... })` reject tables that omit optional fields.

## Installation

```sh
pesde add tohue/loom
pesde install
```

## Structure

| Piece | Side | Purpose |
|---|---|---|
| Definition | shared | `Loom.Define`: a name, a start priority and the packets. Required by both sides. |
| Service | server | A woven definition with server logic. |
| Controller | client | A woven definition with client logic. Shares the service's definition, and with it the packets. |
| Component | either | A class bound to every instance with a CollectionService tag. |
| Packet | shared | A typed ByteNet packet inside a definition's `Net` table. |

## Example

A shared definition:

```lua
-- ReplicatedStorage/Shared/Schemas/ShopService.luau
local Loom = require(Packages.loom)
local ByteNet = Loom.Util.ByteNet

return Loom.Define({
	Name = "ShopService",
	Net = {
		Bought = Loom.Packet({
			Schema = ByteNet.struct({ item = ByteNet.string, price = ByteNet.uint16 }),
			RateLimit = { Requests = 5, Window = 1 },
		}),
	},
})
```

The typed contract, one type per service:

```lua
-- ServerScriptService/ServerAPI.luau
local Loom = require(Packages.loom)
local ShopServiceDef = require(ReplicatedStorage.Shared.Schemas.ShopService)

export type ShopService = Loom.Service<{
	Buy: (self: ShopService, player: Player, item: string) -> (),
}, typeof(ShopServiceDef.Net)>

return {
	ShopService = ShopServiceDef :: ShopService,
}
```

The implementation:

```lua
-- ServerScriptService/Services/ShopService.luau
local ShopService = Loom.Weave(API.ShopService)

function ShopService:LoomInit()
	self.Net.Bought.listen(function(data, player)
		self.Debugger:Debug("%s bought %s", player.Name, data.item)
	end)
end

function ShopService:Buy(player: Player, item: string)
	self.Net.Bought.sendTo({ item = item, price = 100 }, player)
end

return ShopService
```

The loader, once per side:

```lua
for _, module in Services:GetDescendants() do
	if module:IsA("ModuleScript") then
		require(module)
	end
end

Loom.Spin()
```

## API

### Loom.Define

```lua
Loom.Define<D>(definition: D & { read Name: string }): D
```

Declares a service or controller. The definition is returned unchanged and typed exactly as written, so `typeof(Def.Net)` is its packet table type.

| Field | Type | Description |
|---|---|---|
| `Name` | `string` | Unique name. Also the ByteNet namespace of its packets. |
| `Priority` | `number?` | Start order; higher starts first. Default `0`. |
| `Net` | `{ [string]: Packet }?` | The packets. Frozen by `Define`. |

### Loom.Packet

```lua
Loom.Packet<T>(definition: PacketDef<T>): Packet<T>
```

Creates a packet. `T` is inferred from `Schema`.

| Field | Type | Description |
|---|---|---|
| `Schema` | `T` | Built from `Loom.Util.ByteNet`. |
| `ReliabilityType` | `"reliable" \| "unreliable"` | Default `"reliable"`. Use `Loom.Enums.Reliability`. |
| `Middleware` | `{ (player, data) -> boolean }?` | Server-side checks for client packets, run in order. Returning `false` drops the packet. |
| `RateLimit` | `{ Requests, Window } \| false \| nil` | Per-player limit for client packets. `nil` uses `LoomConfig.Net.RateLimit`; `false` disables it for this packet. |

A packet's members depend on the side. A service's `Net` exposes the server members and a controller's `Net` exposes the client members; calling the other side's member is a type error.

| Member | Side | Description |
|---|---|---|
| `sendToAll(data)` | server | Sends to every player. |
| `sendTo(data, player)` | server | Sends to one player. |
| `sendToList(data, players)` | server | Sends to each player in the list. |
| `sendToAllExcept(data, player)` | server | Sends to every player but one. |
| `send(data)` | client | Sends to the server. |
| `listen(callback)` | both | `callback(data, player)`; `player` is the sender on the server and `nil` on the client. Returns a connection with `Disconnect`. |
| `wait()` | both | Yields until the next packet and returns `data, player`. |

`listen` and `wait` work immediately. The send members work after `Loom.Spin` has connected the owning service or controller.

On the server, incoming packets pass their checks in this order: the rate limit, `LoomConfig.Net.Middleware`, then the packet's own `Middleware`.

### Loom.Weave

```lua
Loom.Weave<S>(service: S): S
```

Registers a service (server) or controller (client) for `Loom.Spin` and returns the same table. Loom adds:

| Field | Type | Description |
|---|---|---|
| `Debugger` | `Debugger` | Logger named after the service. See [Debugger](#debugger). |
| `Trove` | `Trove` | Cleanup container. |
| `Priority` | `number` | `0` when the definition omits it. |

Optional lifecycle methods: `LoomInit(self)` and `LoomStart(self)`.

### Loom.Spin

```lua
Loom.Spin(): TypedPromise<()>
```

Starts every woven service or controller. Call it once, after requiring all of their modules.

1. Connects every `Net`. On the client, waits for the server to publish each namespace (`LoomConfig.Net.NamespaceTimeout`).
2. Runs every `LoomInit` concurrently and waits for all of them. A `LoomInit` may yield.
3. Spawns `LoomStart` for each successfully initialised entry, highest `Priority` first.

A failure in any step is logged with a traceback and excludes only the failing service. A `LoomInit` still running after `LoomConfig.Spin.SlowInitWarning` seconds produces a warning.

### Loom.Component

```lua
Loom.Component<S>(definition: S): S
```

Creates a component class based on sleitnick's [Component](https://github.com/Sleitnick/RbxUtil). Define methods on the returned class.

```lua
local Lamp = Loom.Component({ Tag = "Lamp" } :: API.LampComponent)

function Lamp:LoomStart()
	self.Instance.Light.Enabled = true
end

return Lamp
```

Definition fields:

| Field | Description |
|---|---|
| `Tag` | CollectionService tag the class binds to. |
| `Ancestors` | Instances under which tagged instances count. Default `{ workspace, Players }`. |
| `Extensions` | Component extensions. |
| `Decorators` | Method name to a list of decorators. The `"*"` key decorates every method except lifecycle hooks and per-frame updates. |
| `RenderPriority` | Render step priority for `RenderSteppedUpdate`. |

Other fields become class members shared by every instance.

Lifecycle methods: `LoomInit`, `LoomStart`, `LoomDestroy`, `HeartbeatUpdate(dt)`, `SteppedUpdate(dt)`, `RenderSteppedUpdate(dt)`. Each instance receives `LoomDestroy` and a cleaned `Trove` exactly once, including instances removed before they start.

Instance fields: `Instance`, `Trove`, `Debugger`, `Util` (`GetPlayerFromModel`, `GetPlayerFromPart`, `IsAlive`) and `GetComponent(class)`.

Class members: `Started`, `Stopped`, `GetAll()`, `FromInstance(instance)`, `WaitForInstance(instance, timeout?)`.

### Loom.Decorate

```lua
Loom.Decorate<S>(target: S, method: keyof<S>, ...: Decorator)
```

Wraps an existing method of a service, controller or component class. The first decorator is the outermost. `method` is type-checked against the target's keys.

```lua
Loom.Decorate(ShopService, "Buy", Decorators.Cooldown(1, function(player) return player end))
```

A decorator is a function `(self, callback, ...) -> ...`. It calls `callback(self, ...)` to run the method, or returns without calling it to block the call.

### Loom.Decorators

| Decorator | Description |
|---|---|
| `CanCall(predicate)` | Runs the method only when `predicate(self, ...)` returns `true`. |
| `Compose(...)` | Combines several decorators into one, in the given order. |
| `Cooldown(seconds, keyOf?)` | At most one call per `seconds`, per object, or per key returned by `keyOf(...)`. |
| `Debounce` | Ignores calls while the method is already running on the same object. |
| `IsBusy(flag)` | Blocks the method while `self[flag]` is `true` or `nil`. |
| `IsPlayer(aliveOnly?)` | For touch handlers: runs only when the first argument belongs to a player, and passes that player after it. |
| `Once` | Runs the method once per object. |
| `Profile(label)` | Labels each call in the MicroProfiler. For methods that do not yield. |
| `Safe` | Catches and warns about errors instead of throwing. |
| `Spawn` | Runs the method in a new thread and returns immediately. |

### Loom.Middleware

| Middleware | Description |
|---|---|
| `IsAlive` | Drops packets from players without a living character. |
| `RateLimit(requests, window)` | At most `requests` packets per player per `window` seconds. Prefer the packet's `RateLimit` field. |

Custom middleware is any `(player: Player, data) -> boolean`. Declare both parameters even when `data` is unused; a one-parameter function weakens the inferred payload type.

### Loom.Util

| Field | Description |
|---|---|
| `ByteNet` | Schema builders: `struct`, `array`, `optional`, `map`, and the data types `bool`, `string`, `buff`, `inst`, `cframe`, `vec2`, `vec3`, `uint8`, `uint16`, `uint32`, `int8`, `int16`, `int32`, `float32`, `float64`, `nothing`, `unknown`. Each type is typed as the value it carries, so `ByteNet.struct({ hp = ByteNet.uint8 })` is `{ hp: number }`. |
| `Debugger` | `Debugger.new(name)` creates a [Debugger](#debugger) outside a service. |
| `Promise` | evaera's Promise, typed. |
| `Signal` | sleitnick's Signal. |
| `Trove` | sleitnick's Trove. |
| `Sift` | csqrl's Sift. |

`Loom.Enums.Reliability` holds `Reliable` and `Unreliable`. `Loom.IS_SERVER` and `Loom.IS_STUDIO` are booleans.

### Debugger

Every service, controller and component instance has `self.Debugger`.

| Method | Output |
|---|---|
| `Trace(message, ...)` | `print` |
| `Debug(message, ...)` | `print` |
| `Info(message, ...)` | `print` |
| `Warn(message, ...)` | `warn` |
| `Error(message, ...)` | `warn` with a traceback; does not throw |
| `IsEnabled(level)` | Whether a log at `level` is written |

With extra arguments, `message` is a `string.format` pattern, formatted only when the level is enabled. Use `%*` for values that are not strings or numbers. Each line names the owner and the calling function:

```
[Debug] ShopService:Buy: Tohue bought Sword
[Trace] Lamp[Lamp1]:LoomStart: enabled
```

## Configuration

Loom reads an optional `ReplicatedStorage.LoomConfig` module. Every field is optional; omitted fields keep their defaults. Unknown keys and wrong types raise an error.

```lua
local RunService = game:GetService("RunService")
local IS_STUDIO = RunService:IsStudio()

local Loom = require(ReplicatedStorage.Packages.loom)

local config: Loom.LoomConfig = {
	Log = {
		Level = if IS_STUDIO then "Debug" else "Warn",
		Overrides = { ShopService = "Trace" },
	},
	Net = {
		RateLimit = { Requests = 30, Window = 1 },
		LogDrops = IS_STUDIO,
	},
}

return config
```

| Field | Default | Description |
|---|---|---|
| `Log.Level` | `"Debug"` in Studio, `"Warn"` live | One of `Trace`, `Debug`, `Info`, `Warn`, `Error`, `None`. |
| `Log.Overrides` | none | Level per service/controller `Name` or component `Tag`. `Loom` sets Loom's own messages. |
| `Net.RateLimit` | off | Per-player limit for every client packet without its own `RateLimit`. |
| `Net.Middleware` | none | Checks for every client packet, before each packet's own `Middleware`. |
| `Net.LogDrops` | `false` | Warns about each dropped packet with the packet, the player and the check. |
| `Net.NamespaceTimeout` | `30` | Seconds a client waits for the server to publish a namespace. |
| `Spin.SlowInitWarning` | `10` | Seconds before a running `LoomInit` produces a warning. |

The module is read the first time Loom needs a setting, so it may require Loom.

## Types

`require(Packages.loom)` exports every public type, e.g. `Loom.Service<M, N>`. They are defined in Loom's `Types` module.

| Type | Description |
|---|---|
| `Service<M, N>` | A service: members `M`, packet table `N` (usually `typeof(Def.Net)`). |
| `Controller<M, N>` | A controller: members `M`, packet table `N`. |
| `Component<T, I>` | A component class with members `T` on instances of class `I`. |
| `ComponentInstance<T, I>` | `self` inside component methods. |
| `Packet<T>`, `PacketDef<T>` | A packet and its definition. |
| `ServerNet<N>`, `ClientNet<N>` | A packet table as each side sees it. |
| `Middleware<T>`, `RateLimitConfig` | Packet checks. |
| `Decorator<Self>`, `AnyDecorator` | Decorators. |
| `Debugger`, `LogLevel` | Logging. |
| `LoomConfig` | The configuration module's shape. |
| `ByteNet` | The schema builder table. |
| `Signal<T...>`, `Connection`, `Trove`, `Promise`, `TypedPromise<T...>` | Vendor types. |

## License

MIT
