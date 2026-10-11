--!strict

local ByteNet = require(script.ByteNet)
local Promise = require(script.Promise)
local Sift = require(script.Sift)
local Signal = require(script.Signal)
local Component = require(script.Component)
local Trove = require(script.Trove)

local Vendors = {
	ByteNet = ByteNet,
	Promise = Promise,
	Sift = Sift,
	Signal = Signal,
	Component = Component,
	Trove = Trove,
}

return table.freeze(Vendors)
