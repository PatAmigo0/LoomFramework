--!strict

local Types = require(script.Parent.Parent.Types)

--- Runs the method in a new thread and returns right away, so a yielding method never blocks its caller
--- (for example a signal or packet handler that waits). The method's results are discarded.
local Spawn: Types.AnyDecorator = function(self, callback, ...)
	task.spawn(callback, self, ...)
	return
end

return Spawn
