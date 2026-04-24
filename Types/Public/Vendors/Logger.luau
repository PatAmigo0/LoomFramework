--!strict

local LoomRoot = script.Parent.Parent.Parent.Parent
local Logger = require(LoomRoot.Vendors.Logger) -- <script> -> Utils -> Public -> Types -> Loom -> Vendors -> ...

export type Logger = Logger.Logger
export type LogItem = Logger.LogItem

return nil
