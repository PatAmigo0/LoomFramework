# Loom

A fast networking and lifecycle framework for Roblox, written in strictly typed Luau. Loom organises a game into services (server), controllers (client) and components (tagged instances), and connects them with typed packets built on [QuickNet](https://github.com/breadboardengineer1234/QuickNet).

Packets are serialised by QuickNet into buffers. Everything sent to one player during a frame goes out as one buffer in one remote call after physics (one per reliability), so a thousand `sendToAll` calls in a frame cost each player a single call. `sendToAll` and `sendToList` encode the data once and copy the bytes for every other player. Payload types are inferred from the schema, and each side sees only the packet functions it can call.

Loom ships its own copy of QuickNet 0.4.0 in `Vendors/QuickNet` (Wally only has 0.3.5) with one fix: upstream rejects a struct with a single field.

## Requirements

- Luau's new type solver (`LuauSolverV2`). Loom's types use `read` properties, type functions and other features the old solver rejects.
  - Zed: `lsp.luau-lsp.settings.fflags.enable_new_solver = true`
  - VS Code: `luau-lsp.fflags.enableNewSolver = true`
  - CLI: `luau-lsp analyze --flag:LuauSolverV2=true`
- In editors that apply only Roblox's synced flags, also enable `LuauOverloadGetsInstantiated2`. Without it, generic calls such as `Loom.Packet({ Schema = ... })` reject tables that omit optional fields.

## Installation

With pesde:

```sh
pesde add tohue/loom
pesde install
```

With Wally, add Loom to `wally.toml` and run `wally install`:

```toml
[dependencies]
loom = "tohue/loom@0.7.0"
```

The examples below use the alias `loom`, so `require(Packages.loom)` works with either. Wally's generated `Packages/loom.lua` returns the module but drops its exported types; run [wally-package-types](https://github.com/JohnnyMorganz/wally-package-types) after each install (`wally-package-types --sourcemap sourcemap.json Packages/`) to get `Loom.Service<M, N>` and the other types back.

## Structure

| Piece | Side | Purpose |
|---|---|---|
| Definition | shared | `Loom.Define`: a name, a start priority and the packets. Required by both sides. |
| Service | server | A woven definition with server logic. |
| Controller | client | A woven definition with client logic. Shares the service's definition, and with it the packets. |
| Component | either | A class bound to every instance with a CollectionService tag. |
| Packet | shared | A typed QuickNet event inside a definition's `Net` table. |

## Example

A shared definition:

```lua
-- ReplicatedStorage/Shared/Schemas/ShopService.luau
local Loom = require(Packages.loom)
local QuickNet = Loom.Util.QuickNet

return Loom.Define({
	Name = "ShopService",
	Net = {
		Bought = Loom.Packet({
			Schema = { item = QuickNet.String, price = QuickNet.NumberU16 },
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
| `Name` | `string` | Unique name. Its packets become QuickNet events named `Name_Key`, so names use letters, digits and `_` only. |
| `Priority` | `number?` | Start order; higher starts first. Default `0`. |
| `Net` | `{ [string]: Packet }?` | The packets. Frozen by `Define`. |

### Loom.Packet

```lua
Loom.Packet<T>(definition: PacketDef<T>): Packet<T>
```

Creates a packet. `T` is inferred from `Schema`.

| Field | Type | Description |
|---|---|---|
| `Schema` | `T` | Built from `Loom.Util.QuickNet`. Checked when the packet is created. |
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
| `listen(callback)` | both | `callback(data, player)`; `player` is the sender on the server and `nil` on the client. Each listener runs in a thread of its own, so it may yield. Returns a connection with `Disconnect`. |
| `wait()` | both | Yields until the next packet and returns `data, player`. |

`listen` and `wait` work immediately. The send members work after `Loom.Spin` has connected the owning service or controller.

The server registers its packets during `Loom.Spin`, and each client registers the same ones once the server's are there. A game can have at most 255 packets in total (a QuickNet limit). If the server sends a packet that a client hasn't registered, QuickNet drops it along with everything after it in that frame's batch for that client. Weave a controller for every service that sends to clients, even one with no client logic.

On the server, incoming packets pass their checks in this order: the rate limit, the NaN/inf check (`LoomConfig.Security.RejectNonFinite`), `LoomConfig.Net.Middleware`, then the packet's own `Middleware`. Packets from a player that [Security](#security) has blocked are dropped before any of them. Middleware shouldn't yield: QuickNet waits for it before it reads that player's next packet.

#### Schemas

A schema is a plain table of `Loom.Util.QuickNet` data types, nested however you need:

```lua
local QuickNet = Loom.Util.QuickNet

Schema = QuickNet.NumberU8                                  -- number
Schema = { hp = QuickNet.NumberU8, name = QuickNet.String }  -- { hp: number, name: string }
Schema = { QuickNet.Vector3F32 }                             -- { Vector3 }, any length
Schema = { [QuickNet.String] = QuickNet.NumberI32 }          -- { [string]: number }
Schema = QuickNet.optional({ id = QuickNet.NumberU16 })      -- { id: number }?
Schema = QuickNet.literal("Idle", "Attack")                  -- one byte on the wire
```

A table with several types in a row (`{ QuickNet.String, QuickNet.NumberU8 }`) is a fixed-length array. The [QuickNet docs](https://breadboardengineer1234.github.io/QuickNet/types) cover every type's size and range, the fixed-point `FX` types, unions and custom encoders. Two differences from plain QuickNet: a one-field struct works, and Loom copies schemas before QuickNet sees them, so one schema table can be shared by several packets.

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

A table that already has a `Debugger` or `Trove` keeps it, and Loom warns about that in Studio (only there, so live servers stay quiet).

Optional lifecycle methods: `LoomInit(self)` and `LoomStart(self)`.

#### Services as plain tables

A service or controller doesn't need a hand-written type in an API module. Write it as a plain table, and the type checker works out its type from the table and the methods you add:

```lua
-- Services/ShopService.luau
local ShopServiceDef = require(ReplicatedStorage.Shared.Schemas.ShopService)

local ShopService = {
	Name = ShopServiceDef.Name,
	Net = Loom.ServerNet(ShopServiceDef.Net), -- Loom.ClientNet in a controller
	prices = { Sword = 100 } :: { [string]: number },
}
Loom.Weave(ShopService)
type Self = typeof(ShopService) & Loom.Woven

function ShopService.Buy(self: Self, player: Player, item: string): boolean
	local price = self:PriceOf(item)
	...
end

function ShopService.PriceOf(self: Self, item: string): number?
	return self.prices[item]
end

return ShopService :: Self
```

Other modules `require` the service and get every method typed. Inside, `self: Self` checks fields, `self.Debugger`, `self.Net` and calls to methods defined anywhere in the file. Three things keep it working:

- Call `Loom.Weave(ShopService)` as a statement. `local ShopService = Loom.Weave({ ... })` compiles, but a table that comes back out of a generic function loses the checks on `self:Method()` calls.
- Give every method an explicit `self: Self` (`function ShopService.Buy(self: Self, ...)`); callers still write `ShopService:Buy(...)`. Without it, `self` isn't typed at all.
- End with `return ShopService :: Self`, so callers see the `Woven` fields the methods expect.

Services that require each other can't both be written this way: Roblox stops a `require` cycle at runtime, and the type checker loses the types across it. Keep at least one of them in an API module, as above.

### Loom.ServerNet / Loom.ClientNet

```lua
Loom.ServerNet<N>(net: N): ServerNet<N>
Loom.ClientNet<N>(net: N): ClientNet<N>
```

Return a definition's `Net` table typed for one side, for services and controllers written as plain tables. Each errors on the wrong side, or when given something that isn't a `Loom.Define` Net table.

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
| `Finite` | Drops packets with NaN or ±inf anywhere in them: numbers, `Vector2`, `Vector3`, `CFrame`, `Color3`, and table keys and values. `LoomConfig.Security.RejectNonFinite` applies it to every packet. |

Custom middleware is any `(player: Player, data) -> boolean`. Declare both parameters even when `data` is unused; a one-parameter function weakens the inferred payload type.

### Loom.Util

| Field | Description |
|---|---|
| `QuickNet` | QuickNet's data types (`NumberU8`, `String`, `Vector3F32`, `CFrameF32FX16`, ...) and `optional`, `union`, `unionMany`, `literal`, `custom`. Each type is typed as the value it carries, so `{ hp = QuickNet.NumberU8 }` is `{ hp: number }`. See [Schemas](#schemas). |
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
| `Net.NamespaceTimeout` | `30` | Seconds a client waits for the server to register a service's packets. |
| `Net.EnumItems` | none | The EnumItems `QuickNet.EnumItem` can carry, at most 255. Keep the list the same on both sides. |
| `Spin.SlowInitWarning` | `10` | Seconds before a running `LoomInit` produces a warning. |

The module is read the first time Loom needs a setting, so it may require Loom.

### Security

`LoomConfig.Security` protects the server from what clients send. Every part is off by default and works on its own. A client controls everything it sends, so none of this replaces checking requests in your services (does the player own that item, can they reach that position); it handles the generic cases.

```lua
Security = {
	RejectNonFinite = true,
	Traffic = { Calls = 120, Bytes = 64 * 1024, Window = 1 },
	Strikes = { Limit = 20, Window = 10, Action = "Kick" },
	OnViolation = function(player, violation)
		warn(player.Name, violation.Kind, violation.Packet, violation.Reason)
	end,
},
```

| Field | Default | Description |
|---|---|---|
| `Security.RejectNonFinite` | `false` | Drops client packets with NaN or ±inf anywhere in them. QuickNet's float types decode any bits a client sends, and NaN gets past checks like `if damage > 100` because every comparison with it is false. |
| `Security.Traffic` | off | `{ Calls?, Bytes?, Window }`: a per-player budget for every call to QuickNet's remotes, counted before QuickNet decodes anything, so malformed buffers count too. A player over budget has every packet dropped until the window ends. |
| `Security.Strikes` | off | `{ Limit, Window, Action, BlockTime?, KickMessage? }`: after `Limit` violations within `Window` seconds, `"Kick"` kicks the player and `"Block"` drops all their packets for `BlockTime` seconds (default 30). |
| `Security.OnViolation` | none | `(player, violation)`, called for every violation in its own thread. `violation.Kind` is `"Drop"` (a check dropped a packet; `violation.Packet` names it), `"Traffic"` (over budget) or `"Payload"` (a remote call that isn't a QuickNet buffer, which the real client never sends). |

Every dropped packet counts as a violation, rate limit drops included. Set `Strikes.Limit` high enough that a laggy client releasing a burst of queued packets doesn't get kicked. Loom logs traffic blocks, strike blocks and kicks at `Warn` under the name `Loom`.

Loom's remote listener runs after QuickNet's, so the call that crosses the traffic budget still gets decoded; the block starts with the next one. QuickNet has its own limits too: it drops a call over 50,000 bytes and every packet past the 100th in one call, and a buffer it can't decode loses the rest of that call with a warning instead of an error.

## Types

`require(Packages.loom)` exports every public type, e.g. `Loom.Service<M, N>`. They are defined in Loom's `Types` module.

| Type | Description |
|---|---|
| `Service<M, N>` | A service: members `M`, packet table `N` (usually `typeof(Def.Net)`). |
| `Woven` | What `Loom.Weave` adds (`Priority`, `Debugger`, `Trove`), for `type Self = typeof(MyService) & Loom.Woven`. |
| `Controller<M, N>` | A controller: members `M`, packet table `N`. |
| `Component<T, I>` | A component class with members `T` on instances of class `I`. |
| `ComponentInstance<T, I>` | `self` inside component methods. |
| `Packet<T>`, `PacketDef<T>` | A packet and its definition. |
| `ServerNet<N>`, `ClientNet<N>` | A packet table as each side sees it. |
| `Middleware<T>`, `RateLimitConfig` | Packet checks. |
| `Decorator<Self>`, `AnyDecorator` | Decorators. |
| `Debugger`, `LogLevel` | Logging. |
| `LoomConfig` | The configuration module's shape. |
| `TrafficConfig`, `StrikesConfig`, `Violation` | `LoomConfig.Security` parts and what `OnViolation` receives. |
| `QuickNet` | The data type table, `Loom.Util.QuickNet`. |
| `Signal<T...>`, `Connection`, `Trove`, `Promise`, `TypedPromise<T...>` | Vendor types. |

## License

MIT
