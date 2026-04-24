--!strict

local ByteNet = require(script.ByteNet)
local Promise = require(script.Promise)
local Logger = require(script.Logger)
local Sift = require(script.Sift)
local Signal = require(script.Signal)
local Component = require(script.Component)
local Trove = require(script.Trove)

local Vendors = {
	ByteNet = ByteNet,
	Promise = Promise,
	Logger = Logger,
	Sift = Sift,
	Signal = Signal,
	Component = Component,
	Trove = Trove,
}

return table.freeze(Vendors)
