--!strict

local BasicManagerBuilder = require(script.BasicManagerBuilder)

local SystemCoreBuilders = {
	ManagerBuilder = BasicManagerBuilder,
}

return table.freeze(SystemCoreBuilders)
