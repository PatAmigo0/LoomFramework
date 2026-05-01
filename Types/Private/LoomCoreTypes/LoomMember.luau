--!strict

export type LoomMember<T = {}> = {
	Name: string,
	Priority: number?,
	LoomInit: ((self: T) -> ())?,
	LoomStart: ((self: T) -> ())?,
}

return nil
