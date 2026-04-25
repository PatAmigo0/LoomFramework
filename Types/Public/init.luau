--!strict

local ServiceModule = require(script.Service)
local ControllerModule = require(script.Controller)
local ComponentModule = require(script.Component)
local EnumsModule = require(script.Enums)
local VendorsModule = require(script.Vendors)

export type Service<T = any> = ServiceModule.Service<T>
export type Controller<T = any> = ControllerModule.Controller<T>

export type ComponentInstance<T, I = Instance> = ComponentModule.ComponentInstance<T, I>
export type ComponentClass<T, I = Instance> = ComponentModule.ComponentClass<T, I>
export type ComponentDef = ComponentModule.ComponentDef

export type ReliabilityEnum = EnumsModule.ReliabilityTypeEnum
export type NetworkNamespaceEnum = EnumsModule.NetworkNamespaceEnum

export type Logger = VendorsModule.Logger
export type LogItem = VendorsModule.LogItem

export type Signal<T...> = VendorsModule.Signal<T...>
export type Connection = VendorsModule.Connection

return nil
