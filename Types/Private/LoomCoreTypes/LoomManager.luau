--!strict

export type LoomManager<T> = {
	Register: (item: T) -> T,
	Get: (name: string) -> T | nil,
	Start: () -> (),
	_items: { [string]: T? },
}

return nil
