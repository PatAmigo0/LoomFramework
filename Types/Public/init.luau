--!strict

local ServiceModule = require(script.Service.Service)
local ControllerModule = require(script.Controller.Controller)
local PacketDefModule = require(script.Packet.PacketDef)
local EnumsModule = require(script.Enums)
local UtilsModule = require(script.Utils)

export type Service<T = any> = ServiceModule.Service<T>
export type Controller<T = any> = ControllerModule.Controller<T>

export type ServiceDef = ServiceModule.ServiceDef
export type ControllerDef = ControllerModule.ControllerDef
export type PacketDef<T> = PacketDefModule.PacketDef<T>

export type ReliabilityType = EnumsModule.ReliabilityTypeEnum

export type Logger = UtilsModule.Logger

return nil
