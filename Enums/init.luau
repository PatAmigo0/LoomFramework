--!strict

local Reliability = table.freeze({
	Reliable = "reliable" :: "reliable",
	Unreliable = "unreliable" :: "unreliable",
})

return table.freeze({
	Reliability = Reliability,
})
