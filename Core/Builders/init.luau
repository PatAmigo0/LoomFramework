--!strict

local BasicManagerBuilder = require(script.__sys__)

local Builders = { ManagerBuilder = BasicManagerBuilder.ManagerBuilder }

return table.freeze(Builders)
