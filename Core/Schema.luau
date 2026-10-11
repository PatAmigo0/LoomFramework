--!strict
--[[
	`Loom.Util.ByteNet`: ByteNet's data types, with lazy composites.

	ByteNet only lets you create a struct inside `defineNamespace`, but Loom schemas are written at module top
	level. So struct/array/optional/map return a builder, and `Schema.resolve` builds the whole tree once the
	namespace exists (see Core/Net). Builders resolve their children, so composites nest freely.

	Struct creation order must be identical on server and client (ByteNet numbers structs by it), which is why
	fields are always resolved in sorted key order.
]]

local LoomRoot = script.Parent.Parent
local Types = require(LoomRoot.Types)
local ByteNet = require(LoomRoot.Vendors.ByteNet)

--#region TYPES
type Builder = () -> unknown
--#endregion

--#region LOCAL
-- Turns a schema (a ByteNet data type, or a builder from this module) into a ByteNet data type.
local function resolve(schema: unknown): unknown
	if type(schema) == "function" then
		return (schema :: Builder)()
	end
	return schema
end

-- The dictionary's keys, sorted.
local function sortedKeys(dictionary: { [string]: unknown }): { string }
	local keys = {}
	for key in dictionary do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- At runtime a schema is a ByteNet serializer (or a builder of one), but its type is the value it carries, the
-- same as ByteNet's own types. The `(build :: unknown) :: T` casts below bridge the two.

local function struct<T>(format: T): T
	local fields = format :: { [string]: unknown }

	local function build(): unknown
		local resolved = {}
		for _, key in sortedKeys(fields) do
			resolved[key] = resolve(fields[key])
		end
		return ByteNet.struct(resolved)
	end

	return (build :: unknown) :: T
end

local function array<T>(value: T): { T }
	local function build(): unknown
		return ByteNet.array(resolve(value))
	end

	return (build :: unknown) :: { T }
end

local function optional<T>(value: T): T?
	local function build(): unknown
		return ByteNet.optional(resolve(value))
	end

	return (build :: unknown) :: T?
end

local function map<K, V>(key: K, value: V): { [K]: V }
	local function build(): unknown
		return ByteNet.map(resolve(key), resolve(value))
	end

	return (build :: unknown) :: { [K]: V }
end

--#endregion

--#region API
local LazyByteNet = {
	struct = struct,
	array = array,
	optional = optional,
	map = map,

	bool = ByteNet.bool,
	string = ByteNet.string,
	buff = ByteNet.buff,
	inst = ByteNet.inst,
	cframe = ByteNet.cframe,
	vec2 = ByteNet.vec2,
	vec3 = ByteNet.vec3,

	uint8 = ByteNet.uint8,
	uint16 = ByteNet.uint16,
	uint32 = ByteNet.uint32,
	int8 = ByteNet.int8,
	int16 = ByteNet.int16,
	int32 = ByteNet.int32,
	float32 = ByteNet.float32,
	float64 = ByteNet.float64,

	nothing = ByteNet.nothing,
	unknown = ByteNet.unknown,
}
table.freeze(LazyByteNet)

local Schema = {}

--- Turns a schema into a ByteNet data type. Call inside `ByteNet.defineNamespace`.
Schema.resolve = resolve
--- A dictionary's keys, sorted.
Schema.sortedKeys = sortedKeys
-- A cast, not an annotation: the new solver (luau-lsp 1.66) rejects `optional` against the identical field type
-- ("expected '<T>(T) -> T?', got '<T>(T) -> T?'").
Schema.ByteNet = LazyByteNet :: Types.ByteNet
--#endregion

return table.freeze(Schema)
