--!strict

export type LoomMember<T = any> = {
	Name: string,
	Priority: number?,
	LoomInit: ((self: T) -> ())?,
	LoomStart: ((self: T) -> ())?,
}

return nil
