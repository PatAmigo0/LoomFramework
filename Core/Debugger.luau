--!strict
-- The `Debugger` every service, controller and component instance gets: a debug-level logger tagged with its name.

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local Logger = require(LoomRoot.Vendors.Logger)

-- typed_logger has no public way to name a logger, so set the field sleitnick's Log reads.
type NamedLogger = Types.Logger & { _name: string }

return function(name: string): Types.LogItem
	local logger = Logger.new() :: NamedLogger
	logger._name = name
	return logger:AtDebug()
end
