--!strict
--[[
	`Loom.Util.QuickNet` (QuickNet's data types) and schema checks.

	QuickNet rewrites optional and union schema tables in place when it registers an event, so a schema used by
	two packets would break the second one. Loom gives QuickNet a fresh copy every time.
]]

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local QuickNet = LoomRoot.Vendors.QuickNet
-- Neither module starts QuickNet; only its main module does (see Core/Net).
local DataTypes = require(QuickNet.DataTypes)
local Parser = require(QuickNet.Parser)

--#region LOCAL
-- A deep copy of a schema: tables are copied, data types and custom encoders are kept.
local function copy(schema: unknown): unknown
	if type(schema) ~= "table" then
		return schema
	end
	local result: { [unknown]: unknown } = {}
	for key, value in schema :: { [unknown]: unknown } do
		result[copy(key)] = copy(value)
	end
	return result
end

-- Why QuickNet rejects `schema`, or nil if it accepts it.
local function problem(schema: unknown): string?
	local ok, err = pcall(Parser.getSchema, copy(schema))
	if ok then
		return nil
	end
	local message = tostring(err)
	return string.match(message, "%[QuickNet%] (.*)") or message
end
--#endregion

--#region API
local Schema = {}

Schema.QuickNet = (DataTypes :: unknown) :: Types.QuickNet
--- A copy of the schema for QuickNet to register.
Schema.copy = copy
--- Why QuickNet rejects the schema, or nil if it accepts it.
Schema.problem = problem
--#endregion

return table.freeze(Schema)
