--!strict
-- CarService (Script) -> ServerScriptService.CarService
-- Gives every character a car in a spawn lane, seats them in it, and hands the
-- player network ownership so their client drives it. The car is their
-- equipped one, with stats from their upgrade levels (Garage), so the first
-- car waits for their data to load.
--
-- Respawns go through ServerStorage.RespawnCar (a BindableEvent fired with a
-- player and a CFrame, by ScoreService on a reset or wreck): the old car is
-- removed and a fresh one is built there, with the same driver seated.
--
-- No oof rules live here: the driver's health never drops, they are put back
-- in the seat if they ever leave it, and their character is massless and
-- collides with nothing, so it can neither change how the car handles nor hold
-- a flipped car up.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CarBuilder = require(ServerScriptService.CarBuilder)
local CollisionGroups = require(ServerScriptService.CollisionGroups)
local Garage = require(ServerScriptService.Garage)
local TestPark = require(ServerScriptService.TestPark)

local RESEAT_DELAY = 0.2

local carsFolder = Instance.new("Folder")
carsFolder.Name = "Cars"
carsFolder.Parent = workspace

local cars: { [Player]: Model } = {}
local lanesUsed = 0

local function removeCar(player: Player)
	local car = cars[player]
	if car then
		cars[player] = nil
		car:Destroy()
	end
end

local function ghostPart(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = CollisionGroups.Drivers
		instance.Massless = true
	end
end

local function lockDriver(character: Model, humanoid: Humanoid)
	humanoid.BreakJointsOnDeath = false
	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
	for _, descendant in character:GetDescendants() do
		ghostPart(descendant)
	end
	character.DescendantAdded:Connect(ghostPart)
end

local function giveOwnership(car: Model, player: Player)
	for _, descendant in car:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:CanSetNetworkOwnership() then
			descendant:SetNetworkOwner(player)
		end
	end
end

local function seatDriver(car: Model, humanoid: Humanoid)
	local seat = car:FindFirstChild("DriverSeat")
	if seat and seat:IsA("Seat") and humanoid.Health > 0 and humanoid.SeatPart ~= seat then
		seat:Sit(humanoid)
	end
end

-- Replaces the player's car with a fresh one at `cframe` and seats them in it.
local function placeCar(player: Player, humanoid: Humanoid, cframe: CFrame)
	local carId, stats = Garage.car(player)
	if not (carId and stats) or humanoid.Parent ~= player.Character then
		return
	end
	removeCar(player)
	local car = CarBuilder.build(stats, cframe)
	car.Name = `Car_{player.Name}`
	car:SetAttribute("OwnerUserId", player.UserId)
	car:SetAttribute("CarId", carId)
	car.Parent = carsFolder
	cars[player] = car
	seatDriver(car, humanoid)
	giveOwnership(car, player)
end

local function onCharacterAdded(player: Player, character: Model)
	removeCar(player)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart")
	lockDriver(character, humanoid)

	-- Looks up the player's current car each time, since a respawn swaps it.
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		local car = cars[player]
		if not car or player.Character ~= character then
			return
		end
		if humanoid.SeatPart then
			-- Seating welds the character into the car's assembly.
			giveOwnership(car, player)
			return
		end
		task.delay(RESEAT_DELAY, function()
			local now = cars[player]
			if now and player.Character == character and humanoid.SeatPart == nil then
				seatDriver(now, humanoid)
			end
		end)
	end)

	lanesUsed += 1
	placeCar(player, humanoid, TestPark.spawnCFrame(lanesUsed))
end

local respawnCar = Instance.new("BindableEvent")
respawnCar.Name = "RespawnCar"
respawnCar.Event:Connect(function(player: Player, cframe: CFrame)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and cars[player] then
		placeCar(player, humanoid, cframe)
	end
end)
respawnCar.Parent = ServerStorage

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		removeCar(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(removeCar)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
