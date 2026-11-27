--!strict
-- AnalyticsWatch (Script) -> ServerScriptService.AnalyticsWatch
-- Reaches the onboarding steps (Analytics) that no other script sees:
-- Joined once a player's data loads, then every WatchGap seconds, from the
-- car the server sees in workspace.Cars, CarSpawned, FirstDrive once it
-- moves at DriveSpeed with a wheel on the ground, and OpenedGarage when the
-- player's client says the garage panel opened (GarageOpenedEvent, sent by
-- GarageMenu). The panel opens anywhere, only on the player's screen, and a
-- false report can't touch cash or stats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Tuning = require(ReplicatedStorage.Tuning)
local Analytics = require(ServerScriptService.Analytics)
local PlayerData = require(ServerScriptService.PlayerData)

local T = Tuning.Analytics
local carsFolder = workspace:WaitForChild("Cars")

-- Whether the hull has ground just under it, so a fall or a flight is not a drive.
local function grounded(hull: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { carsFolder }
	return workspace:Raycast(hull.Position, Vector3.new(0, -Tuning.Garage.GroundCheck, 0), params) ~= nil
end

local function onPlayerAdded(player: Player)
	if PlayerData.waitFor(player) then
		Analytics.reach(player, "Joined")
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

local garageOpened = ReplicatedStorage:WaitForChild("GarageOpenedEvent") :: RemoteEvent
garageOpened.OnServerEvent:Connect(function(player: Player)
	Analytics.reach(player, "OpenedGarage")
end)

while true do
	task.wait(T.WatchGap)
	for _, car in carsFolder:GetChildren() do
		local owner = car:GetAttribute("OwnerUserId")
		local player = if typeof(owner) == "number" then Players:GetPlayerByUserId(owner) else nil
		local hull = if car:IsA("Model") then car.PrimaryPart else nil
		if player and hull then
			Analytics.reach(player, "CarSpawned")
			if hull.AssemblyLinearVelocity.Magnitude >= T.DriveSpeed and grounded(hull) then
				Analytics.reach(player, "FirstDrive")
			end
		end
	end
end
