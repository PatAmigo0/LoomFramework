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

type Builder = () -> unknown

local Schema = {}

--- Turns a schema (a ByteNet data type, or a builder from this module) into a ByteNet data type.
function Schema.resolve(schema: unknown): unknown
	if type(schema) == "function" then
		return (schema :: Builder)()
	end
	return schema
end

function Schema.sortedKeys(dictionary: { [string]: unknown }): { string }
	local keys = {}
	for key in dictionary do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- At runtime a schema is a ByteNet serializer (or a builder of one), but its type is the value it carries;
-- ByteNet's own types work the same way. The `(builder :: unknown) :: T` casts below are where that is bridged.

local function struct<T>(format: T): T
	local fields = format :: { [string]: unknown }

	local function build(): unknown
		local resolved = {}
		for _, key in Schema.sortedKeys(fields) do
			resolved[key] = Schema.resolve(fields[key])
		end
		return ByteNet.struct(resolved)
	end

	return (build :: unknown) :: T
end

local function array<T>(value: T): { T }
	local function build(): unknown
		return ByteNet.array(Schema.resolve(value))
	end

	return (build :: unknown) :: { T }
end

local function optional<T>(value: T): T?
	local function build(): unknown
		return ByteNet.optional(Schema.resolve(value))
	end

	return (build :: unknown) :: T?
end

local function map<K, V>(key: K, value: V): { [K]: V }
	local function build(): unknown
		return ByteNet.map(Schema.resolve(key), Schema.resolve(value))
	end

	return (build :: unknown) :: { [K]: V }
end

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

-- A cast, not an annotation: the new solver (luau-lsp 1.66) rejects `optional` against the identical field type
-- ("expected '<T>(T) -> T?', got '<T>(T) -> T?'"). The cast is still checked, just more leniently.
Schema.ByteNet = LazyByteNet :: Types.ByteNet

return table.freeze(Schema)
