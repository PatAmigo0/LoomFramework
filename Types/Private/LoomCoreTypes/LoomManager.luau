--!strict

local TableTypes = require(script.Parent.Table)

export type LoomManager<BaseType> = {
	Register: <I>(item: I, params: any?) -> I,

	Get: (name: string) -> BaseType | nil,
	Start: () -> (),
	_items: TableTypes.AnyGenericTable<BaseType>,
}

return nil
