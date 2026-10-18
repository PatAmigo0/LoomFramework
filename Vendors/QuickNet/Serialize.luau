--!optimize 2

local Players = game:GetService("Players")

local Types = require(script.Parent.Types)
local Enums = require(script.Parent.Enums)

type SchemaArg = Types.SchemaArg
type Literal = Types.Literal

const FX8_SCALE = 10
const FX8_ROT_SCALE = 40.42
const FX16_SCALE = 100
const FX16_ROT_SCALE = 10430
const DYNAMIC_DEFAULTS = {
	number = Enums.NumberF64,
	CFrame = Enums.CFrameF32,
	Vector3 = Enums.Vector3F32,
	Vector2 = Enums.Vector2F32,
	["nil"] = Enums.Nil,
	string = Enums.String,
	Color3 = Enums.Color3,
	BrickColor = Enums.BrickColor,
	boolean = Enums.Boolean,
	table = Enums.DictDynamic,
	buffer = Enums.Buffer,
	Instance = Enums.Instance,
	DateTime = Enums.DateTime64,
	TweenInfo = Enums.TweenInfo,
	ColorSequence = Enums.ColorSequence,
	NumberSequence = Enums.NumberSequence,
	NumberRange = Enums.NumberRange,
	UDim = Enums.UDim,
	UDim2 = Enums.UDim2,
	Region3 = Enums.Region3,
	PhysicalProperties = Enums.PhysicalProperties,
	Rect = Enums.Rect,
	Font = Enums.Font,
	Ray = Enums.Ray,
}
const ENUM_NIL = Enums.Nil
const ENUM_ARRAYDYNAMIC = Enums.ArrayDynamic
const TBL_POOL_SIZE = 100

local tablePool = table.create(TBL_POOL_SIZE)
 
@native local function getTable(): {any}
	local poolIdx = #tablePool
	local tbl = tablePool[poolIdx]
	tablePool[poolIdx] = nil
	return tbl or {}
end

@native local function recycleTable(tbl: {any})
	local poolIdx = #tablePool
	if poolIdx > TBL_POOL_SIZE then
		return
	end
	table.clear(tbl)
	tablePool[poolIdx + 1] = tbl
end

@native local function isArray(tbl: {any}): boolean
	local count = 1
	for i, val in tbl do
		if i ~= count then
			return false
		end
		count += 1
	end
	return true
end

@native local function getDataType(value: any): number?
	local generalType = typeof(value)
	local dataType = DYNAMIC_DEFAULTS[generalType] or ENUM_NIL

	if generalType == "table" then
		if isArray(value) then
			dataType = ENUM_ARRAYDYNAMIC
		end
	end
	return dataType
end

@native local function encodeFloat16(value: number): number
	if value == 0 then
		return value
	end
	local sign = 0
	if value < 0 then
		sign = 1
		value = -value
	end

	local mantissa, exponent = math.frexp(value)
	local expNum = exponent + 14
	if expNum <= 0 then
		return 0
	elseif expNum >= 31 then
		return sign * 32768 + 31744
	end
	local mant = mantissa * 2048 - 1024
	mant = math.floor(mant + .5)
	return sign * 32768 + expNum * 1024 + mant
end

@native local function decodeFloat16(value: number): number
	if value == 0 then
		return 0
	end

	local sign = (value >= 0x8000) and -1 or 1
	if sign == -1 then
		value -= 0x8000
	end

	local exponent = math.floor(value / 1024)
	local mantissa = value - exponent * 1024

	if exponent == 0 then
		return 0
	elseif exponent == 31 then
		return sign * math.huge
	end

	local normalized = 1 + mantissa / 1024
	return sign * normalized * 2^(exponent - 15)
end

--number
@native local function encodeNumberU8(buff: buffer, offset: number, arg: SchemaArg, value: number): number
	buffer.writeu8(buff, offset, value)
	return 1
end

@native local function encodeNumberU16(buff: buffer, offset: number, arg: SchemaArg, value: number): number
	buffer.writeu16(buff, offset, value)
	return 2
end

@native local function encodeNumberU32(buff: buffer, offset: number, arg: SchemaArg, value: number): number
	buffer.writeu32(buff, offset, value)
	return 4
end

@native local function encodeNumberI8(buff: buffer, offset: number, arg: SchemaArg, value: number): number
	buffer.writei8(buff, offset, value)
	return 1
end

@native local function encodeNumberI16(buff: buffer, offset: number, arg: SchemaArg, value: number): number
	buffer.writei16(buff, offset, value)
	return 2
end

@native local function encodeNumberI32(buff: buffer, offset: number, arg: SchemaArg, value: number): number
	buffer.writei32(buff, offset, value)
	return 4
end

@native local function encodeNumberF16(buff: buffer, offset: number, arg: SchemaArg, value: number): number
	buffer.writeu16(buff, offset, encodeFloat16(value))
	return 2	
end

@native local function encodeNumberF32(buff: buffer, offset: number, arg: SchemaArg, value: number): number
	buffer.writef32(buff, offset, value)
	return 4
end

@native local function encodeNumberF64(buff: buffer, offset: number, arg: SchemaArg, value: number): number
	buffer.writef64(buff, offset, value)
	return 8
end

@native local function decodeNumberU8(buff: buffer, offset: number, arg: SchemaArg): (number, number)
	return buffer.readu8(buff, offset), 1
end

@native local function decodeNumberU16(buff: buffer, offset: number, arg: SchemaArg): (number, number)
	return buffer.readu16(buff, offset), 2
end

@native local function decodeNumberU32(buff: buffer, offset: number, arg: SchemaArg): (number, number)
	return buffer.readu32(buff, offset), 4
end

@native local function decodeNumberI8(buff: buffer, offset: number, arg: SchemaArg): (number, number)
	return buffer.readi8(buff, offset), 1
end

@native local function decodeNumberI16(buff: buffer, offset: number, arg: SchemaArg): (number, number)
	return buffer.readi16(buff, offset), 2
end

@native local function decodeNumberI32(buff: buffer, offset: number, arg: SchemaArg): (number, number)
	return buffer.readi32(buff, offset), 4
end

@native local function decodeNumberF16(buff: buffer, offset: number, arg: SchemaArg): (number, number)
	return decodeFloat16(buffer.readu16(buff, offset)), 2
end

@native local function decodeNumberF32(buff: buffer, offset: number, arg: SchemaArg): (number, number)
	return buffer.readf32(buff, offset), 4
end

@native local function decodeNumberF64(buff: buffer, offset: number, arg: SchemaArg): (number, number)
	return buffer.readf64(buff, offset), 8
end

--cframe
@native local function encodeCFrameFX8(buff: buffer, offset: number, arg: SchemaArg, value: CFrame): number
	local pos = value.Position
	local x, y, z = value:ToEulerAnglesXYZ()
	buffer.writei8(buff, offset, pos.X * FX8_SCALE)
	buffer.writei8(buff, offset + 1, pos.Y * FX8_SCALE)
	buffer.writei8(buff, offset + 2, pos.Z * FX8_SCALE)
	buffer.writei8(buff, offset + 3, x * FX8_ROT_SCALE)
	buffer.writei8(buff, offset + 4, y * FX8_ROT_SCALE)
	buffer.writei8(buff, offset + 5, z * FX8_ROT_SCALE)
	return 6
end

@native local function encodeCFrameI16FX16(buff: buffer, offset: number, arg: SchemaArg, value: CFrame): number
	local pos = value.Position
	local x, y, z = value:ToEulerAnglesXYZ()
	buffer.writei16(buff, offset, pos.X)
	buffer.writei16(buff, offset + 2, pos.Y)
	buffer.writei16(buff, offset + 4, pos.Z)
	buffer.writei16(buff, offset + 6, x * FX16_ROT_SCALE)
	buffer.writei16(buff, offset + 8, y * FX16_ROT_SCALE)
	buffer.writei16(buff, offset + 10, z * FX16_ROT_SCALE)
	return 12
end

@native local function decodeCFrameI16FX16(buff: buffer, offset: number, arg: SchemaArg): (CFrame, number)
	local pos = Vector3.new(
		buffer.readi16(buff, offset),
		buffer.readi16(buff, offset + 2),
		buffer.readi16(buff, offset + 4)
	)
	local x = buffer.readi16(buff, offset + 6) / FX16_ROT_SCALE
	local y = buffer.readi16(buff, offset + 8) / FX16_ROT_SCALE
	local z = buffer.readi16(buff, offset + 10) / FX16_ROT_SCALE
	return CFrame.Angles(x, y, z) + pos, 12
end

@native local function encodeCFrameFX16(buff: buffer, offset: number, arg: SchemaArg, value: CFrame): number
	local pos = value.Position
	local x, y, z = value:ToEulerAnglesXYZ()
	buffer.writei16(buff, offset, pos.X * FX16_SCALE)
	buffer.writei16(buff, offset + 2, pos.Y * FX16_SCALE)
	buffer.writei16(buff, offset + 4, pos.Z * FX16_SCALE)
	buffer.writei16(buff, offset + 6, x * FX16_ROT_SCALE)
	buffer.writei16(buff, offset + 8, y * FX16_ROT_SCALE)
	buffer.writei16(buff, offset + 10, z * FX16_ROT_SCALE)
	return 12
end

@native local function encodeCFrameF16(buff: buffer, offset: number, arg: SchemaArg, value: CFrame): number
	local pos = value.Position
	local x, y, z = value:ToEulerAnglesXYZ()
	buffer.writeu16(buff, offset, encodeFloat16(pos.X))
	buffer.writeu16(buff, offset + 2, encodeFloat16(pos.Y))
	buffer.writeu16(buff, offset + 4, encodeFloat16(pos.Z))
	buffer.writeu16(buff, offset + 6, encodeFloat16(x))
	buffer.writeu16(buff, offset + 8, encodeFloat16(y))
	buffer.writeu16(buff, offset + 10, encodeFloat16(z))
	return 12
end

@native local function axisId(x: number, y: number, z: number): number
	local ax = math.abs(x)
	local ay = math.abs(y)
	local az = math.abs(z)

	if ax >= ay and ax >= az then
		return x > 0 and 0 or 1
	elseif ay >= az then
		return y > 0 and 2 or 3
	else
		return z > 0 and 4 or 5
	end
end

local xAxis = Vector3.new(1, 0, 0)
local yAxis = Vector3.new(0, 1, 0)
local zAxis = Vector3.new(0, 0, 1)

local alignIdsToCFrames = {
	[0] = CFrame.identity,
	[1] = CFrame.identity,
	[2] = CFrame.fromMatrix(Vector3.zero, xAxis, yAxis),
	[3] = CFrame.fromMatrix(Vector3.zero, xAxis, -yAxis),
	[4] = CFrame.fromMatrix(Vector3.zero, xAxis, zAxis),
	[5] = CFrame.fromMatrix(Vector3.zero, xAxis, -zAxis),
	
	[6] = CFrame.identity,
	[7] = CFrame.identity,
	[8] = CFrame.fromMatrix(Vector3.zero, -xAxis, yAxis),
	[9] = CFrame.fromMatrix(Vector3.zero, -xAxis, -yAxis),
	[10] = CFrame.fromMatrix(Vector3.zero, -xAxis, zAxis),
	[11] = CFrame.fromMatrix(Vector3.zero, -xAxis, -zAxis),
	
	[12] = CFrame.fromMatrix(Vector3.zero, yAxis, xAxis),
	[13] = CFrame.fromMatrix(Vector3.zero, yAxis, -xAxis),
	[14] = CFrame.identity,
	[15] = CFrame.identity,
	[16] = CFrame.fromMatrix(Vector3.zero, yAxis, zAxis),
	[17] = CFrame.fromMatrix(Vector3.zero, yAxis, -zAxis),
	
	[18] = CFrame.fromMatrix(Vector3.zero, -yAxis, xAxis),
	[19] = CFrame.fromMatrix(Vector3.zero, -yAxis, -xAxis),
	[20] = CFrame.identity,
	[21] = CFrame.identity,
	[22] = CFrame.fromMatrix(Vector3.zero, -yAxis, zAxis),
	[23] = CFrame.fromMatrix(Vector3.zero, -yAxis, -zAxis),
	
	[24] = CFrame.fromMatrix(Vector3.zero, zAxis, xAxis),
	[25] = CFrame.fromMatrix(Vector3.zero, zAxis, -xAxis),
	[26] = CFrame.fromMatrix(Vector3.zero, zAxis, yAxis),
	[27] = CFrame.fromMatrix(Vector3.zero, zAxis, -yAxis),
	[28] = CFrame.identity,
	[29] = CFrame.identity,
	
	[30] = CFrame.fromMatrix(Vector3.zero, -zAxis, xAxis),
	[31] = CFrame.fromMatrix(Vector3.zero, -zAxis, -xAxis),
	[32] = CFrame.fromMatrix(Vector3.zero, -zAxis, yAxis),
	[33] = CFrame.fromMatrix(Vector3.zero, -zAxis, -yAxis),
	[34] = CFrame.identity,
	[35] = CFrame.identity,	
}

@native local function encodeCFrameF32Aligned(buff: buffer, offset: number, arg: SchemaArg, value: CFrame): number
	local x, y, z,
	r00, r01, r02,
	r10, r11, r12,
	r20, r21, r22 = value:GetComponents()
	local right = axisId(r00, r10, r20)
	local up = axisId(r01, r11, r21)
	buffer.writef32(buff, offset, x)
	buffer.writef32(buff, offset + 4, y)
	buffer.writef32(buff, offset + 8, z)
	buffer.writeu8(buff, offset + 12, right * 6 + up)
	return 13
end

@native local function decodeCFrameF32Aligned(buff: buffer, offset: number, arg: SchemaArg): (CFrame, number)
	local x = buffer.readf32(buff, offset)
	local y = buffer.readf32(buff, offset + 4)
	local z = buffer.readf32(buff, offset + 8)
	local alignId = buffer.readu8(buff, offset + 12)
	return alignIdsToCFrames[alignId] + Vector3.new(x, y, z), 13
end

@native local function encodeCFrameF32FX16(buff: buffer, offset: number, arg: SchemaArg, value: CFrame): number
	local pos = value.Position
	local x, y, z = value:ToEulerAnglesXYZ()
	buffer.writef32(buff, offset, pos.X)
	buffer.writef32(buff, offset + 4, pos.Y)
	buffer.writef32(buff, offset + 8, pos.Z)
	buffer.writei16(buff, offset + 12, x * FX16_ROT_SCALE)
	buffer.writei16(buff, offset + 14, y * FX16_ROT_SCALE)
	buffer.writei16(buff, offset + 16, z * FX16_ROT_SCALE)
	return 18
end

@native local function encodeCFrameF32(buff: buffer, offset: number, arg: SchemaArg, value: CFrame): number
	local pos = value.Position
	local x, y, z = value:ToEulerAnglesXYZ()
	buffer.writef32(buff, offset, pos.X)
	buffer.writef32(buff, offset + 4, pos.Y)
	buffer.writef32(buff, offset + 8, pos.Z)
	buffer.writef32(buff, offset + 12, x)
	buffer.writef32(buff, offset + 16, y)
	buffer.writef32(buff, offset + 20, z)
	return 24
end

@native local function decodeCFrameFX8(buff: buffer, offset: number, arg: SchemaArg): (CFrame, number)
	local posX = buffer.readi8(buff, offset) / FX8_SCALE
	local posY = buffer.readi8(buff, offset + 1) / FX8_SCALE
	local posZ = buffer.readi8(buff, offset + 2) / FX8_SCALE
	local x = buffer.readi8(buff, offset + 3) / FX8_ROT_SCALE
	local y = buffer.readi8(buff, offset + 4) / FX8_ROT_SCALE
	local z = buffer.readi8(buff, offset + 5) / FX8_ROT_SCALE
	return CFrame.Angles(x, y, z) + Vector3.new(posX, posY, posZ), 6
end

@native local function decodeCFrameFX16(buff: buffer, offset: number, arg: SchemaArg): (CFrame, number)
	local posX = buffer.readi16(buff, offset) / FX16_SCALE
	local posY = buffer.readi16(buff, offset + 2) / FX16_SCALE
	local posZ = buffer.readi16(buff, offset + 4) / FX16_SCALE
	local x = buffer.readi16(buff, offset + 6) / FX16_ROT_SCALE
	local y = buffer.readi16(buff, offset + 8) / FX16_ROT_SCALE
	local z = buffer.readi16(buff, offset + 10) / FX16_ROT_SCALE
	return CFrame.Angles(x, y, z) + Vector3.new(posX, posY, posZ), 12
end

@native local function decodeCFrameF16(buff: buffer, offset: number, arg: SchemaArg): (CFrame, number)
	local posX = decodeFloat16(buffer.readu16(buff, offset))
	local posY = decodeFloat16(buffer.readu16(buff, offset + 2))
	local posZ = decodeFloat16(buffer.readu16(buff, offset + 4))
	local x = decodeFloat16(buffer.readu16(buff, offset + 6))
	local y = decodeFloat16(buffer.readu16(buff, offset + 8))
	local z = decodeFloat16(buffer.readu16(buff, offset + 10))
	return CFrame.Angles(x, y, z) + Vector3.new(posX, posY, posZ), 12
end

@native local function decodeCFrameF32FX16(buff: buffer, offset: number, arg: SchemaArg): (CFrame, number)
	local posX = buffer.readf32(buff, offset)
	local posY = buffer.readf32(buff, offset + 4)
	local posZ = buffer.readf32(buff, offset + 8)
	local x = buffer.readi16(buff, offset + 12) / FX16_ROT_SCALE
	local y = buffer.readi16(buff, offset + 14) / FX16_ROT_SCALE
	local z = buffer.readi16(buff, offset + 16) / FX16_ROT_SCALE
	return CFrame.Angles(x, y, z) + Vector3.new(posX, posY, posZ), 18
end

@native local function decodeCFrameF32(buff: buffer, offset: number, arg: SchemaArg): (CFrame, number)
	local posX = buffer.readf32(buff, offset)
	local posY = buffer.readf32(buff, offset + 4)
	local posZ = buffer.readf32(buff, offset + 8)
	local x = buffer.readf32(buff, offset + 12)
	local y = buffer.readf32(buff, offset + 16)
	local z = buffer.readf32(buff, offset + 20)
	return CFrame.Angles(x, y, z) + Vector3.new(posX, posY, posZ), 24
end

--vector3
@native local function encodeVector3FX8(buff: buffer, offset: number, arg: SchemaArg, value: Vector3): number
	buffer.writei8(buff, offset, value.X * FX8_SCALE)
	buffer.writei8(buff, offset + 1, value.Y * FX8_SCALE)
	buffer.writei8(buff, offset + 2, value.Z * FX8_SCALE)
	return 3
end

@native local function encodeVector3I16(buff: buffer, offset: number, arg: SchemaArg, value: Vector3): number
	buffer.writei16(buff, offset, value.X)
	buffer.writei16(buff, offset + 2, value.Y)
	buffer.writei16(buff, offset + 4, value.Z)
	return 6
end

@native local function decodeVector3I16(buff: buffer, offset: number, arg: SchemaArg): (Vector3, number)
	return Vector3.new(
		buffer.readi16(buff, offset),
		buffer.readi16(buff, offset + 2),
		buffer.readi16(buff, offset + 4)
	), 6
end

@native local function encodeVector3FX16(buff: buffer, offset: number, arg: SchemaArg, value: Vector3): number
	buffer.writei16(buff, offset, value.X * FX16_SCALE)
	buffer.writei16(buff, offset + 2, value.Y * FX16_SCALE)
	buffer.writei16(buff, offset + 4, value.Z * FX16_SCALE)
	return 6
end

@native local function encodeVector3F16(buff: buffer, offset: number, arg: SchemaArg, value: Vector3): number	
	buffer.writeu16(buff, offset, encodeFloat16(value.X))
	buffer.writeu16(buff, offset + 2, encodeFloat16(value.Y))
	buffer.writeu16(buff, offset + 4, encodeFloat16(value.Z))
	return 6
end

@native local function encodeVector3F32(buff: buffer, offset: number, arg: SchemaArg, value: Vector3): number
	buffer.writef32(buff, offset, value.X)
	buffer.writef32(buff, offset + 4, value.Y)
	buffer.writef32(buff, offset + 8, value.Z)
	return 12
end

@native local function decodeVector3FX8(buff: buffer, offset: number, arg: SchemaArg): (Vector3, number)
	local x = buffer.readi8(buff, offset) / FX8_SCALE
	local y = buffer.readi8(buff, offset + 1) / FX8_SCALE
	local z = buffer.readi8(buff, offset + 2) / FX8_SCALE
	return Vector3.new(x, y, z), 3
end

@native local function decodeVector3FX16(buff: buffer, offset: number, arg: SchemaArg): (Vector3, number)
	local x = buffer.readi16(buff, offset) / FX16_SCALE
	local y = buffer.readi16(buff, offset + 2) / FX16_SCALE
	local z = buffer.readi16(buff, offset + 4) / FX16_SCALE
	return Vector3.new(x, y, z), 6
end

@native local function decodeVector3F16(buff: buffer, offset: number, arg: SchemaArg): (Vector3, number)
	local x = decodeFloat16(buffer.readu16(buff, offset))
	local y = decodeFloat16(buffer.readu16(buff, offset + 2))
	local z = decodeFloat16(buffer.readu16(buff, offset + 4))
	return Vector3.new(x, y, z), 6
end

@native local function decodeVector3F32(buff: buffer, offset: number, arg: SchemaArg): (Vector3, number)
	return Vector3.new(
		buffer.readf32(buff, offset),
		buffer.readf32(buff, offset + 4),
		buffer.readf32(buff, offset + 8)
	), 12
end

--vector2
@native local function encodeVector2FX8(buff: buffer, offset: number, arg: SchemaArg, value: Vector2): number
	buffer.writei8(buff, offset, value.X * FX8_SCALE)
	buffer.writei8(buff, offset + 1, value.Y * FX8_SCALE)
	return 2
end

@native local function encodeVector2I16(buff: buffer, offset: number, arg: SchemaArg, value: Vector2): number
	buffer.writei16(buff, offset, value.X)
	buffer.writei16(buff, offset + 2, value.Y)
	return 4
end

@native local function decodeVector2I16(buff: buffer, offset: number, arg: SchemaArg): (Vector2, number)
	return Vector2.new(buffer.readi16(buff, offset), buffer.readi16(buff, offset + 2)), 4
end

@native local function encodeVector2FX16(buff: buffer, offset: number, arg: SchemaArg, value: Vector2): number
	buffer.writei16(buff, offset, value.X * FX16_SCALE)
	buffer.writei16(buff, offset + 2, value.Y * FX16_SCALE)
	return 4
end

@native local function encodeVector2F16(buff: buffer, offset: number, arg: SchemaArg, value: Vector2): number
	buffer.writeu16(buff, offset, encodeFloat16(value.X))
	buffer.writeu16(buff, offset + 2, encodeFloat16(value.Y))
	return 4
end

@native local function encodeVector2F32(buff: buffer, offset: number, arg: SchemaArg, value: Vector2): number
	buffer.writef32(buff, offset, value.X)
	buffer.writef32(buff, offset + 4, value.Y)
	return 8
end

@native local function decodeVector2FX8(buff: buffer, offset: number, arg: SchemaArg): (Vector2, number)
	local x = buffer.readi8(buff, offset) / FX8_SCALE
	local y = buffer.readi8(buff, offset + 1) / FX8_SCALE
	return Vector2.new(x, y), 2
end

@native local function decodeVector2FX16(buff: buffer, offset: number, arg: SchemaArg): (Vector2, number)
	local x = buffer.readi16(buff, offset) / FX16_SCALE
	local y = buffer.readi16(buff, offset + 2) / FX16_SCALE
	return Vector2.new(x, y), 4
end

@native local function decodeVector2F16(buff: buffer, offset: number, arg: SchemaArg): (Vector2, number)
	local x = decodeFloat16(buffer.readu16(buff, offset))
	local y = decodeFloat16(buffer.readu16(buff, offset + 2))
	return Vector2.new(x, y), 4
end

@native local function decodeVector2F32(buff: buffer, offset: number, arg: SchemaArg): (Vector2, number)
	local x = buffer.readf32(buff, offset)
	local y = buffer.readf32(buff, offset + 4)
	return Vector2.new(x, y), 8
end

--misc
@native local function encodeString(buff: buffer, offset: number, arg: SchemaArg, value: string): number
	local bytes = string.len(value)
	buffer.writeu8(buff, offset, bytes)
	buffer.writestring(buff, offset + 1, value, bytes)
	return bytes + 1
end

@native local function decodeString(buff: buffer, offset: number, arg: SchemaArg): (string, number)
	local bytes = buffer.readu8(buff, offset)
	return buffer.readstring(buff, offset + 1, bytes), bytes + 1
end

@native local function encodeStringLong(buff: buffer, offset: number, arg: SchemaArg, value: string): number
	local bytes = string.len(value)
	buffer.writeu32(buff, offset, bytes)
	buffer.writestring(buff, offset + 4, value, bytes)
	return bytes + 4
end

@native local function decodeStringLong(buff: buffer, offset: number, arg: SchemaArg, value: string): (string, number)
	local bytes = buffer.readu32(buff, offset)
	return buffer.readstring(buff, offset + 4, bytes), bytes + 4
end

@native local function encodeColor(buff: buffer, offset: number, arg: SchemaArg, value: Color3): number
	buffer.writeu8(buff, offset, value.R * 255 + .5)
	buffer.writeu8(buff, offset + 1, value.G * 255 + .5)
	buffer.writeu8(buff, offset + 2, value.B * 255 + .5)
	return 3
end

@native local function decodeColor(buff: buffer, offset: number, arg: SchemaArg): (Color3, number)
	local r = buffer.readu8(buff, offset)
	local g = buffer.readu8(buff, offset + 1)
	local b = buffer.readu8(buff, offset + 2)
	return Color3.fromRGB(r, g, b), 3
end

@native local function encodeBrickColor(buff: buffer, offset: number, arg: SchemaArg, value: BrickColor): number
	buffer.writeu16(buff, offset, value.Number)
	return 2
end

@native local function decodeBrickColor(buff: buffer, offset: number, arg: SchemaArg): (BrickColor, number)
	return BrickColor.new(buffer.readu16(buff, offset)), 2
end

@native local function encodeBool(buff: buffer, offset: number, arg: SchemaArg, value: boolean): number
	buffer.writeu8(buff, offset, if value then 1 else 0)
	return 1
end

@native local function decodeBool(buff: buffer, offset: number, arg: SchemaArg): (boolean, number)
	local val = buffer.readu8(buff, offset)
	return val == 1, 1
end

@native local function encodeNil(buff: buffer, offset: number, arg: SchemaArg, value: any): number
	return 0
end

@native local function decodeNil(buff: buffer, offset: number, arg: SchemaArg): (any, number)
	return nil, 0
end

@native local function encodeBuffer(buff: buffer, offset: number, arg: SchemaArg, value: buffer): number
	local len = buffer.len(value)
	buffer.writeu16(buff, offset, len)
	buffer.copy(buff, offset + 2, value, 0, len)
	return len + 2
end

@native local function decodeBuffer(buff: buffer, offset: number, arg: SchemaArg): (buffer?, number)
	local len = buffer.readu16(buff, offset)
	local newBuff = buffer.create(len)
	buffer.copy(newBuff, 0, buff, offset + 2, len)
	return newBuff, len + 2
end

@native local function encodeDateTime32(buff: buffer, offset: number, arg: SchemaArg, value: DateTime): number
	buffer.writeu32(buff, offset, value.UnixTimestamp)
	return 4
end

@native local function decodeDateTime32(buff: buffer, offset: number, arg: SchemaArg): (DateTime, number)
	return DateTime.fromUnixTimestamp(buffer.readu32(buff, offset)), 4
end

@native local function encodeDateTime64(buff: buffer, offset: number, arg: SchemaArg, value: DateTime): number
	buffer.writef64(buff, offset, value.UnixTimestampMillis)
	return 8
end

@native local function decodeDateTime64(buff: buffer, offset: number, arg: SchemaArg): (DateTime, number)
	return DateTime.fromUnixTimestampMillis(buffer.readf64(buff, offset)), 8
end

local tweenStyles = {
	Enum.EasingStyle.Linear,
	Enum.EasingStyle.Back,
	Enum.EasingStyle.Quad,
	Enum.EasingStyle.Bounce,
	Enum.EasingStyle.Sine,
	Enum.EasingStyle.Cubic,
	Enum.EasingStyle.Quart,
	Enum.EasingStyle.Quint,
	Enum.EasingStyle.Elastic,
	Enum.EasingStyle.Circular,
	Enum.EasingStyle.Exponential,	
}

local tweenDirections = {
	Enum.EasingDirection.In,
	Enum.EasingDirection.Out,
	Enum.EasingDirection.InOut,
}

local function keyValueSwap(tbl: {[any]: any}): {[any]: any}
	local new = {}
	for k, v in tbl do
		new[v] = k
	end
	return new
end

local tweenStylesToId: {[EnumItem]: number} = keyValueSwap(tweenStyles)
local tweenDirectionsToId: {[EnumItem]: number} = keyValueSwap(tweenDirections)

@native local function encodeTweenInfo(buff: buffer, offset: number, arg: SchemaArg, value: TweenInfo): number
	local style = tweenStylesToId[value.EasingStyle]
	local dir = tweenDirectionsToId[value.EasingDirection]
	local reverse = value.Reverses and 1 or 0
	local packed = style + dir * 16 + reverse * 128
	
	buffer.writeu16(buff, offset, value.Time * FX16_SCALE)
	buffer.writeu8(buff, offset + 2, packed)
	buffer.writei8(buff, offset + 3, value.RepeatCount)
	buffer.writeu16(buff, offset + 4, value.DelayTime * FX16_SCALE)
	return 6
end

@native local function decodeTweenInfo(buff: buffer, offset: number, arg: SchemaArg): (TweenInfo, number)
	local tweenTime = buffer.readu16(buff, offset) / FX16_SCALE
	local packed = buffer.readu8(buff, offset + 2)
	local repeatCount = buffer.readi8(buff, offset + 3)
	local delayTime = buffer.readu16(buff, offset + 4) / FX16_SCALE
	
	local styleId = packed % 16
	local dirId = (packed // 16) % 8
	local reverse = (packed // 128) == 1
	
	local tweenInfo = TweenInfo.new(
		tweenTime, 
		tweenStyles[styleId], 
		tweenDirections[dirId], 
		repeatCount,
		reverse,
		delayTime
	)
	return tweenInfo, 6
end

@native local function encodeColorSequence(buff: buffer, offset: number, arg: SchemaArg, value: ColorSequence)
	:number
	local keypoints = value.Keypoints
	buffer.writeu8(buff, offset, #keypoints)
	local ptr = offset + 1
	
	for _, kp in keypoints do
		local color = kp.Value
		buffer.writeu8(buff, ptr, kp.Time * 255 + .5)
		buffer.writeu8(buff, ptr + 1, color.R * 255 + .5)
		buffer.writeu8(buff, ptr + 2, color.G * 255 + .5)
		buffer.writeu8(buff, ptr + 3, color.B * 255 + .5)
		ptr += 4
	end	
	return ptr - offset
end

@native local function decodeColorSequence(buff: buffer, offset: number, arg: SchemaArg): (ColorSequence, number)
	local len = buffer.readu8(buff, offset)
	local ptr = offset + 1
	local keypoints = table.create(len)
	
	for i = 1, len do
		keypoints[i] = ColorSequenceKeypoint.new(
			buffer.readu8(buff, ptr) / 255,
			Color3.fromRGB(
				buffer.readu8(buff, ptr + 1),
				buffer.readu8(buff, ptr + 2),
				buffer.readu8(buff, ptr + 3)
			)
		)
		ptr += 4
	end
	return ColorSequence.new(keypoints), ptr - offset
end

@native local function encodeNumberSequence(buff: buffer, offset: number, arg: SchemaArg, value: NumberSequence)
	:number
	local keypoints = value.Keypoints
	buffer.writeu8(buff, offset, #keypoints)
	local ptr = offset + 1
	
	for _, kp in keypoints do
		buffer.writeu8(buff, ptr, kp.Time * 255 + .5)
		buffer.writeu8(buff, ptr + 1, kp.Value * 255 + .5)
		buffer.writeu8(buff, ptr + 2, kp.Envelope * 255 + .5)
		ptr += 3
	end
	return ptr - offset
end

@native local function decodeNumberSequence(buff: buffer, offset: number, arg: SchemaArg)
	: (NumberSequence, number)
	local len = buffer.readu8(buff, offset)
	local ptr = offset + 1
	local keypoints = table.create(len)
	
	for i = 1, len do
		keypoints[i] = NumberSequenceKeypoint.new(
			buffer.readu8(buff, ptr) / 255,
			buffer.readu8(buff, ptr + 1) / 255,
			buffer.readu8(buff, ptr + 2) / 255
		)
		ptr += 3
	end
	return NumberSequence.new(keypoints), ptr - offset
end

@native local function encodeNumberRange(buff: buffer, offset: number, arg: SchemaArg, value: NumberRange)
	:number
	buffer.writef32(buff, offset, value.Min)
	buffer.writef32(buff, offset + 4, value.Max)
	return 8
end

@native local function decodeNumberRange(buff: buffer, offset: number, arg: SchemaArg): (NumberRange, number)
	return NumberRange.new(buffer.readf32(buff, offset), buffer.readf32(buff, offset + 4)), 8
end

@native local function encodeUDim(buff: buffer, offset: number, arg: SchemaArg, value: UDim): number
	buffer.writei16(buff, offset, value.Scale * 1000)
	buffer.writei16(buff, offset + 2, value.Offset)
	return 4
end

@native local function decodeUDim(buff: buffer, offset: number, arg: SchemaArg): (UDim, number)
	return UDim.new(buffer.readi16(buff, offset) / 1000, buffer.readi16(buff, offset + 2)), 4
end

@native local function encodeUDim2(buff: buffer, offset: number, arg: SchemaArg, value: UDim2): number
	local x, y = value.X, value.Y
	buffer.writei16(buff, offset, x.Scale * 1000)
	buffer.writei16(buff, offset + 2, x.Offset)
	buffer.writei16(buff, offset + 4, y.Scale * 1000)
	buffer.writei16(buff, offset + 6, y.Offset)
	return 8
end

@native local function decodeUDim2(buff: buffer, offset: number, arg: SchemaArg): (UDim2, number)
	return UDim2.new(
		buffer.readi16(buff, offset) / 1000,
		buffer.readi16(buff, offset + 2),
		buffer.readi16(buff, offset + 4) / 1000,
		buffer.readi16(buff, offset + 6)
		), 8
end

@native local function encodeRegion3(buff: buffer, offset: number, arg: SchemaArg, value: Region3): number
	local halfSize = value.Size / 2
	local pos = value.CFrame.Position
	local min, max = pos - halfSize, pos + halfSize
	buffer.writef32(buff, offset, min.X)
	buffer.writef32(buff, offset + 4, min.Y)
	buffer.writef32(buff, offset + 8, min.Z)
	buffer.writef32(buff, offset + 12, max.X)
	buffer.writef32(buff, offset + 16, max.Y)
	buffer.writef32(buff, offset + 20, max.Z)
	return 24
end

@native local function decodeRegion3(buff: buffer, offset: number, arg: SchemaArg): (Region3, number)
	return Region3.new(
		Vector3.new(
			buffer.readf32(buff, offset),
			buffer.readf32(buff, offset + 4),
			buffer.readf32(buff, offset + 8)
		),
		Vector3.new(
			buffer.readf32(buff, offset + 12),
			buffer.readf32(buff, offset + 16),
			buffer.readf32(buff, offset + 20)
		)
	), 24
end

@native local function encodePhysicalProperties(buff: buffer, offset: number, arg: SchemaArg, value: PhysicalProperties)
	:number
	buffer.writeu16(buff, offset, value.Density * 655.35)
	buffer.writeu8(buff, offset + 2, value.Friction * 127.5)
	buffer.writeu8(buff, offset + 3, value.Elasticity * 255)
	buffer.writeu16(buff, offset + 4, value.FrictionWeight * 655.35)
	buffer.writeu16(buff, offset + 6, value.ElasticityWeight * 655.35)
	buffer.writeu8(buff, offset + 8, value.AcousticAbsorption * 255)
	return 9
end

@native local function decodePhysicalProperties(buff: buffer, offset: number, arg: SchemaArg)
	:(PhysicalProperties, number)
	return PhysicalProperties.new(
		buffer.readu16(buff, offset) / 655.35,
		buffer.readu8(buff, offset + 2) / 127.5,
		buffer.readu8(buff, offset + 3) / 255,
		buffer.readu16(buff, offset + 4) / 655.35,
		buffer.readu16(buff, offset + 6) / 655.35,
		buffer.readu8(buff, offset + 8) / 255
	), 9
end

@native local function encodeRect(buff: buffer, offset: number, arg: SchemaArg, value: Rect): number
	local min, max = value.Min, value.Max
	buffer.writef32(buff, offset, min.X)
	buffer.writef32(buff, offset + 4, min.Y)
	buffer.writef32(buff, offset + 8, max.X)
	buffer.writef32(buff, offset + 12, max.Y)
	return 16
end

@native local function decodeRect(buff: buffer, offset: number, arg: SchemaArg): (Rect, number)
	return Rect.new(
		buffer.readf32(buff, offset),
		buffer.readf32(buff, offset + 4),
		buffer.readf32(buff, offset + 8),
		buffer.readf32(buff, offset + 12)
	), 16
end

@native local function encodeBulkNumberU4Array(buff: buffer, offset: number, array: {number}): number
	local ptr = offset
	local arrayLen = #array
	local mod = arrayLen % 2
	local iters = (arrayLen - mod) / 2
	local nibPtr = 1

	for i = 1, iters do
		buffer.writeu8(buff, ptr, array[nibPtr] + array[nibPtr + 1] * 16)
		ptr += 1
		nibPtr += 2
	end
	
	if mod ~= 0 then
		buffer.writeu8(buff, ptr, array[arrayLen])
	end
	return ptr - offset
end

@native local function decodeBulkNumberU4Array(buff: buffer, offset: number, arrayLen: number, tbl: {any}?)
	:({number}, number)
	local ptr = offset
	local array = tbl or table.create(arrayLen)
	local mod = arrayLen % 2
	local iters = (arrayLen - mod) / 2
	local nibPtr = 1
	
	for i = 1, iters do
		local b = buffer.readu8(buff, ptr)
		local n2 = b // 16
		local n1 = b - n2 * 16
		array[nibPtr] = n1
		array[nibPtr + 1] = n2
		ptr += 1
		nibPtr += 2	
	end

	if mod ~= 0 then
		array[arrayLen] = buffer.readu8(buff, ptr)
	end
	return array, ptr - offset
end

@native local function encodeBulkNumberU8Array(buff: buffer, offset: number, array: {number}): number
	local ptr = offset
	for _, val in array do
		buffer.writeu8(buff, ptr, val)
		ptr += 1
	end
	return ptr - offset
end

@native local function decodeBulkNumberU8Array(buff: buffer, offset: number, arrayLen: number, tbl: {any}?)
	: ({number}, number)
	local ptr = offset
	local array = tbl or table.create(arrayLen)
	for i = 1, arrayLen do
		array[i] = buffer.readu8(buff, ptr)
		ptr += 1
	end	
	return array, ptr - offset
end

@native local function encodeBulkNumberI32Array(buff: buffer, offset: number, array: {number}): number
	local ptr = offset
	for _, val in array do
		buffer.writei32(buff, ptr, val)
		ptr += 4
	end
	return ptr - offset
end

@native local function decodeBulkNumberI32Array(buff: buffer, offset: number, arrayLen: number, tbl: {any}?)
	: ({number}, number)
	local ptr = offset
	local array = tbl or table.create(arrayLen)
	for i = 1, arrayLen do
		array[i] = buffer.readi32(buff, ptr)
		ptr += 4
	end
	return array, ptr - offset
end

@native local function encodeBulkNumberF32Array(buff: buffer, offset: number, array: {number}): number
	local ptr = offset
	for _, val in array do
		buffer.writef32(buff, ptr, val)
		ptr += 4
	end
	return ptr - offset
end

@native local function decodeBulkNumberF32Array(buff: buffer, offset: number, arrayLen: number, tbl: {any}?)
	: ({number}, number)
	local ptr = offset
	local array = tbl or table.create(arrayLen)
	for i = 1, arrayLen do
		array[i] = buffer.readf32(buff, ptr)
		ptr += 4
	end
	return array, ptr - offset
end

@native local function encodeBulkBoolArray(buff: buffer, offset: number, array: {boolean}): number
	local ptr = offset
	local arrayLen = #array
	local mod = arrayLen % 8
	local bitIters = (arrayLen - mod) / 8

	local bitPtr = 1
	for i = 1, bitIters do
		buffer.writeu8(buff, ptr,
				(if array[bitPtr] then 1 else 0) +
				(if array[bitPtr + 1] then 2 else 0) + 
				(if array[bitPtr + 2] then 4 else 0) +
				(if array[bitPtr + 3] then 8 else 0) +
				(if array[bitPtr + 4] then 16 else 0) +
				(if array[bitPtr + 5] then 32 else 0) +
				(if array[bitPtr + 6] then 64 else 0) +
				(if array[bitPtr + 7] then 128 else 0)
				)
		bitPtr += 8
		ptr += 1
	end
	
	for i = arrayLen - mod + 1, arrayLen do
		buffer.writeu8(buff, ptr, if array[i] then 1 else 0)
		ptr += 1
	end
	
	return ptr - offset
end

local byteToBools = table.create(256)
local function buildByteToBools()
	for byte = 0, 255 do
		local t = table.create(8)
		local val = byte

		for i = 1, 8 do
			t[i] = (val % 2) == 1
			val = val // 2
		end
		byteToBools[byte] = t
	end
end

buildByteToBools()

@native local function decodeBulkBoolArray(buff: buffer, offset: number, arrayLen: number, tbl: {any}?)
	: ({boolean}, number)
	local ptr = offset
	local array = tbl or table.create(arrayLen)
	local mod = arrayLen % 8
	local bitIters = (arrayLen - mod) / 8
	local bitPtr = 1

	for i = 1, bitIters do
		local byte = buffer.readu8(buff, ptr)
		ptr += 1
		
		local bits = byteToBools[byte]
		array[bitPtr]     = bits[1]
		array[bitPtr + 1] = bits[2]
		array[bitPtr + 2] = bits[3]
		array[bitPtr + 3] = bits[4]
		array[bitPtr + 4] = bits[5]
		array[bitPtr + 5] = bits[6]
		array[bitPtr + 6] = bits[7]
		array[bitPtr + 7] = bits[8]		
		bitPtr += 8
	end
	
	for i = arrayLen - mod + 1, arrayLen do
		array[i] = buffer.readu8(buff, ptr) == 1
		ptr += 1
	end
	
	return array, ptr - offset
end

@native local function encodeBulkStringArray(buff: buffer, offset: number, array: {string}): number
	local ptr = offset
	
	for _, str in array do
		local len = string.len(str)
		buffer.writeu8(buff, ptr, len)
		ptr += 1
	end
	
	local largeStr = table.concat(array)
	local totalLen = string.len(largeStr)
	buffer.writeu32(buff, ptr, totalLen)
	ptr += 4
	buffer.writestring(buff, ptr, largeStr, totalLen)
	return ptr + totalLen - offset
end

@native local function decodeBulkStringArray(buff: buffer, offset: number, arrayLen: number, tbl: {any}?)
	: ({string}, number)
	local ptr = offset
	local array = tbl or table.create(arrayLen)	
	local totalLenPtr = ptr + arrayLen
	local totalLen = buffer.readu32(buff, totalLenPtr)
	local largeStr = buffer.readstring(buff, totalLenPtr + 4, totalLen)
	local largeStrPtr = 1
	
	for i = 1, arrayLen do
		local start = largeStrPtr
		largeStrPtr += buffer.readu8(buff, ptr)
		ptr += 1
		array[i] = string.sub(largeStr, start, largeStrPtr - 1)
	end	
	return array, ptr + totalLen + 4 - offset
end

@native local function encodeBulkNumberU8DictStatic(buff: buffer, offset: number, dict: {[any]: number}, keysMap: {any})
	: number
	local ptr = offset
	for _, key in keysMap do
		buffer.writeu8(buff, ptr, dict[key])
		ptr += 1
	end
	return ptr - offset
end

@native local function decodeBulkNumberU8DictStatic(buff: buffer, offset: number, keysMap: {any}, 
	template: {[string | number]: any}): ({[any]: number}, number)
	local ptr = offset
	local dict = table.clone(template)
	for _, key in keysMap do
		dict[key] = buffer.readu8(buff, ptr)
		ptr += 1
	end
	return dict, ptr - offset
end

@native local function encodeBulkNumberI32DictStatic(buff: buffer, offset: number, dict: {[any]: number}, keysMap: {any})
	: number
	local ptr = offset
	for _, key in keysMap do
		buffer.writei32(buff, ptr, dict[key])
		ptr += 4
	end
	return ptr - offset
end

@native local function decodeBulkNumberI32DictStatic(buff: buffer, offset: number, keysMap: {any},
	template: {[string | number]: any}): ({[any]: number}, number)
	local ptr = offset
	local dict = table.clone(template)
	for _, key in keysMap do
		dict[key] = buffer.readi32(buff, ptr)
		ptr += 4
	end
	return dict, ptr - offset
end

@native local function encodeBulkNumberF32DictStatic(buff: buffer, offset: number, dict: {[any]: number}, keysMap: {any})
	: number
	local ptr = offset

	for _, key in keysMap do
		buffer.writef32(buff, ptr, dict[key])
		ptr += 4
	end
	return ptr - offset
end

@native local function decodeBulkNumberF32DictStatic(buff: buffer, offset: number, keysMap: {any},
	template: {[string | number]: any}): ({[any]: number}, number)
	local ptr = offset
	local dict = table.clone(template)
	for _, key in keysMap do
		dict[key] = buffer.readf32(buff, ptr)
		ptr += 4
	end
	return dict, ptr - offset
end

@native local function encodeBulkBoolDictStatic(buff: buffer, offset: number, dict: {[any]: boolean}, keysMap: {any})
	: number
	local ptr = offset
	for _, key in keysMap do
		buffer.writeu8(buff, ptr, dict[key] and 1 or 0)
		ptr += 1
	end
	return ptr - offset
end

@native local function decodeBulkBoolDictStatic(buff: buffer, offset: number, keysMap: {any},
	template: {[string | number]: any}): ({[any]: boolean}, number)
	local ptr = offset
	local dict = table.clone(template)
	for _, key in keysMap do
		dict[key] = buffer.readu8(buff, ptr) == 1
		ptr += 1
	end
	return dict, ptr - offset
end

@native local function encodeBulkStringDictStatic(buff: buffer, offset: number, dict: {[any]: string}, keysMap: {any})
	: number
	local ptr = offset
	local str = getTable()
	
	for i, key in keysMap do
		local val = dict[key]
		local strLen = string.len(val)
		buffer.writeu8(buff, ptr, strLen)
		ptr += 1
		str[i] = val
	end
	
	local largeStr = table.concat(str)
	local totalStrLen = string.len(largeStr)
	buffer.writestring(buff, ptr, largeStr, totalStrLen)
	ptr += totalStrLen
	recycleTable(str)
	return ptr - offset
end

@native local function decodeBulkStringDictStatic(buff: buffer, offset: number, keysMap: {any},
	template: {[string | number]: any}): ({[any]: string}, number)
	local ptr = offset
	local dictLen = #keysMap
	local strPtr = 1
	local totalLen = 0
	local dict = table.clone(template)
	local lens = getTable()
	
	for i = 1, dictLen do
		local len = buffer.readu8(buff, ptr)
		lens[i] = len
		totalLen += len
		ptr += 1
	end
	
	local largeStr = buffer.readstring(buff, offset + dictLen, totalLen)
	for i, key in keysMap do
		local start = strPtr
		strPtr += lens[i]
		dict[key] = string.sub(largeStr, start, strPtr - 1)
	end
	recycleTable(lens)
	return dict, strPtr - offset
end

@native local function encodeBulkNumberU8Dict(buff: buffer, offset: number, dict: {[any]: number}, keys: boolean?)
	: (number, number?)
	local ptr = offset
	local len
	
	if keys then
		for key, val in dict do
			buffer.writeu8(buff, ptr, key)
			ptr += 1
		end
		len = ptr - offset
	else
		for key, val in dict do
			buffer.writeu8(buff, ptr, val)
			ptr += 1
		end
	end
	return ptr - offset, len
end

@native local function encodeBulkNumberI32Dict(buff: buffer, offset: number, dict: {[any]: number}, keys: boolean?)
	: (number, number?)
	local ptr = offset
	local len

	if keys then
		for key, val in dict do
			buffer.writei32(buff, ptr, key)
			ptr += 4
		end
		len = ptr - offset
	else
		for key, val in dict do
			buffer.writei32(buff, ptr, val)
			ptr += 4
		end
	end
	return ptr - offset, len
end

@native local function encodeBulkNumberF32Dict(buff: buffer, offset: number, dict: {[any]: number}, keys: boolean)
	: (number, number?)
	local ptr = offset
	local len
	
	if keys then
		for key, val in dict do
			buffer.writef32(buff, ptr, key)
			ptr += 4
		end
		len = (ptr - offset) / 4
	else
		for key, val in dict do
			buffer.writef32(buff, ptr, val)
			ptr += 4
		end
	end
	return ptr - offset, len
end

@native local function encodeBulkBoolDict(buff: buffer, offset: number, dict: {[any]: boolean}, keys: boolean?)
	: (number, number?)
	local ptr = offset
	local len
	
	if keys then
		for key, val in dict do
			buffer.writeu8(buff, ptr, if key then 1 else 0)
			ptr += 1
		end
		len = ptr - offset
	else
		for key, val in dict do
			buffer.writeu8(buff, ptr, if val then 1 else 0)
			ptr += 1
		end
	end
	return ptr - offset, len
end

@native local function encodeBulkStringDict(buff: buffer, offset: number, dict: {[any]: string}, keys: boolean?)
	: (number, number?)
	local ptr = offset
	local str = getTable()
	local len
	if keys then
		len = 0
		for key, val in dict do
			local strLen = string.len(key)
			buffer.writeu8(buff, ptr, strLen)
			ptr += 1
			len += 1
			str[len] = key
		end
	else
		local count = 0
		for key, val in dict do
			local strLen = string.len(val)
			buffer.writeu8(buff, ptr, strLen)
			ptr += 1
			count += 1
			str[count] = val
		end
	end	
	
	local largeStr = table.concat(str)
	local bigStrLen = string.len(largeStr)
	buffer.writeu32(buff, ptr, bigStrLen)
	ptr += 4
	buffer.writestring(buff, ptr, largeStr, bigStrLen)
	ptr += bigStrLen
	recycleTable(str)
	return ptr - offset, len
end

local enumItems: {EnumItem} = {}
local enumItemsByEnum: {[EnumItem]: number} = {}
local encodeData: {[number]: (buffer, number, any, any?, any?) -> number}
local decodeData: {[number]: (buffer, number, any?, any?) -> (any, number)}

@native local function encodeEnumItem(buff: buffer, offset: number, arg: SchemaArg, value: EnumItem): number
	buffer.writeu16(buff, offset, enumItemsByEnum[value] or 0)
	return 2
end

@native local function decodeEnumItem(buff: buffer, offset: number, arg: SchemaArg): (EnumItem?, number)
	local idx = buffer.readu16(buff, offset)
	return enumItems[idx], 2
end

@native local function encodeInstance(buff: buffer, offset: number, arg: SchemaArg, value: Instance, inst: {Instance})
	: number
	inst[#inst + 1] = value
	return 0
end

@native local function decodeInstance(buff: buffer, offset: number, arg: SchemaArg, inst: {Instance})
	: (Instance, number)	
	local ptr = inst.pointer
	inst.pointer += 1
	return inst[ptr], 0
end

@native local function encodePlayer(buff: buffer, offset: number, arg: SchemaArg, value: Player): number
	buffer.writef64(buff, offset, value.UserId or 0)
	return 8
end

@native local function decodePlayer(buff: buffer, offset: number, arg: SchemaArg): (Player?, number)
	local player = Players:GetPlayerByUserId(buffer.readf64(buff, offset))
	return player, 8	
end

@native local function encodeFont(buff: buffer, offset: number, arg: SchemaArg, value: Font): number
	local family = value.Family
	local len = string.len(family)
	buffer.writeu8(buff, offset, len)
	offset += 1
	buffer.writestring(buff, offset, family, len)
	offset += len
	buffer.writeu16(buff, offset, value.Weight.Value)
	buffer.writeu8(buff, offset + 2, value.Style.Value)
	return 4 + len
end

@native local function decodeFont(buff: buffer, offset: number, arg: SchemaArg): (Font, number)
	local len = buffer.readu8(buff, offset)
	offset += 1
	local family = buffer.readstring(buff, offset, len)
	offset += len
	local font = Font.new(
		family,
		Enum.FontWeight:FromValue(buffer.readu16(buff, offset)),
		Enum.FontStyle:FromValue(buffer.readu8(buff, offset + 2))		
	)
	return font, 4 + len
end

@native local function encodeRay(buff: buffer, offset: number, arg: SchemaArg, value: Ray): number
	local origin = value.Origin
	local direction = value.Direction
	buffer.writef32(buff, offset, origin.X)
	buffer.writef32(buff, offset + 4, origin.Y)
	buffer.writef32(buff, offset + 8, origin.Z)
	buffer.writef32(buff, offset + 12, direction.X)
	buffer.writef32(buff, offset + 16, direction.Y)
	buffer.writef32(buff, offset + 20, direction.Z)
	return 24
end

@native local function decodeRay(buff: buffer, offset: number, arg: SchemaArg): (Ray, number)
	return Ray.new(
		Vector3.new(
			buffer.readf32(buff, offset),
			buffer.readf32(buff, offset + 4),
			buffer.readf32(buff, offset + 8)
		),
		Vector3.new(
			buffer.readf32(buff, offset + 12),
			buffer.readf32(buff, offset + 16),
			buffer.readf32(buff, offset + 20)
		)
	), 24
end

@native local function encodeAny(buff: buffer, offset: number, arg: SchemaArg, value: any, inst: {Instance}): number
	local dataType = getDataType(value)
	buffer.writeu8(buff, offset, dataType)
	local bytes = 1
	local encode = encodeData[dataType] :: ((buffer, number, SchemaArg, any, {Instance}?) -> number)?
	bytes += encode(buff, offset + bytes, arg, value, inst)
	return bytes
end

@native local function decodeAny(buff: buffer, offset: number, arg: SchemaArg, inst: {Instance}?): (any, number)
	local dataType = buffer.readu8(buff, offset)
	local bytes = 1
	local decode = decodeData[dataType] :: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
	if not decode then
		return nil, 1
	end
	local val, b = decode(buff, offset + bytes, arg, inst)
	return val, bytes + b
end

@native local function encodeOptional(buff: buffer, offset: number, arg: SchemaArg, value: any, inst: {Instance}?)
	: number
	local isNil = value == nil
	local tag = isNil and 0 or 1
	buffer.writeu8(buff, offset, tag)
	if isNil then
		return 1
	end
	
	local valArg = arg[2]
	local encode = encodeData[valArg] or encodeData[valArg[1]] :: (buffer, number, SchemaArg, any, {Instance}?) -> number
	local bytes = encode(buff, offset + 1, valArg, value, inst)
	return bytes + 1
end

@native local function decodeOptional(buff: buffer, offset: number, arg: SchemaArg, inst: {Instance}?)
	: (any, number)
	local isNil = buffer.readu8(buff, offset) == 0
	if isNil then return nil, 1 end
	
	local valArg = arg[2]
	local decode = decodeData[valArg] or decodeData[valArg[1]] :: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
	local val, b = decode(buff, offset + 1, valArg, inst)
	return val, b + 1
end

@native local function encodeUnion(buff: buffer, offset: number, arg: SchemaArg, value: any, inst: {Instance})
	: number
	local dt = typeof(value)
	local valArg = arg[dt]
	local tag = dt ~= "table" and valArg or valArg[1]
	buffer.writeu8(buff, offset, tag)
	
	local encode = encodeData[tag] :: (buffer, number, SchemaArg, any, {Instance}?) -> number
	local bytes = encode(buff, offset + 1, valArg, value, inst)
	return bytes + 1
end

@native local function decodeUnion(buff: buffer, offset: number, arg: SchemaArg, inst: {Instance}?): (any, number)
	local tag = buffer.readu8(buff, offset)
	local valArg = arg[tag]
	local decode = decodeData[tag] :: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
	local val, b = decode(buff, offset + 1, valArg, inst)
	return val, b + 1
end

@native local function encodeLiteral(buff: buffer, offset: number, arg: SchemaArg, value: Literal)
	:number
	local reverseMap = arg[3]
	buffer.writeu8(buff, offset, reverseMap[value])
	return 1
end

@native local function decodeLiteral(buff: buffer, offset: number, arg: SchemaArg): (Literal, number)
	local map = arg[2]
	return map[buffer.readu8(buff, offset)], 1
end

@native local function encodeCustom(buff: buffer, offset: number, schema: SchemaArg, value: any, inst: {Instance})
	: number
	local encode = schema[2]
	local metadata = schema[4]
	return encode(buff, offset, value, inst, metadata)
end

@native local function decodeCustom(buff: buffer, offset: number, schema: SchemaArg, inst: {Instance}?): (any, number)
	local decode = schema[3]
	local metadata = schema[4]
	return decode(buff, offset, inst, metadata)
end

@native local function encodeArrayStatic(buff: buffer, offset: number, schema: SchemaArg, array: {any}, inst: {Instance})
	: number
	local ptr = offset
	local fastPath = schema[3]
	
	if fastPath then
		ptr += encodeData[fastPath](buff, ptr, array)
		return ptr - offset
	end
	
	for idx, arg: SchemaArg in schema[2] do
		local encode = (encodeData[arg] or encodeData[arg[1]])
		:: (buffer, number, SchemaArg, any, {Instance}?) -> number
		ptr += encode(buff, ptr, arg, array[idx], inst)
	end
	return ptr - offset
end

@native local function decodeArrayStatic(buff: buffer, offset: number, schema: {SchemaArg}, inst: {Instance}?)
	: ({any}, number)
	local ptr = offset
	local data = schema[2]
	local fastPath = schema[3]
	
	if fastPath then
		local array, b = decodeData[fastPath](buff, ptr, #data)
		return array, ptr + b - offset
	end
	
	local array = {}
	for i, arg: SchemaArg in data do
		local decode = (decodeData[arg] or decodeData[arg[1]])
		:: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
		local val, b = decode(buff, ptr, arg, inst)
		ptr += b
		array[i] = val
	end
	return array, ptr - offset
end

@native local function encodeBulkStructArray(buff: buffer, offset: number, array: {any}, _: boolean, schema: SchemaArg, 
	inst: {Instance}, isDict: boolean?): number
	local structSchema = isDict and schema[3] or schema[2]
	local keysMap = structSchema[3]
	local fastPath = structSchema[5]
	local ptr = offset
	
	if fastPath then
		local encode = encodeData[fastPath]
		for _, struct in array do
			ptr += encode(buff, ptr, struct, keysMap)
		end
		return ptr - offset
	end
	
	local data = structSchema[2]
	for _, struct in array do
		for i, key in keysMap do
			local arg = data[i]
			local val = struct[key]
			local encode = (encodeData[arg] or encodeData[arg[1]]) :: 
			(buffer, number, SchemaArg, any, {Instance}?) -> number
			ptr += encode(buff, ptr, arg, val, inst)
		end
	end
	return ptr - offset
end

@native local function decodeBulkStructArray(buff: buffer, offset: number, len: number, tbl: {any}?, schema: SchemaArg, inst: {Instance}?,
	isDict: boolean?)
	: ({any}, number)
	local ptr = offset
	local structSchema = isDict and schema[3] or schema[2]
	local keysMap = structSchema[3]
	local template = structSchema[4]
	local fastPath = structSchema[5]
	
	local array = tbl or table.create(len)
	if fastPath then
		local decode = decodeData[fastPath]
		for i = 1, len do
			local struct, b = decode(buff, ptr, keysMap, template)
			ptr += b
			array[i] = struct
		end
		return array, ptr - offset
	end
	
	local data = structSchema[2]
	
	for i = 1, len do
		local struct = table.clone(template)	
		for i, arg in data do
			local decode = (decodeData[arg] or decodeData[arg[1]])
			:: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
			local val, b = decode(buff, ptr, arg, inst)
			ptr += b
			local key = keysMap[i]
			struct[key] = val
		end
		array[i] = struct
	end	
	return array, ptr - offset
end

@native local function encodeArray(buff: buffer, offset: number, schema: SchemaArg, array: {any}, inst: {Instance})
	: number
	local len = #array
	buffer.writeu16(buff, offset, len)
	local ptr = offset + 2
	
	local fastPath = schema[3]
	if fastPath then
		ptr += encodeData[fastPath](buff, ptr, array, false, schema, inst)
		return ptr - offset
	end
	
	local arg = schema[2]
	local encode = (encodeData[arg] or encodeData[arg[1]]) :: (buffer, number, SchemaArg, any, {Instance}?) -> number
	for i, value in array do
		ptr += encode(buff, ptr, arg, value, inst)
	end
	return ptr - offset
end

@native local function decodeArray(buff: buffer, offset: number, schema: SchemaArg, inst: {Instance}?): ({any}, number)
	local len = buffer.readu16(buff, offset)
	local ptr = offset + 2
	
	local fastPath = schema[3]
	if fastPath then
		local array, b = decodeData[fastPath](buff, ptr, len, nil, schema, inst)
		return array, ptr + b - offset
	end
	
	local arg = schema[2]
	local decode = (decodeData[arg] or decodeData[arg[1]])
	:: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
	local array = table.create(len)
	for i = 1, len do
		local val, b = decode(buff, ptr, arg, inst)
		ptr += b
		array[i] = val
	end
	return array, ptr - offset
end

@native local function encodeArrayDynamic(buff: buffer, offset: number, schema: SchemaArg, array: {any}, inst: {Instance})
	: number
	local len = #array
	buffer.writeu16(buff, offset, len)
	local ptr = offset + 2

	for i = 1, len do
		local val = array[i]
		local dataType = getDataType(val)
		buffer.writeu8(buff, ptr, dataType)
		ptr += 1
		local encode = encodeData[dataType] :: (buffer, number, SchemaArg, any, {Instance}?) -> number
		ptr += encode(buff, ptr, schema, val, inst)
	end
	return ptr - offset
end

@native local function decodeArrayDynamic(buff: buffer, offset: number, schema: SchemaArg, inst: {Instance}?)
	: ({any}, number)
	local len = buffer.readu16(buff, offset)
	local ptr = offset + 2
	local array = table.create(len)

	for i = 1, len do
		local dataType = buffer.readu8(buff, ptr)
		ptr += 1
		local decode = (decodeData[dataType] or decodeData[ENUM_NIL])
		:: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
		local val, b = decode(buff, ptr, schema, inst)
		ptr += b
		array[i] = val
	end
	return array, ptr - offset
end

@native local function encodeDictStatic(buff: buffer, offset: number, schema: SchemaArg, dict: {[string | number]: any},
	inst: {Instance}): number
	local ptr = offset
	local data = schema[2]
	local keysMap = schema[3]
	local fastPath = schema[5]
	
	if fastPath then
		ptr += encodeData[fastPath](buff, ptr, dict, keysMap)
		return ptr - offset
	end
	
	local idx = 0	
	for i, key in keysMap do
		idx += 1
		local arg = data[idx]
		local val = dict[key]
		local encode = (encodeData[arg] or encodeData[arg[1]]) :: 
		(buffer, number, SchemaArg, any, {Instance}?) -> number
		ptr += encode(buff, ptr, arg, val, inst)
	end
	return ptr - offset
end

@native local function decodeDictStatic(buff: buffer, offset: number, schema: SchemaArg, inst: {Instance}?)
	: ({[number | string]: any}, number)
	local ptr = offset
	local data = schema[2]
	local keysMap = schema[3]
	local template = schema[4]
	local fastPath = schema[5]
	
	if fastPath then
		local values, b = decodeData[fastPath](buff, ptr, keysMap, template)
		ptr += b
		return values, ptr - offset
	end
	
	local dict = table.clone(template)	
	for i, arg in data do
		local decode = (decodeData[arg] or decodeData[arg[1]])
		:: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
		local val, b = decode(buff, ptr, arg, inst)
		ptr += b
		local key = keysMap[i]
		dict[key] = val
	end
	return dict, ptr - offset
end

@native local function encodeDict(buff: buffer, offset: number, schema: SchemaArg, dict: {[any]: any}, inst: {Instance})
	: number
	local len = 0
	local ptr = offset + 2	
	local keyFastPath = schema[4]
	local valFastPath = schema[5]
	
	if keyFastPath then
		local bytes
		bytes, len = encodeData[keyFastPath](buff, ptr, dict, true)
		ptr += bytes
	else
		local keyArg = schema[2]
		local encodeKey = (encodeData[keyArg] or encodeData[keyArg[1]])
		:: (buffer, number, SchemaArg, any, {Instance}?) -> number
		for key, val in dict do
			ptr += encodeKey(buff, ptr, keyArg, key, inst)
			len += 1
		end
	end
	
	if valFastPath then
		ptr += encodeData[valFastPath](buff, ptr, dict, false, schema, inst, true)
	else
		local valArg = schema[3]
		local encodeVal = encodeData[valArg] or encodeData[valArg[1]] 
		:: (buffer, number, SchemaArg, any, {Instance}?) -> number
		for key, val in dict do
			ptr += encodeVal(buff, ptr, valArg, val, inst)
		end
	end

	buffer.writeu16(buff, offset, len)
	return ptr - offset
end

local dictTempCache: {[number]: {[any]: any}} = {}

@native local function decodeDict(buff: buffer, offset: number, schema: SchemaArg, inst: {Instance}?): ({[any]: any}, number)
	local len = buffer.readu16(buff, offset)
	local ptr = offset + 2	
	local keyFastPath = schema[4]
	local valFastPath = schema[5]	
	local keys, vals = getTable(), getTable()
	
	if keyFastPath then
		local bytes
		keys, bytes = decodeData[keyFastPath](buff, ptr, len, keys, schema, inst)
		ptr += bytes
	else
		local keyArg = schema[2]
		local decodeKey = (decodeData[keyArg] or decodeData[keyArg[1]])
		:: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
		for i = 1, len do
			local key, b = decodeKey(buff, ptr, keyArg, inst)
			ptr += b
			keys[i] = key
		end
	end
	
	if valFastPath then
		local bytes
		vals, bytes = decodeData[valFastPath](buff, ptr, len, vals, schema, inst, true)
		ptr += bytes
	else
		local valArg = schema[3]
		local decodeVal = decodeData[valArg] or decodeData[valArg[1]] 
		:: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
		for i = 1, len do
			local val, b = decodeVal(buff, ptr, valArg, inst)
			ptr += b
			vals[i] = val
		end
	end
	
	local dictId = schema[6]
	local template = dictTempCache[dictId]
	local dict
	if template then
		table.clear(template)
		dict = table.clone(template)
	else
		dict = {}
	end

	for i, key in keys do
		dict[key] = vals[i]
	end
	recycleTable(keys)
	recycleTable(vals)
	if not template then
		dictTempCache[dictId] = table.clone(dict)
	end
	return dict, ptr - offset
end

@native local function encodeDictDynamic(buff: buffer, offset: number, schema: SchemaArg, dict: {[any]: any},
	inst: {Instance}): number
	local startOffset = offset
	local ptr = offset + 2
	local idx = 0

	for key, val in dict do
		local keyType = getDataType(key)	
		local encodeKey = encodeData[keyType] ::  (buffer, number, SchemaArg, any, {Instance}?) -> number
		buffer.writeu8(buff, ptr, keyType)			
		ptr += 1
		ptr += encodeKey(buff, ptr, schema, key, inst)
		
		local valType = getDataType(val)
		local encodeVal = encodeData[valType] :: (buffer, number, SchemaArg, any, {Instance}?) -> number
		buffer.writeu8(buff, ptr, valType)
		ptr += 1
		ptr += encodeVal(buff, ptr, schema, val, inst)
		idx += 1
	end
	buffer.writeu16(buff, offset, idx)
	return ptr - offset
end

@native local function decodeDictDynamic(buff: buffer, offset: number, schema: SchemaArg, inst: {Instance}?)
	: ({[any]: any}, number)
	local len = buffer.readu16(buff, offset)
	local ptr = offset + 2
	local dict = {}

	for i = 1, len do
		local keyType = buffer.readu8(buff, ptr)
		ptr += 1
		local decodeKey = (decodeData[keyType] or decodeData[ENUM_NIL])
		:: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
		local key, b = decodeKey(buff, ptr, schema, inst)
		ptr += b

		local valType = buffer.readu8(buff, ptr)
		ptr += 1
		local decodeVal = (decodeData[valType] or decodeData[ENUM_NIL])
		:: (buffer, number, SchemaArg, {Instance}?) -> (any, number)
		local val, b = decodeVal(buff, ptr, schema, inst)
		ptr += b
		dict[key] = val
	end
	return dict, ptr - offset
end

encodeData = {
	[Enums.Start] = function() end,
	[Enums.NumberU4] = encodeNumberU8,
	[Enums.NumberU8] = encodeNumberU8,
	[Enums.NumberU16] = encodeNumberU16,
	[Enums.NumberU32] = encodeNumberU32,
	[Enums.NumberI8] = encodeNumberI8,
	[Enums.NumberI16] = encodeNumberI16,
	[Enums.NumberI32] = encodeNumberI32,
	[Enums.NumberF16] = encodeNumberF16,
	[Enums.NumberF32] = encodeNumberF32,
	[Enums.NumberF64] = encodeNumberF64,

	[Enums.CFrameFX8] = encodeCFrameFX8,
	[Enums.CFrameI16FX16] = encodeCFrameI16FX16,
	[Enums.CFrameFX16] = encodeCFrameFX16,
	[Enums.CFrameF16] = encodeCFrameF16,
	[Enums.CFrameF32Aligned] = encodeCFrameF32Aligned,
	[Enums.CFrameF32FX16] = encodeCFrameF32FX16,
	[Enums.CFrameF32] = encodeCFrameF32,

	[Enums.Vector3FX8] = encodeVector3FX8,
	[Enums.Vector3I16] = encodeVector3I16,
	[Enums.Vector3FX16] = encodeVector3FX16,
	[Enums.Vector3F16] = encodeVector3F16,
	[Enums.Vector3F32] = encodeVector3F32,

	[Enums.Vector2FX8] = encodeVector2FX8,
	[Enums.Vector2I16] = encodeVector2I16,
	[Enums.Vector2FX16] = encodeVector2FX16,
	[Enums.Vector2F16] = encodeVector2F16,
	[Enums.Vector2F32] = encodeVector2F32,

	[Enums.String] = encodeString,
	[Enums.StringLong] = encodeStringLong,
	[Enums.Color3] = encodeColor,
	[Enums.BrickColor] = encodeBrickColor,
	[Enums.Boolean] = encodeBool,
	[Enums.Nil] = encodeNil,
	[Enums.Buffer] = encodeBuffer,
	[Enums.EnumItem] = encodeEnumItem,
	[Enums.Instance] = encodeInstance,
	[Enums.Player] = encodePlayer,
	[Enums.DateTime32] = encodeDateTime32,
	[Enums.DateTime64] = encodeDateTime64,
	[Enums.TweenInfo] = encodeTweenInfo,
	[Enums.ColorSequence] = encodeColorSequence,
	[Enums.NumberSequence] = encodeNumberSequence,
	[Enums.NumberRange] = encodeNumberRange,
	[Enums.UDim] = encodeUDim,
	[Enums.UDim2] = encodeUDim2,
	[Enums.Region3] = encodeRegion3,
	[Enums.PhysicalProperties] = encodePhysicalProperties,
	[Enums.Rect] = encodeRect,
	[Enums.Font] = encodeFont,
	[Enums.Ray] = encodeRay,

	[Enums.Any] = encodeAny,
	[Enums.Optional] = encodeOptional,
	[Enums.Union] = encodeUnion,
	[Enums.Literal] = encodeLiteral,
	[Enums.Custom] = encodeCustom,
	
	[Enums.ArrayStatic] = encodeArrayStatic,
	[Enums.Array] = encodeArray,
	[Enums.ArrayDynamic] = encodeArrayDynamic,
	[Enums.DictStatic] = encodeDictStatic,
	[Enums.Dict] = encodeDict,
	[Enums.DictDynamic] = encodeDictDynamic,
	
	[Enums.FastNumberU4Array] = encodeBulkNumberU4Array,
	[Enums.FastNumberU8Array] = encodeBulkNumberU8Array,
	[Enums.FastNumberI32Array] = encodeBulkNumberI32Array,
	[Enums.FastNumberF32Array] = encodeBulkNumberF32Array,
	[Enums.FastBoolArray] = encodeBulkBoolArray,
	[Enums.FastStringArray] = encodeBulkStringArray,
	[Enums.FastStructArray] = encodeBulkStructArray,
	[Enums.FastNumberU8DictStatic] = encodeBulkNumberU8DictStatic,
	[Enums.FastNumberI32DictStatic] = encodeBulkNumberI32DictStatic,
	[Enums.FastNumberF32DictStatic] = encodeBulkNumberF32DictStatic,
	[Enums.FastBoolDictStatic] = encodeBulkBoolDictStatic,
	[Enums.FastStringDictStatic]= encodeBulkStringDictStatic,
	[Enums.FastNumberU8Dict] = encodeBulkNumberU8Dict,
	[Enums.FastNumberI32Dict] = encodeBulkNumberI32Dict,
	[Enums.FastNumberF32Dict] = encodeBulkNumberF32Dict,
	[Enums.FastBoolDict] = encodeBulkBoolDict,
	[Enums.FastStringDict] = encodeBulkStringDict,
	[Enums.FastStructDict] = encodeBulkStructArray,
}

decodeData = {
	[Enums.Start] = function() end,
	[Enums.NumberU4] = decodeNumberU8,
	[Enums.NumberU8] = decodeNumberU8,
	[Enums.NumberU16] = decodeNumberU16,
	[Enums.NumberU32] = decodeNumberU32,
	[Enums.NumberI8] = decodeNumberI8,
	[Enums.NumberI16] = decodeNumberI16,
	[Enums.NumberI32] = decodeNumberI32,
	[Enums.NumberF16] = decodeNumberF16,
	[Enums.NumberF32] = decodeNumberF32,
	[Enums.NumberF64] = decodeNumberF64,

	[Enums.CFrameFX8] = decodeCFrameFX8,
	[Enums.CFrameI16FX16] = decodeCFrameI16FX16,
	[Enums.CFrameFX16] = decodeCFrameFX16,
	[Enums.CFrameF16] = decodeCFrameF16,
	[Enums.CFrameF32Aligned] = decodeCFrameF32Aligned,
	[Enums.CFrameF32FX16] = decodeCFrameF32FX16,
	[Enums.CFrameF32] = decodeCFrameF32,

	[Enums.Vector3FX8] = decodeVector3FX8,
	[Enums.Vector3I16] = decodeVector3I16,
	[Enums.Vector3FX16] = decodeVector3FX16,
	[Enums.Vector3F16] = decodeVector3F16,
	[Enums.Vector3F32] = decodeVector3F32,

	[Enums.Vector2FX8] = decodeVector2FX8,
	[Enums.Vector2I16] = decodeVector2I16,
	[Enums.Vector2FX16] = decodeVector2FX16,
	[Enums.Vector2F16] = decodeVector2F16,
	[Enums.Vector2F32] = decodeVector2F32,

	[Enums.String] = decodeString,
	[Enums.StringLong] = decodeStringLong,
	[Enums.Color3] = decodeColor,
	[Enums.BrickColor] = decodeBrickColor,
	[Enums.Boolean] = decodeBool,
	[Enums.Nil] = decodeNil,
	[Enums.Buffer] = decodeBuffer,
	[Enums.EnumItem] = decodeEnumItem,
	[Enums.Instance] = decodeInstance,
	[Enums.Player] = decodePlayer,
	[Enums.DateTime32] = decodeDateTime32,
	[Enums.DateTime64] = decodeDateTime64,
	[Enums.TweenInfo] = decodeTweenInfo,
	[Enums.ColorSequence] = decodeColorSequence,
	[Enums.NumberSequence] = decodeNumberSequence,
	[Enums.NumberRange] = decodeNumberRange,
	[Enums.UDim] = decodeUDim,
	[Enums.UDim2] = decodeUDim2,
	[Enums.Region3] = decodeRegion3,
	[Enums.PhysicalProperties] = decodePhysicalProperties,
	[Enums.Rect] = decodeRect,
	[Enums.Font] = decodeFont,
	[Enums.Ray] = decodeRay,

	[Enums.Any] = decodeAny,
	[Enums.Optional] = decodeOptional,
	[Enums.Union] = decodeUnion,
	[Enums.Literal] = decodeLiteral,
	[Enums.Custom] = decodeCustom,
	
	[Enums.ArrayStatic] = decodeArrayStatic,
	[Enums.Array] = decodeArray,
	[Enums.ArrayDynamic] = decodeArrayDynamic,
	[Enums.DictStatic] = decodeDictStatic,
	[Enums.Dict] = decodeDict,
	[Enums.DictDynamic] = decodeDictDynamic,
	
	[Enums.FastNumberU4Array] = decodeBulkNumberU4Array,
	[Enums.FastNumberU8Array] = decodeBulkNumberU8Array,
	[Enums.FastNumberI32Array] = decodeBulkNumberI32Array,
	[Enums.FastNumberF32Array] = decodeBulkNumberF32Array,
	[Enums.FastBoolArray] = decodeBulkBoolArray,
	[Enums.FastStringArray] = decodeBulkStringArray,
	[Enums.FastStructArray] = decodeBulkStructArray,
	[Enums.FastNumberU8DictStatic] = decodeBulkNumberU8DictStatic,
	[Enums.FastNumberI32DictStatic] = decodeBulkNumberI32DictStatic,
	[Enums.FastNumberF32DictStatic] = decodeBulkNumberF32DictStatic,
	[Enums.FastBoolDictStatic] = decodeBulkBoolDictStatic,
	[Enums.FastStringDictStatic] = decodeBulkStringDictStatic,
	[Enums.FastNumberU8Dict] = decodeBulkNumberU8Array,
	[Enums.FastNumberI32Dict] = decodeBulkNumberI32Array,
	[Enums.FastNumberF32Dict] = decodeBulkNumberF32Array,
	[Enums.FastBoolDict] = decodeBulkBoolArray,
	[Enums.FastStringDict] = decodeBulkStringArray,
	[Enums.FastStructDict] = decodeBulkStructArray,
}

return {
	encode = encodeData,
	decode = decodeData,
	enumItems = enumItems,
	enumItemsByEnum = enumItemsByEnum,
}