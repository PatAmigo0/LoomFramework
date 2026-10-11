--!strict
--[[
	Server-side protection from `LoomConfig.Security` (see Types.LoomConfig).

	Net reports every packet its checks drop, and skips packets from blocked players. `Security.start` (from
	`Loom.Spin`) also listens on ByteNet's two remotes, next to ByteNet's own listener, for the traffic budget and
	for calls that aren't ByteNet buffers. That listener runs after ByteNet's, so the call that crosses the budget is
	still decoded; the block applies from the next one.

	Every violation goes to `OnViolation` and counts as a strike. `Strikes.Limit` strikes within `Strikes.Window`
	seconds kick the player or block their packets for `BlockTime` seconds.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Config = require(script.Parent.Config)
local Debugger = require(script.Parent.Debugger)

--#region TYPES
type Violation = Types.Violation

-- A player's counts in the current window.
type Window = { start: number, count: number, bytes: number, over: boolean }
--#endregion

--#region STATE
-- Player -> os.clock() when their block ends. Blocked players' packets are dropped before any check runs.
local blockedUntil: { [Player]: number } = {}
local strikeWindows: { [Player]: Window } = {}
local trafficWindows: { [Player]: Window } = {}

local log: Types.Debugger? = nil
local started = false
--#endregion

--#region LOCAL
local function logger(): Types.Debugger
	local current = log
	if current then
		return current
	end
	local created = Debugger.new("Loom")
	log = created
	return created
end

-- `windows[player]`, restarted if `length` seconds have passed since it began.
local function windowFor(windows: { [Player]: Window }, player: Player, length: number, now: number): Window
	local window = windows[player]
	if not window or now - window.start >= length then
		window = { start = now, count = 0, bytes = 0, over = false }
		windows[player] = window
	end
	return window
end

local function block(player: Player, untilTime: number)
	blockedUntil[player] = math.max(blockedUntil[player] or 0, untilTime)
end

local function strike(player: Player)
	local strikes = Config.get().Security.Strikes
	if not strikes then
		return
	end
	local now = os.clock()
	local window = windowFor(strikeWindows, player, strikes.Window, now)
	window.count += 1
	if window.count < strikes.Limit then
		return
	end

	strikeWindows[player] = nil
	if strikes.Action == "Kick" then
		logger():Warn("Kicking %s: %d violations in %*s", player.Name, strikes.Limit, strikes.Window)
		player:Kick(strikes.KickMessage)
	else
		local seconds = strikes.BlockTime :: number
		logger():Warn("Blocking %s for %*s: %d violations in %*s", player.Name, seconds, strikes.Limit, strikes.Window)
		block(player, now + seconds)
	end
end

local function report(player: Player, violation: Violation)
	local onViolation = Config.get().Security.OnViolation
	if onViolation then
		-- Its own thread, so an error or a yield in the game's callback can't stop Loom's handling.
		task.spawn(onViolation, player, violation)
	end
	strike(player)
end

-- Runs for every call to ByteNet's remotes, after ByteNet's own listener.
local function onRemoteCall(player: Player, data: unknown, references: unknown)
	if typeof(data) ~= "buffer" then
		report(player, { Kind = "Payload", Reason = `sent a {typeof(data)} instead of a buffer` })
		return
	elseif references ~= nil and type(references) ~= "table" then
		report(player, { Kind = "Payload", Reason = `sent a {typeof(references)} as the reference list` })
		return
	end

	local traffic = Config.get().Security.Traffic
	if not traffic then
		return
	end
	local window = windowFor(trafficWindows, player, traffic.Window, os.clock())
	window.count += 1
	window.bytes += buffer.len(data :: buffer)
	if window.over then
		return
	end

	local calls, bytes = traffic.Calls, traffic.Bytes
	local reason: string? = nil
	if calls and window.count > calls then
		reason = `over {calls} calls in {traffic.Window}s`
	elseif bytes and window.bytes > bytes then
		reason = `over {bytes} bytes in {traffic.Window}s`
	end
	if reason then
		window.over = true
		block(player, window.start + traffic.Window)
		logger():Warn("Dropping %s's packets until the traffic window ends: %s", player.Name, reason)
		report(player, { Kind = "Traffic", Reason = reason })
	end
end
--#endregion

--#region API
local Security = {}

--- Reports a packet that a check dropped.
function Security.Dropped(player: Player, packet: string, reason: string)
	report(player, { Kind = "Drop", Packet = packet, Reason = reason })
end

--- Whether the player's packets are being dropped (over the traffic budget, or blocked by `Strikes`).
function Security.IsBlocked(player: Player): boolean
	local untilTime = blockedUntil[player]
	if not untilTime then
		return false
	elseif os.clock() >= untilTime then
		blockedUntil[player] = nil
		return false
	end
	return true
end

--- Starts watching ByteNet's remotes if any of `Traffic`, `Strikes` or `OnViolation` is set. Server only; once.
function Security.Start()
	if started or not RunService:IsServer() then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player)
		blockedUntil[player] = nil
		strikeWindows[player] = nil
		trafficWindows[player] = nil
	end)

	local security = Config.get().Security
	if not (security.Traffic or security.Strikes or security.OnViolation) then
		return
	end
	-- ByteNet creates these when it's first required, which Loom does while loading.
	for _, name in { "ByteNetReliable", "ByteNetUnreliable" } do
		local remote = ReplicatedStorage:FindFirstChild(name)
		local event = if remote and remote:IsA("RemoteEvent")
			then remote.OnServerEvent
			elseif remote and remote:IsA("UnreliableRemoteEvent") then remote.OnServerEvent
			else nil
		if event then
			event:Connect(onRemoteCall)
		else
			logger():Error("ReplicatedStorage.%s is missing; Loom can't watch its traffic", name)
		end
	end
end
--#endregion

return table.freeze(Security)
