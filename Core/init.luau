--!strict

local CoreComponents = {}

CoreComponents.ServiceManager = require(script.Service.Manager)
CoreComponents.ControllerManager = require(script.Controller.Manager)
CoreComponents.Component = require(script.Component)

return table.freeze(CoreComponents)
