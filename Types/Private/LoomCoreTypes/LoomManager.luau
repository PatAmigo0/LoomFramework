--!strict

export type LoomManager<T> = {
	Register: (item: T, params: { [any]: any }?) -> T,
	Get: (name: string) -> T | nil,
	Start: () -> (),
	_items: { [string]: T? },
}

return nil
