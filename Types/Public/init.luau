--!strict

local ServiceModule = require(script.Service.Service)
local ControllerModule = require(script.Controller.Controller)
local EnumsModule = require(script.Enums)
local UtilsModule = require(script.Utils)

export type Service<T = any> = ServiceModule.Service<T>
export type Controller<T = any> = ControllerModule.Controller<T>

export type ReliabilityEnum = EnumsModule.ReliabilityTypeEnum
export type NetworkNamespaceEnum = EnumsModule.NetworkNamespaceEnum

export type Logger = UtilsModule.Logger

return nil
