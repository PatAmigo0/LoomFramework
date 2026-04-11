--!strict

local LoomRoot = script.Parent.Parent
local Logger = require(LoomRoot.roblox_packages.typed_logger)

export type Logger = Logger.Logger
export type LogItem = Logger.LogItem

return table.freeze(Logger)
