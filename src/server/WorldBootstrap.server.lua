--!strict
-- WorldBootstrap (Script) -> ServerScriptService.WorldBootstrap
-- Sets world physics and builds the M0 test park at startup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Tuning = require(ReplicatedStorage.Tuning)
local TestPark = require(ServerScriptService.TestPark)

workspace.Gravity = Tuning.World.Gravity

if workspace:FindFirstChild("TestPark") then
	-- World was already built at edit time and saved in the place file.
	-- Skip runtime generation to avoid creating a duplicate.
	return
end

TestPark.build()
