--!strict
--[[
	Loom's settings: the game's optional `ReplicatedStorage.LoomConfig` module (see Types.LoomConfig) on top of
	`DEFAULTS` below. Fields the module leaves out, or all of them if there's no module, keep their default.
	Unknown keys and wrong types are errors.

	The module is read on the first `Config.get()`, so it can require Loom. Don't call `Config.get()` while Loom's
	own modules are loading.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)

--#region TYPES
type Check = (player: Player, data: unknown) -> boolean

export type Resolved = {
	Log: {
		Level: Types.LogLevel,
		Overrides: { [string]: Types.LogLevel },
	},
	Net: {
		RateLimit: Types.RateLimitConfig?,
		Middleware: { Check },
		LogDrops: boolean,
		NamespaceTimeout: number,
	},
	Spin: {
		SlowInitWarning: number,
	},
}

--#endregion

--#region DEFAULTS
local IS_STUDIO = RunService:IsStudio()

local DEFAULTS = table.freeze({
	Log = table.freeze({
		Level = (if IS_STUDIO then "Debug" else "Warn") :: Types.LogLevel,
	}),
	Net = table.freeze({
		RateLimit = nil :: Types.RateLimitConfig?, -- off
		LogDrops = false,
		NamespaceTimeout = 30,
	}),
	Spin = table.freeze({
		SlowInitWarning = 10,
	}),
})

--#endregion

--#region STATE
local LEVELS: { [string]: true } = { Trace = true, Debug = true, Info = true, Warn = true, Error = true, None = true }
table.freeze(LEVELS)

local cached: Resolved? = nil
--#endregion

--#region LOCAL
local function fail(path: string, expected: string, value: unknown): never
	error(`LoomConfig.{path} must be {expected}, got {typeof(value)} {value}`, 0)
end

-- `value` as a table (empty if nil). Errors if it isn't a table or has keys outside `allowed`.
local function section(value: unknown, path: string, allowed: { string }): { [string]: unknown }
	if value == nil then
		return {}
	elseif type(value) ~= "table" then
		return fail(path, "a table", value)
	end
	local fields = value :: { [unknown]: unknown }
	for key in fields do
		if type(key) ~= "string" or not table.find(allowed, key) then
			error(`LoomConfig.{path} has an unknown key '{key}' (known: {table.concat(allowed, ", ")})`, 0)
		end
	end
	return fields :: { [string]: unknown }
end

local function level(value: unknown, path: string): Types.LogLevel
	if type(value) ~= "string" or not LEVELS[value] then
		return fail(path, "one of Trace, Debug, Info, Warn, Error, None", value)
	end
	return value :: Types.LogLevel
end

local function positive(value: unknown, path: string, default: number): number
	if value == nil then
		return default
	elseif type(value) ~= "number" or value <= 0 then
		return fail(path, "a number above 0", value)
	end
	return value
end

local function boolean(value: unknown, path: string, default: boolean): boolean
	if value == nil then
		return default
	elseif type(value) ~= "boolean" then
		return fail(path, "true or false", value)
	end
	return value
end

-- Why `value` isn't a rate limit (`{ Requests = n, Window = seconds }`), or nil if it is one.
local function rateLimitProblem(value: unknown): string?
	if type(value) ~= "table" then
		return `must be false or \{ Requests = n, Window = seconds }, got {typeof(value)} {value}`
	end
	local fields = value :: { [unknown]: unknown }
	for key in fields do
		if key ~= "Requests" and key ~= "Window" then
			return `has an unknown key '{key}' (known: Requests, Window)`
		end
	end
	local requests, window = fields.Requests, fields.Window
	if type(requests) ~= "number" or requests < 1 or requests % 1 ~= 0 then
		return `needs Requests, a whole number of 1 or more; got {requests}`
	elseif type(window) ~= "number" or window <= 0 then
		return `needs Window, a number of seconds above 0; got {window}`
	end
	return nil
end

-- Reads LoomConfig, checks it and fills in the defaults.
local function load(): Resolved
	local module = ReplicatedStorage:FindFirstChild("LoomConfig")
	local raw: unknown = nil
	if module and module:IsA("ModuleScript") then
		raw = (require :: (ModuleScript) -> unknown)(module)
	end

	local root = section(raw, "(root)", { "Log", "Net", "Spin" })
	local log = section(root.Log, "Log", { "Level", "Overrides" })
	local net = section(root.Net, "Net", { "RateLimit", "Middleware", "LogDrops", "NamespaceTimeout" })
	local spin = section(root.Spin, "Spin", { "SlowInitWarning" })

	local overrides: { [string]: Types.LogLevel } = {}
	if log.Overrides ~= nil then
		if type(log.Overrides) ~= "table" then
			fail("Log.Overrides", "a table of name = level", log.Overrides)
		end
		for name, value in log.Overrides :: { [unknown]: unknown } do
			if type(name) ~= "string" then
				fail("Log.Overrides", "keyed by names (strings)", name)
			end
			overrides[name :: string] = level(value, `Log.Overrides.{name}`)
		end
	end

	local middleware: { Check } = {}
	if net.Middleware ~= nil then
		if type(net.Middleware) ~= "table" then
			fail("Net.Middleware", "a list of functions", net.Middleware)
		end
		for i, check in net.Middleware :: { [unknown]: unknown } do
			if type(check) ~= "function" then
				fail(`Net.Middleware[{i}]`, "a function", check)
			end
			table.insert(middleware, check :: Check)
		end
	end

	local rateLimit = if net.RateLimit == nil then DEFAULTS.Net.RateLimit else nil
	if net.RateLimit ~= nil and net.RateLimit ~= false then
		local problem = rateLimitProblem(net.RateLimit)
		if problem then
			error(`LoomConfig.Net.RateLimit {problem}`, 0)
		end
		rateLimit = net.RateLimit :: Types.RateLimitConfig
	end

	local resolved: Resolved = {
		Log = {
			Level = if log.Level == nil then DEFAULTS.Log.Level else level(log.Level, "Log.Level"),
			Overrides = overrides,
		},
		Net = {
			RateLimit = rateLimit,
			Middleware = middleware,
			LogDrops = boolean(net.LogDrops, "Net.LogDrops", DEFAULTS.Net.LogDrops),
			NamespaceTimeout = positive(net.NamespaceTimeout, "Net.NamespaceTimeout", DEFAULTS.Net.NamespaceTimeout),
		},
		Spin = {
			SlowInitWarning = positive(spin.SlowInitWarning, "Spin.SlowInitWarning", DEFAULTS.Spin.SlowInitWarning),
		},
	}
	return resolved
end

--#endregion

--#region API
local Config = {}

--- Why `value` isn't a valid `RateLimit`, or nil if it is one.
Config.rateLimitProblem = rateLimitProblem

--- The checked config with defaults filled in. Read on the first call.
function Config.get(): Resolved
	local current = cached
	if current then
		return current
	end
	local loaded = load()
	cached = loaded
	return loaded
end

--#endregion

return table.freeze(Config)
