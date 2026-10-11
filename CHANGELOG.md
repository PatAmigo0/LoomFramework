# Changelog

## 0.5.1 (2026-10-11)

No behaviour changes. Comments say what each function does, and the core modules are split into `--#region` blocks (TYPES, STATE, LOCAL, API; Config also has DEFAULTS) so the helpers fold away. `Types` uses one region per section.

## 0.5.0 (2026-10-11)

Breaking: `self.Debugger` is Loom's own logger now (`Debugger:Log` becomes `Debugger:Debug`, and `Loom.Util.Logger` becomes `Loom.Util.Debugger`). Everything else is additive: LoomConfig, side-specific packet types, component lifecycle fixes and runtime checks.

### Breaking: Loom's own Debugger replaces typed_logger

`self.Debugger` used to be one sleitnick Log item, created when the service or component was. That had three problems. Its modifiers stuck: `Throw()`, `Every(n)` and `AtMostEvery(n)` change the item and return it, so a single `self.Debugger:AtMostEvery(1):Log(...)` throttled every later log from that service, and `:Throw()` made every later log throw. Every line reported the traceback from where the item was made, not where it was logged. And without a sleitnick `LogConfig` module the level was Debug everywhere, so live servers printed every debug line and, outside Studio, sent each one to `AnalyticsService:FireLogEvent`.

`Core/Debugger.luau` is a small logger written for Loom:

- `Trace`, `Debug`, `Info`, `Warn` and `Error` (Error adds a traceback; none of them throw). `IsEnabled(level)` lets you skip work that only feeds a log.
- Each line names its owner and the function that logged: `[Debug] DuelService:_startDuel: ...`. Component lines show the instance too: `DuelPad[Pad1]:LoomInit`. The function name is looked up only for lines that get written.
- With extra arguments the message is a `string.format` pattern, formatted only when the level is on, so a log that's off costs one method call and builds no string. Use `%*` for values that aren't strings or numbers. A pattern that doesn't fit its arguments is printed with the reason instead of throwing.
- Levels come from `LoomConfig.Log` (below): `Level` (default Debug in Studio, Warn in live games) and `Overrides` by service/controller Name or component Tag. Loom's own messages use the name "Loom".

Migrating: `self.Debugger:Log(msg)` becomes `self.Debugger:Debug(msg)`. `Loom.Util.Logger` is gone; use `Loom.Util.Debugger.new(name)`. `Types.Logger` and `Types.LogItem` are replaced by `Types.Debugger` and `Types.LogLevel`. Loom no longer depends on typed_logger.

### LoomConfig

An optional `ReplicatedStorage.LoomConfig` module now holds Loom's settings; `Types.LoomConfig` documents each field and its default. It's a module, so branch on `RunService:IsStudio()` for different test and live values. Loom reads it the first time it needs a value rather than when it loads, so the config can require Loom. Unknown keys and wrong types are errors, so a typo can't silently leave a setting at its default. Without the module, or for any field it leaves out, Loom uses the defaults in the `DEFAULTS` table at the top of `Core/Config.luau`, so a game only writes what it wants to change.

- `Log.Level`, `Log.Overrides`: see the Debugger above.
- `Net.RateLimit = { Requests = n, Window = seconds }`: a per-player limit on every client -> server packet. Off by default. A packet can set its own with the new `RateLimit` field on `Loom.Packet`, or turn the default off with `RateLimit = false`.
- `Net.Middleware`: checks that run on every client -> server packet, before each packet's own `Middleware`.
- `Net.LogDrops`: warn about each packet a rate limit or middleware drops, naming the packet, the player and the check. Off by default.
- `Net.NamespaceTimeout` (was a constant 30) and `Spin.SlowInitWarning` (10).

On the server a packet's checks run in this order: its rate limit, `LoomConfig.Net.Middleware`, its own `Middleware`. They're built once, when the packet is connected at `Loom.Spin`.

`Middleware.RateLimit` keeps its counters in a strong table cleared on `PlayerRemoving`, instead of a weak table keyed by Player, so a limit never depends on when the garbage collector drops Instance keys. It also reuses each player's record instead of allocating a new one every window, and checks its arguments.

### Components

- An instance removed before it started never got `LoomDestroy`, and its Trove was never cleaned. The Component library constructs and starts an instance in separate deferred steps, and only stops instances that started. Loom now checks right after the start step would have run and finishes such instances itself. `LoomDestroy` and the Trove clean-up run at most once per instance either way, and the Trove is cleaned even if `LoomDestroy` throws.
- If `LoomInit` throws, the instance's Trove is cleaned before the error goes on, so connections made before the error don't outlive it.
- `Decorators` used to be marked applied before they were applied. A bad entry failed the first instance and left every later one running with some or none of its decorators, silently. Every decorated method is now worked out before any is replaced, and a bad entry fails every instance with the same error, prefixed with the Tag.
- `"*"` decorators skip `HeartbeatUpdate`, `SteppedUpdate` and `RenderSteppedUpdate`, so a `"*"` Cooldown or Once no longer throttles or stops per-frame updates. Name them in `Decorators` to decorate them on purpose. Named entries wrap their method first and `"*"` wraps the result.

### Checks

These catch mistakes the type checker sees in strict code but not in nonstrict files or behind casts, with errors pointing at your call:

- `Loom.Packet` requires a `Schema`, a `ReliabilityType` of `"reliable"` or `"unreliable"` (ByteNet quietly treats any other value, `"Reliable"` included, as unreliable), and `Middleware` as a list of functions. These used to fail at `Loom.Spin`, or on every incoming packet.
- `listen` requires a function; it used to fail when a packet arrived.
- `Loom.Define` requires string `Net` keys.
- `Loom.Decorate`, component `Decorators` and `Compose` require lists of functions.
- `Cooldown` checks its arguments, and a `keyOf` that returns nil no longer errors ("table index is nil").
- `Safe` no longer throws from its own error report when `self` isn't a table.
- `IsPlayer` ignores calls whose first argument isn't an Instance.
- `Loom.Spin` warns, naming the services, when a `LoomInit` is still running after 10 seconds (`LoomConfig.Spin.SlowInitWarning`), since nothing starts until every init returns.

### Packets

- Services and controllers see different halves of each packet. `Service.Net` uses `ServerNet<N>` (no `send`) and `Controller.Net` uses `ClientNet<N>` (only `send`, `listen` and `wait`), so autocomplete offers only what works on that side and a wrong-side call is a type error. A `PacketView` type function builds both views from the one shared `Net` type. The runtime error stubs stay as a backstop.
- `Middleware.IsAlive` and `Middleware.RateLimit(...)` take `(player, data)`. As one-parameter functions they made the solver put an error type into the payload type of any packet that used them (`Packet<*error-type* | number>`), which left that packet's `data` partly unchecked. Write your own middleware with both parameters too.

## 0.4.0 (2026-10-11)

This release rewrites Loom's types for Luau's new type solver and reshapes the API around them. Services, controllers and components get a typed `self`, typed packets and inferred payloads without any `:: any` in game code, and a service takes one line to set up instead of two passes.

It breaks the 0.3 API. The migration guide at the bottom shows each change side by side.

### Requires the new type solver

Loom's types use `read` properties and other things the old solver rejects, so 0.4 needs `LuauSolverV2`: `fflags.enable_new_solver` in Zed's Luau extension, `luau-lsp.fflags.enableNewSolver` in VS Code, or `--flag:LuauSolverV2=true` for `luau-lsp analyze`. Roblox's FFlag sync doesn't turn it on for you.

0.3 passed the old solver mostly because `:: any` switched checking off. Under the new solver the same project produced about 100 errors, and nearly all of them traced back to three patterns in Loom's own types.

### Why the 0.3 types failed

**Generic inference through intersections.** `Weave<T, N>(schema: LoomSchema<T, N>)` asked the solver to pull `T` back out of `T & {...}`, which it can't do, so every `Loom.Weave` and `Loom.Component` call failed with "No valid instantiation could be inferred". 0.4 uses identity generics (`<S>(service: S): S`).

**Optional lifecycle hooks.** `function MyService:LoomInit()` only gets a typed `self` when the field is a non-optional function. Declared as `((self: X) -> ())?`, the solver infers `self` from how the body uses it, as a read-only shape; `self.Count += 1` then fails as "read-only" and `self.Debugger:Log(...)` mismatches typed_logger's signature. Hooks are declared non-optional now. Loom still skips the ones you don't write.

**ByteNet types that threw information away.** Loom's `ByteNetLib` typed `ByteNet.struct` as returning `dataTypeInterface<any>`, which is why every schema needed `:: Types.ByteNetInterface<...>`. ByteNet's own types are phantom types: `ByteNet.uint8` is typed `number` and `struct` is `<T>(format: T) -> T`. 0.4 goes back to that, so `ByteNet.struct({ hp = ByteNet.uint8 })` is `{ hp: number }` and `Loom.Packet` infers `Packet<{ hp: number }>` on its own.

### API

Added or changed:

- `Loom.Weave(definition)` registers right away and returns the same table, typed. Call it on the first line of the module, define methods on what it returns, and return that.
- `Loom.Component(definition)` creates the class immediately and returns it, so methods go on the class. Decorators are applied when the first instance is constructed, which is always after the module has finished.
- `Loom.Decorate(target, "method", ...)` decorates a method you already defined, on a service, controller or component. `keyof` checks the method name, so a typo is a type error that lists the valid names.
- `Loom.Define` takes any table with a `Name` and returns it typed exactly as written; `typeof(Def.Net)` is the Net type. At runtime it checks that every `Net` entry came from `Loom.Packet`, and freezes `Net`.
- `Loom.Packet` returns the real packet object at once. `listen` and `wait` work immediately; the send functions start working at `Loom.Spin()` and raise a clear error before that.
- `packet.listen` returns a `Connection`. Add it to a Trove or call `:Disconnect()`.

Removed:

- `Loom.Unseal`. It was an `any` cast; the API module hands out typed tables instead.
- `Loom.Resolve`. Use `API.MyService`, which is the very table the registry holds.
- `Loom.VerifyNetSchema`, since `Loom.Define` validates `Net` now, and `Loom.Define`'s second `net` argument.
- `Loom.Enums.Network` and `Loom.Enums.LoomType`, which nothing used.
- `PacketDef.CallbackBehavior`. ByteNet 0.4.6 declares `callbackBehavior` in its types and never reads it, so the option did nothing. `PacketDef.RateLimit` was never read either; use `Middleware.RateLimit`.
- `Decorators.TimeoutDebounce`, renamed to `Cooldown`. It keeps its own state now instead of reading `self._lastTouched`.

### Types

There's one public module, `Loom.Types`. In 0.3 a type such as `LogItem` went through up to five re-export files (`Vendors/Logger`, `Types/Public/Vendors/Logger`, `Types/Public/Vendors/init`, `Types/Public/init`, `Types/init`), and the Public and Private folders overlapped. Now each public type is written once. Types only Loom needs are plain `type` declarations inside the module that uses them, so game code can't import them.

- `Service<M, N>` and `Controller<M, N>` replace `LoomSchema` + `LoomClass`: one type per service.
- `Component<T, I>` describes the definition and the class together (config, hooks, your methods, `Started`, `GetAll`...), and `ComponentInstance<T, I>` is `self`.
- `Decorator<Self>` and `AnyDecorator`. Built-ins that never look at `self` are `AnyDecorator`, so they fit any method. `CanCall` takes `Self` from its predicate, or from where you use it, so `CanCall(function(self) return self._state == "unlocked" end)` needs no annotation inside a `Decorators` table.
- `Middleware<T>`, `PacketDef<T>`, `Packet<T>` (read-only members), the phantom `ByteNet` type, `ComponentExtension<Self>` and `ComponentUtil`.
- `GetComponent` returns the other component's instance type instead of `any`.

`any` remains in two deliberate spots. Decorators forward method arguments as `...any`, because a predicate typed `(self, part: BasePart) -> boolean` can't be passed where `(...unknown) -> boolean` is expected; `unknown` there would claim the predicate accepts anything. And `Core/Decorate` keeps its list of decorators type-erased. Everywhere else, data of unknown shape is `unknown`, which you have to narrow or cast before using.

### Fixes

Networking:

- Middleware ran once per listener, so with two `listen` calls `RateLimit` counted every packet twice. Each packet now has a single ByteNet listener that runs the middleware once.
- `packet.wait()` skipped middleware completely. It goes through the same dispatcher now.
- A `ByteNet.struct` inside `array`, `optional`, `map` or another struct crashed at startup. ByteNet's composites read `.read` and `.write` from their argument straight away, and 0.3 handed them a lazy function. Every composite is lazy now and builds its children first.
- Struct creation order followed table iteration order. ByteNet numbers structs by creation order and the client assumes it matches the server, so packets and struct fields now build in sorted key order on both sides.
- A client could crash with "attempt to index nil" if a namespace hadn't replicated yet, because ByteNet looks it up with `FindFirstChild`. Loom waits up to 30 seconds and names the namespace if it never arrives.
- Calling a packet function on the wrong side failed silently: ByteNet's guard never fires, since its `__index` treats the table argument as the key. Loom installs error stubs for `sendTo*` on the client and `send` on the server.
- Every `RateLimit(...)` shared one counter table, so limits on different packets added up. Each call gets its own counters.

Decorators:

- Decorated methods returned `nil`. `CanCall`, `Debounce`, `IsBusy`, `IsPlayer` and `TimeoutDebounce` called the method and dropped its results.
- `IsPlayer()` and `IsPlayer(false)` never called the method; the only call sat inside `if shouldBeAlive then`.
- `IsPlayer` treated Models as parts. `typeof(part) == "Model"` is always false, since `typeof` returns `"Instance"`; it uses `IsA("Model")` now.
- `Debounce` locked per object instead of per method, so one debounced method blocked the others on the same object, and an error inside it kept the lock forever.

Lifecycle and packaging:

- Spin stopped waiting for `LoomInit`s after the first failure (0.3 used `Promise.all`, which rejects early), so `LoomStart` could begin while other inits were still yielding. 0.4 waits for every init, logs failures, and only skips `LoomStart` for the services that failed.
- Inits run in `Priority` order as well, with `Name` as the tiebreak, so startup order is the same every run.
- `pesde.toml` left `Decorators/` out of the package, so the published version failed on `require(script.Decorators)`.

### New decorators

- `Once` runs a method a single time per object.
- `Spawn` runs it in a new thread so the caller never waits on a yield.
- `Safe` catches errors and warns with a traceback instead of throwing.
- `Profile(label)` puts every call under a MicroProfiler label.
- `Cooldown(seconds, keyOf?)` throttles per object, or per key such as the player.
- `Compose(...)` bundles several decorators into one you can reuse.

### Performance

Server sends (`sendToAll`, `sendTo`, `sendToList`, `sendToAllExcept`) are ByteNet's own functions with no wrapper around them; 0.3 put a metatable proxy in front of every packet. A packet with one listener calls it directly on ByteNet's listener thread, and only several listeners get a `task.spawn` each. Client `send` has one thin wrapper because ByteNet's `send(data, target?)` signature doesn't match `Packet<T>`.

### Solver limits worth knowing (luau-lsp 1.66)

- Annotate a method parameter whose type is a component instance or a service, as in `function DuelPad:_activate(player, hitbox: API.HitboxInstance)`. The solver doesn't carry an intersection type into an unannotated parameter, and what it infers instead won't match.
- `table.freeze(t)` returns a read-only type. If the table has to match a type with writable fields, annotate it and call `table.freeze(t)` as a statement.
- Give weak tables their type on the inner table: `setmetatable({} :: { [K]: V }, { __mode = "k" })`.
- StyLua 2.4.1 rewrites explicit generic calls `f<<T>>(x)` into `f << T >> x`, which breaks them, so Loom doesn't use that syntax.

### Migration from 0.3

Schema with networking:

```lua
-- 0.3
export type ClientType = { DuelState: Types.Packet<DuelStateData> }
local NetSchema: ClientType = {
	DuelState = Loom.Packet({
		Schema = ByteNet.struct({ state = ByteNet.int8 }) :: Types.ByteNetInterface<DuelStateData>,
	}),
}
return Loom.Define({ Name = "DuelService", Net = NetSchema })

-- 0.4
return Loom.Define({
	Name = "DuelService",
	Net = {
		DuelState = Loom.Packet({ Schema = ByteNet.struct({ state = ByteNet.int8 }) }),
	},
})
```

A service without networking doesn't need a shared schema at all; define it where its type lives:

```lua
LuckyBlockService = Loom.Define({ Name = "LuckyBlockService" }) :: LuckyBlockService,
```

The service type, in the API module:

```lua
-- 0.3
type GameServiceType = { A: (self: GameServiceClass) -> () }
type GameServiceClientType = GameServiceDef.ClientType
export type GameServiceClass = Types.LoomClass<GameServiceType, GameServiceClientType>
export type GameService = Types.LoomSchema<GameServiceType, GameServiceClientType>

-- 0.4
export type GameService = Types.Service<{
	A: (self: GameService) -> (),
}, typeof(GameServiceDef.Net)>

return { GameService = GameServiceDef :: GameService }
```

The service module:

```lua
-- 0.3
local GameService = Loom.Unseal(API.GameService) :: API.GameService
function GameService:LoomStart() end
return Loom.Weave(GameService)

-- 0.4
local GameService = Loom.Weave(API.GameService)
function GameService:LoomStart() end
return GameService
```

A component:

```lua
-- 0.3
local Pad = ({ Tag = "DuelPad", Decorators = { ... } } :: any) :: Types.ComponentSchema<DuelPad, Model>
function Pad:LoomInit() end
return Loom.Component(Pad)

-- 0.4
local Pad = Loom.Component({ Tag = "DuelPad", Decorators = { ... } } :: API.DuelPadComponent)
function Pad:LoomInit() end
return Pad
```

Everything else:

- `Loom.Resolve("X") :: API.X` becomes `API.X`.
- Remove `Loom.VerifyNetSchema(...)` and `CallbackBehavior`.
- Rename `Decorators.TimeoutDebounce(t)` to `Decorators.Cooldown(t)`, and drop the `_lastTouched` field it needed.
- Import public types with `require(Shared.Loom.Types)`; the type names changed as listed under Types.
