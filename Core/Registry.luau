--!strict
--[[
	Woven services (server) / controllers (client) and their lifecycle.

	`Loom.Weave` registers one and gives it its `Debugger` and `Trove`. `Loom.Spin` then:
	  1. connects every `Net`, so any service can use any packet from its `LoomInit`;
	  2. runs every `LoomInit` at the same time (an init may yield) and waits for all of them;
	  3. spawns `LoomStart` for everything that initialized, highest `Priority` first.
	A failure is logged and only takes the failing service out.
]]

local RunService = game:GetService("RunService")

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Logger = require(LoomRoot.Vendors.Logger)
local Promise = require(LoomRoot.Vendors.Promise)
local Trove = require(LoomRoot.Vendors.Trove)
local createDebugger = require(script.Parent.Debugger)
local Net = require(script.Parent.Net)

local KIND = if RunService:IsServer() then "Service" else "Controller"

type Hook = (self: Entry) -> ()

-- The part of a woven table Loom works with; everything else on it belongs to the game.
type Entry = {
	Name: string,
	Priority: number,
	Net: { [string]: unknown }?,
	Debugger: Types.LogItem,
	Trove: Types.Trove,
	LoomInit: Hook?,
	LoomStart: Hook?,
}

local logger = Logger.new()
local entries: { Entry } = {}
local woven: { [string]: true } = {}
local spun = false

local function runHook(entry: Entry, hookName: string, hook: Hook?): boolean
	if not hook then
		return true
	end

	return xpcall(hook, function(err: unknown)
		logger:AtWarning():Log(`{KIND} {entry.Name} failed in {hookName}: {debug.traceback(tostring(err), 2)}`)
	end, entry)
end

local function connectNet(entry: Entry): boolean
	local net = entry.Net
	if not net then
		return true
	end

	local ok, err = pcall(Net.Attach, entry.Name, net)
	if not ok then
		logger:AtWarning():Log(`{KIND} {entry.Name} couldn't connect its Net: {err}`)
	end
	return ok
end

-- Runs every LoomInit in its own thread and yields until all of them have finished.
local function initAll(ready: { Entry }): { [Entry]: boolean }
	local initialized: { [Entry]: boolean } = {}
	local remaining = #ready
	local waiting: thread? = nil

	for _, entry in ready do
		task.spawn(function()
			initialized[entry] = runHook(entry, "LoomInit", entry.LoomInit)
			remaining -= 1
			if remaining == 0 and waiting then
				task.spawn(waiting)
			end
		end)
	end

	if remaining > 0 then
		waiting = coroutine.running()
		coroutine.yield()
	end
	return initialized
end

local function byPriority(a: Entry, b: Entry): boolean
	if a.Priority ~= b.Priority then
		return a.Priority > b.Priority
	end
	return a.Name < b.Name
end

local Registry = {}

function Registry.Weave<S>(service: S): S
	local entry = service :: Entry
	if type(entry) ~= "table" or type(entry.Name) ~= "string" then
		error("Loom.Weave expects a table made with Loom.Define", 3)
	elseif woven[entry.Name] then
		error(`{KIND} {entry.Name} is already woven`, 3)
	elseif spun then
		error(`{KIND} {entry.Name} was woven after Loom.Spin(); require its module before spinning`, 3)
	end

	woven[entry.Name] = true
	entry.Priority = entry.Priority or 0
	entry.Debugger = createDebugger(entry.Name)
	entry.Trove = Trove.new()
	table.insert(entries, entry)

	return service
end

function Registry.Spin(): Types.TypedPromise<()>
	return Promise.new(function(resolve)
		if spun then
			error("Loom.Spin() was already called")
		end
		spun = true
		table.sort(entries, byPriority)

		local ready: { Entry } = {}
		for _, entry in entries do
			if connectNet(entry) then
				table.insert(ready, entry)
			end
		end

		local initialized = initAll(ready)
		for _, entry in ready do
			if initialized[entry] then
				task.spawn(runHook, entry, "LoomStart", entry.LoomStart)
			end
		end

		resolve()
	end)
end

return table.freeze(Registry)
