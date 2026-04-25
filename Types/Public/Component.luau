--!strict

local LoomRoot = script.Parent.Parent.Parent
local Logger = require(LoomRoot.Vendors.Logger)
local Trove = require(LoomRoot.Vendors.Trove)
local Promise = require(LoomRoot.Vendors.Promise)
local Signal = require(LoomRoot.Vendors.Signal)

export type ComponentDef<T = {}, I = Instance> = T & {
	Tag: string,
	Ancestors: { Instance }?,
	Extensions: { any }?,

	LoomInit: ((self: ComponentInstance<T, I>) -> ())?,
	LoomStart: ((self: ComponentInstance<T, I>) -> ())?,
	LoomDestroy: ((self: ComponentInstance<T, I>) -> ())?,

	Construct: ((self: ComponentInstance<T, I>) -> ())?,
	Start: ((self: ComponentInstance<T, I>) -> ())?,
	Stop: ((self: ComponentInstance<T, I>) -> ())?,
	HeartbeatUpdate: ((self: ComponentInstance<T, I>, dt: number) -> ())?,
	SteppedUpdate: ((self: ComponentInstance<T, I>, dt: number) -> ())?,
	RenderSteppedUpdate: ((self: ComponentInstance<T, I>, dt: number) -> ())?,
}

export type ComponentInstance<T, I = Instance> = T & {
	Instance: I,
	Trove: Trove.Trove,
	Debugger: Logger.LogItem,

	GetComponent: (self: ComponentInstance<T, I>, componentClass: { Tag: string, [any]: any }) -> any,
}

export type ComponentClass<T, I = Instance> = {
	Tag: string,

	Started: Signal.Signal<ComponentInstance<T, I>>,
	Stopped: Signal.Signal<ComponentInstance<T, I>>,

	GetAll: (self: ComponentClass<T, I>) -> { ComponentInstance<T, I> },

	FromInstance: (self: ComponentClass<T, I>, instance: Instance) -> ComponentInstance<T, I>?,

	WaitForInstance: (
		self: ComponentClass<T, I>,
		instance: Instance,
		timeout: number?
	) -> Promise.TypedPromise<ComponentInstance<T, I>>,
}

return nil
