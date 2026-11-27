--!strict
-- AnalyticsWatch (Script) -> ServerScriptService.AnalyticsWatch
-- Reaches the onboarding steps (Analytics) that no other script sees:
-- Joined once a player's data loads, then every WatchGap seconds, from the
-- car the server sees in workspace.Cars, CarSpawned, FirstDrive once it
-- moves at DriveSpeed with a wheel on the ground, and OpenedGarage when the
-- player's client says the garage panel opened (GarageOpenedEvent, sent by
-- GarageMenu). The panel opens anywhere, only on the player's screen, and a
-- false report can't touch cash or stats.
-- It also follows each player's park visits (ParkVisits) from where their car
-- is while on the ground, in the obby while they have an ObbyCheckpoint, and
-- logs each one that ends (Analytics.parkTime), as Moved, or Quit on leaving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local ParkVisits = require(ReplicatedStorage.ParkVisits)
local Tuning = require(ReplicatedStorage.Tuning)
local Analytics = require(ServerScriptService.Analytics)
local PlayerData = require(ServerScriptService.PlayerData)

local T = Tuning.Analytics
local carsFolder = workspace:WaitForChild("Cars")
local areas: { MapLayout.Area } = Tuning.Map.Areas :: any
local visits: { [Player]: ParkVisits.State } = {}

-- Where the player is: "Obby", a park's area Id, or "" between parks.
local function parkOf(player: Player, position: Vector3): string
	if player:GetAttribute("ObbyCheckpoint") ~= nil then
		return "Obby"
	end
	local area = MapLayout.at(areas, position.X, position.Z)
	return if area then area.Id else ""
end

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

Players.PlayerRemoving:Connect(function(player: Player)
	local state = visits[player]
	visits[player] = nil
	local visit = state and ParkVisits.finish(state, T.ParkVisits)
	if visit then
		Analytics.parkTime(player, visit.park, visit.seconds, "Quit")
	end
end)

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
			local onGround = grounded(hull)
			if hull.AssemblyLinearVelocity.Magnitude >= T.DriveSpeed and onGround then
				Analytics.reach(player, "FirstDrive")
			end
			if onGround then
				local state = visits[player] or ParkVisits.new()
				visits[player] = state
				local visit = ParkVisits.step(state, parkOf(player, hull.Position), os.clock(), T.ParkVisits)
				if visit then
					Analytics.parkTime(player, visit.park, visit.seconds, "Moved")
				end
			end
		end
	end
end
