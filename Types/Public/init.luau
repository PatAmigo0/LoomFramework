--!strict

local ComponentModule = require(script.Component)
local EnumsModule = require(script.Enums)
local VendorsModule = require(script.Vendors)
local LoomSchema = require(script.LoomSchema)

export type LoomSchema<T = {}, N = nil> = LoomSchema.LoomSchema<T, N>
export type LoomClass<T = {}, N = nil> = LoomSchema.LoomClass<T, N>
export type LoomNet<Net> = LoomSchema.LoomNet<Net>

export type ComponentInstance<T, I = Instance> = ComponentModule.ComponentInstance<T, I>
export type ComponentClass<T, I = Instance> = ComponentModule.ComponentClass<T, I>
export type ComponentDef<T = {}, I = Instance> = ComponentModule.ComponentDef<T, I>

export type ReliabilityEnum = EnumsModule.ReliabilityTypeEnum
export type NetworkNamespaceEnum = EnumsModule.NetworkNamespaceEnum

export type Logger = VendorsModule.Logger
export type LogItem = VendorsModule.LogItem

export type Signal<T...> = VendorsModule.Signal<T...>
export type Connection = VendorsModule.Connection

return nil
