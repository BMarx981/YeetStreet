--!strict
-- TeleportService (Script) -> ServerScriptService.TeleportService
-- The teleport menu's server side. Clients invoke ReplicatedStorage.Teleport
-- with "Garage" or the Id of a hub or park in Tuning.Map, and get back
-- (ok, reason): "TooSoon", "Unknown", "NoGarage", or "NotReady".
--
-- A teleport works any time, even mid-air: like a reset, it ends the run
-- (ScoreService, through ServerStorage.MovePlayerCar) and builds the car at
-- the destination. A hub or park becomes where later resets and wrecks
-- respawn, until the next launch pad. "Garage" goes to the Garage-tagged
-- model nearest the player, GarageDistance in front of it and facing it, and
-- leaves the respawn point alone. A player on foot moves there on foot.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local GARAGE = "Garage"
-- The hull's center above the floor, the same as a car in a spawn lane.
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight

local areas: { MapLayout.Area } = Tuning.Map.Areas :: any
local movePlayerCar = ServerStorage:WaitForChild("MovePlayerCar") :: BindableFunction
local carsFolder = workspace:WaitForChild("Cars")

local lastTeleportAt: { [Player]: number } = {}

-- The floor's height under (x, z), looking down from `fromY`; 0 if nothing is
-- there. Cars and characters are not floors.
local function floorY(x: number, z: number, fromY: number, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { carsFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	for _, instance in ignore do
		table.insert(exclude, instance)
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -fromY - 50, 0), params)
	return if hit then hit.Position.Y else 0
end

local function areaArrival(area: MapLayout.Area): CFrame
	local y = floorY(area.ArriveX, area.ArriveZ, 200, {})
	return CFrame.new(area.ArriveX, y + HULL_HEIGHT, area.ArriveZ) * CFrame.Angles(0, math.rad(area.Heading), 0)
end

local function nearestGarage(from: Vector3): PVInstance?
	local best: PVInstance? = nil
	local bestDistance = math.huge
	for _, garage in CollectionService:GetTagged(GARAGE) do
		if garage:IsA("PVInstance") then
			local distance = (garage:GetPivot().Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = garage, distance
			end
		end
	end
	return best
end

local function garageArrival(garage: PVInstance): CFrame
	local pivot = garage:GetPivot()
	local spot = pivot.Position + pivot.LookVector * Tuning.Teleport.GarageDistance
	local y = floorY(spot.X, spot.Z, pivot.Position.Y + 3, { garage })
	local at = Vector3.new(spot.X, y + HULL_HEIGHT, spot.Z)
	return CFrame.lookAt(at, Vector3.new(pivot.Position.X, at.Y, pivot.Position.Z))
end

local function teleport(player: Player, destination: any): (boolean, string?)
	local now = os.clock()
	if now - (lastTeleportAt[player] or -math.huge) < Tuning.Teleport.RequestGap then
		return false, "TooSoon"
	end
	local character = player.Character
	if not character then
		return false, "NotReady"
	end

	local arrival: CFrame
	local home: boolean
	if destination == GARAGE then
		local garage = nearestGarage(character:GetPivot().Position)
		if not garage then
			return false, "NoGarage"
		end
		arrival, home = garageArrival(garage), false
	else
		local area = if typeof(destination) == "string" then MapLayout.find(areas, destination) else nil
		if not area or area.Kind == "Open" then
			return false, "Unknown"
		end
		arrival, home = areaArrival(area), true
	end

	lastTeleportAt[player] = now
	if not movePlayerCar:Invoke(player, arrival, home) then
		character:PivotTo(arrival + Vector3.new(0, 3, 0))
	end
	return true, nil
end

local teleportRemote = Instance.new("RemoteFunction")
teleportRemote.Name = "Teleport"
teleportRemote.OnServerInvoke = teleport
teleportRemote.Parent = ReplicatedStorage

Players.PlayerRemoving:Connect(function(player: Player)
	lastTeleportAt[player] = nil
end)
