--!strict

local ServiceModule = require(script.Service.Service)
local ControllerModule = require(script.Controller.Controller)
local EnumsModule = require(script.Enums)
local VendorsModule = require(script.Vendors)

export type Service<T = any> = ServiceModule.Service<T>
export type Controller<T = any> = ControllerModule.Controller<T>

export type ReliabilityEnum = EnumsModule.ReliabilityTypeEnum
export type NetworkNamespaceEnum = EnumsModule.NetworkNamespaceEnum

export type Logger = VendorsModule.Logger
export type LogItem = VendorsModule.LogItem

export type Signal<T...> = VendorsModule.Signal<T...>
export type Connection = VendorsModule.Connection

return nil
