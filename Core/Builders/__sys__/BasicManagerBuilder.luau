--!strict
local LoomRoot = script.Parent.Parent.Parent.Parent -- script.__sys__.Builders.Core.Loom

local PrivateTypes = require(LoomRoot.Types.Private)
local Logger = require(LoomRoot.Vendors.Logger)
local Promise = require(LoomRoot.Vendors.Promise)
local Sift = require(LoomRoot.Vendors.Sift)

local Array = Sift.Array
local Dictionary = Sift.Dictionary
local logger = Logger.new()

local function runLifecycle(item: any, methodName: string): boolean
	local method = item[methodName]

	if type(method) ~= "function" then
		if method then
			logger:AtWarning():Log("Skipping because item is not a function")
			logger:AtWarning():Log(method)
		end

		return true -- we've ran nothing so basically we've  passed
	end

	local success, err = xpcall(function()
		method(item)
	end, debug.traceback)

	if not success then
		logger:AtWarning():Log(`Failed to run {methodName} for {item.Name}: {err}`)
		return false
	end

	return true
end

local function normalizeItem(item: PrivateTypes.LoomMember)
	if not item.Priority then
		item.Priority = 0
	end
end

local function fillItem(item: PrivateTypes.LoomMember, params: { [any]: any? }?)
	if not params then
		return
	end

	for key, value in params do
		item[key] = value
	end
end

local ManagerBuilder = {}
ManagerBuilder.__index = ManagerBuilder

function ManagerBuilder.new<T>(options: PrivateTypes.BuilderOptions): PrivateTypes.LoomManager<T>
	return ManagerBuilder._buildManager(options)
end

function ManagerBuilder._buildManager<T>(options: PrivateTypes.BuilderOptions): PrivateTypes.LoomManager<T>
	local ModuleName = options.Name
	local InitMethod = options.InitMethod or "LoomInit"
	local StartMethod = options.StartMethod or "LoomStart"

	local Manager = {}
	local items: { [string]: T & PrivateTypes.LoomMember } = {}

	function Manager.Register(item: T & PrivateTypes.LoomMember, params: { [any]: any? }?): T
		local member = item :: any

		if items[member.Name] then
			error(`{ModuleName} {member.Name} already exists!`)
		end

		normalizeItem(member)
		fillItem(member, params)

		items[member.Name] = item
		return item
	end

	function Manager.Get(name: string): T?
		local item = items[name]
		if not item then
			error(`Couldn't find {ModuleName}: {name}`)
		end

		return item
	end

	function Manager.Start()
		local successfullyInitialized = {}
		local itemsArray = Dictionary.values(items)

		local promises: { Promise.TypedPromise<any> } = Array.map(itemsArray, function(item)
			return Promise.new(function(resolve, reject)
				if runLifecycle(item, InitMethod) then
					table.insert(successfullyInitialized, item)
					resolve()
				else
					reject(`[{ModuleName}] Initialization failed for {item.Name}`)
				end
			end)
		end)

		local success, err = Promise.all(promises):await()
		if not success then
			logger:AtWarning():Log(`[{ModuleName}] Some {ModuleName}s failed to initialize. Error: {err}`)
		end

		local asyncStart = Array.every(successfullyInitialized, function(service)
			return service.Priority == 0
		end)

		local sorted = Array.sort(successfullyInitialized, function(a, b): boolean
			return a.Priority > b.Priority
		end)

		logger:AtDebug():Log(`[{ModuleName}] async start allowed: {asyncStart}`)
		for _, service in sorted do
			if asyncStart then
				task.spawn(runLifecycle, service, StartMethod)
			else
				runLifecycle(service, StartMethod)
			end
		end
	end

	Manager._items = items

	return table.freeze((Manager :: any) :: PrivateTypes.LoomManager<T>)
end

return table.freeze(ManagerBuilder)
