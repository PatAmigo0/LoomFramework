--!strict
local TableTypes = require(script.Parent.Table)

export type LoomManager<T> = {
	Register: (item: T, params: TableTypes.AnyTable?) -> T,
	Get: (name: string) -> T | nil,
	Start: () -> (),
	_items: TableTypes.AnyGenericTable<T>,
}

return nil
