--!strict

local CoreComponents = {}

CoreComponents.Service = require(script.Service)
CoreComponents.ServiceManager = require(script.Service.Manager)

CoreComponents.Controller = require(script.Controller)
CoreComponents.ControllerManager = require(script.Controller.Manager)

CoreComponents.Component = require(script.Component)

return table.freeze(CoreComponents)
