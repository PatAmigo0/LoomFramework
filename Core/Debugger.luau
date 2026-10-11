--!strict
--[[
	Loom's logger. Every service, controller and component instance gets one as `self.Debugger`, named after its
	owner; `Loom.Util.Debugger.new(name)` makes one for anything else.

	    self.Debugger:Debug("spawned %d blocks", count)
	    --> [Debug] LuckyBlockService:SpawnAll: spawned 3 blocks

	Each line names the function that logged. When there are extra arguments the message is a `string.format`
	pattern, and it's only formatted when the level is on, so a log that's off costs one method call. Luau's `%s`
	takes only strings and numbers; use `%*` for any other value (tables, nil, booleans, Instances). A pattern that
	doesn't fit its arguments is printed as is with the reason, so a bad log never throws. A message without
	arguments is printed as is, `%` included.

	Levels, lowest first: Trace, Debug, Info, Warn, Error, None. They're set in `LoomConfig.Log` (see
	Types.LoomConfig): a default level, and overrides by service/controller Name or component Tag. Trace, Debug and
	Info print; Warn and Error warn, and Error adds a traceback. None of them throw.
]]

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Config = require(script.Parent.Config)

type Level = Types.LogLevel

local LEVELS: { [Level]: number } = {
	Trace = 1,
	Debug = 2,
	Info = 3,
	Warn = 4,
	Error = 5,
	None = 6,
}
table.freeze(LEVELS)
local TRACE, DEBUG, INFO, WARN, ERROR = 1, 2, 3, 4, 5

type Object = {
	Name: string,
	_instance: Instance?,
	_level: number,
}

-- Writes one line. Only called once the level check has passed, so the work here never runs for a log that's off.
-- Stack level 3 is the function that called Debug/Info/...: 1 is `emit`, 2 is the level method.
local function emit(self: Object, label: string, message: string, ...: unknown): string
	local caller = debug.info(3, "n")
	local instance = self._instance
	local owner = if instance then `{self.Name}[{instance.Name}]` else self.Name
	local where = if caller and caller ~= "" then `{owner}:{caller}` else owner
	local text = message
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, message, ...)
		text = if ok then formatted else `{message} (couldn't format: {formatted})`
	end
	return `[{label}] {where}: {text}`
end

local Debugger = {}
Debugger.__index = Debugger

function Debugger.Trace(self: Object, message: string, ...: unknown)
	if self._level <= TRACE then
		print(emit(self, "Trace", message, ...))
	end
end

function Debugger.Debug(self: Object, message: string, ...: unknown)
	if self._level <= DEBUG then
		print(emit(self, "Debug", message, ...))
	end
end

function Debugger.Info(self: Object, message: string, ...: unknown)
	if self._level <= INFO then
		print(emit(self, "Info", message, ...))
	end
end

function Debugger.Warn(self: Object, message: string, ...: unknown)
	if self._level <= WARN then
		warn(emit(self, "Warn", message, ...))
	end
end

function Debugger.Error(self: Object, message: string, ...: unknown)
	if self._level <= ERROR then
		warn(debug.traceback(emit(self, "Error", message, ...), 2))
	end
end

function Debugger.IsEnabled(self: Object, level: Level): boolean
	return self._level <= LEVELS[level]
end

table.freeze(Debugger)

--- A debugger named `name`. Its level comes from `LoomConfig.Log.Overrides[name]`, or `LoomConfig.Log.Level`.
--- `instance` is for component instances: its name is shown next to `name` (read when a line is written, so
--- renames show up), and the level still comes from `name`, the component's Tag.
local function new(name: string, instance: Instance?): Types.Debugger
	if type(name) ~= "string" then
		error("Debugger.new expects a name", 2)
	end
	local log = Config.get().Log
	local object: Object = {
		Name = name,
		_instance = instance,
		_level = LEVELS[log.Overrides[name] or log.Level],
	}
	return (setmetatable(object, Debugger) :: unknown) :: Types.Debugger
end

return table.freeze({
	new = new,
})
