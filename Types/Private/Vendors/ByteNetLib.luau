--!strict

-- Shape of a ByteNet Schema (read/write objects)
export type dataTypeInterface<T> = {
	write: (value: T) -> (),
	read: (b: buffer, cursor: number) -> (T, number),
	length: number?,
}

-- Alias
export type Schema = dataTypeInterface<any>

-- Props for creating a packet
export type packetProps<T> = {
	value: dataTypeInterface<T>,
	reliabilityType: ("reliable" | "unreliable")?,
	callbackBehavior: {
		spawnThread: boolean,
		allowMultiple: boolean,
	}?,
}

-- Packet object
export type Packet<T> = {
	sendToAll: (data: T) -> (),
	sendTo: (data: T, target: Player) -> (),
	sendToList: (data: T, targets: { Player }) -> (),
	sendToAllExcept: (data: T, exceptions: Player) -> (),

	wait: () -> T,
	send: (data: T, target: Player?) -> (),
	listen: (callback: (data: T, player: Player?) -> ()) -> (),
}

-- ByteNet
export type ByteNet = {
	definePacket: <T>(props: packetProps<T>) -> Packet<T>,
	defineNamespace: <T>(name: string, namespace: () -> T) -> T,

	-- Structure creators
	struct: <T>(format: T) -> dataTypeInterface<any>,
	array: <T>(value: dataTypeInterface<T>) -> dataTypeInterface<{ [number]: T }>,
	optional: <T>(value: dataTypeInterface<T>) -> dataTypeInterface<T?>,
	map: <K, V>(key: dataTypeInterface<K>, value: dataTypeInterface<V>) -> dataTypeInterface<{ [K]: V }>,

	-- Primitive Schemas
	bool: dataTypeInterface<boolean>,
	string: dataTypeInterface<string>,
	buff: dataTypeInterface<buffer>,
	inst: dataTypeInterface<Instance?>,
	cframe: dataTypeInterface<CFrame>,
	vec3: dataTypeInterface<Vector3>,
	vec2: dataTypeInterface<Vector2>,

	-- Numeric Schemas
	uint8: dataTypeInterface<number>,
	uint16: dataTypeInterface<number>,
	uint32: dataTypeInterface<number>,
	int8: dataTypeInterface<number>,
	int16: dataTypeInterface<number>,
	int32: dataTypeInterface<number>,
	float32: dataTypeInterface<number>,
	float64: dataTypeInterface<number>,

	-- Special
	nothing: dataTypeInterface<nil>,
	unknown: dataTypeInterface<unknown>,
}

return nil
