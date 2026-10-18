--!strict
-- QuickNet isn't listed here: Core/Net loads it the first time it's needed (see there). It's a copy of
-- breadboardengineer1234/QuickNet v0.4.0 (commit edba9a2), because Wally only has 0.3.5. The one change is marked
-- "Loom patch" in QuickNet/Parser.luau.

local Promise = require(script.Promise)
local Sift = require(script.Sift)
local Signal = require(script.Signal)
local Component = require(script.Component)
local Trove = require(script.Trove)

local Vendors = {
	Promise = Promise,
	Sift = Sift,
	Signal = Signal,
	Component = Component,
	Trove = Trove,
}

return table.freeze(Vendors)
