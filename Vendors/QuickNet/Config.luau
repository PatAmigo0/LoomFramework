--[[
Sizes in bytes
Note: 1KB = 1000 bytes, 1MB = 1M bytes
]]

local Config = {
	DebugMode = true,
	DefaultRateLimit = {Max = 60, Time = 1},
	DefaultResponseTimeout = 10,
	MaxCallsPerFrame = 100,
	MaxPacketSize = 50000, --recommended 10-50K
	ClientAllocationSize = 2000000, --recommended 1-5M
	ServerAllocationSize = 1000000, --recommended 500K-2M
}

return Config
