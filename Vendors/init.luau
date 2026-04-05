--!strict

local ByteNet = require(script.ByteNet)
local Promise = require(script.Promise)
local Logger = require(script.Logger)
local Sift = require(script.Sift)

local Vendors = {
	ByteNet = ByteNet,
	Promise = Promise,
	Logger = Logger,
	Sift = Sift,
}

return table.freeze(Vendors)
