--!strict

local LoomRoot = script.Parent.Parent
local Logger = require(LoomRoot.roblox_packages.typed_logger)

export type Logger = Logger.Logger

return table.freeze(Logger)
