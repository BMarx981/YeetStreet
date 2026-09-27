--!strict
-- CarService (Script) -> ServerScriptService.CarService
-- Gives every character a car in a spawn lane, seats them in it, and hands the
-- player network ownership so their client drives it.
--
-- No oof rules live here: the driver's health never drops, they are put back
-- in the seat if they ever leave it, and their character is massless and
-- collides with nothing, so it can neither change how the car handles nor hold
-- a flipped car up.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Tuning = require(ReplicatedStorage.Tuning)
local CarBuilder = require(ServerScriptService.CarBuilder)
local TestPark = require(ServerScriptService.TestPark)

local RESEAT_DELAY = 0.2

PhysicsService:RegisterCollisionGroup("Cars")
PhysicsService:RegisterCollisionGroup("Drivers")
PhysicsService:CollisionGroupSetCollidable("Drivers", "Default", false)
PhysicsService:CollisionGroupSetCollidable("Drivers", "Cars", false)
PhysicsService:CollisionGroupSetCollidable("Drivers", "Drivers", false)

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
		instance.CollisionGroup = "Drivers"
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

local function onCharacterAdded(player: Player, character: Model)
	removeCar(player)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart")
	lockDriver(character, humanoid)

	lanesUsed += 1
	local car = CarBuilder.build(Tuning.StarterCar, TestPark.spawnCFrame(lanesUsed))
	car.Name = `Car_{player.Name}`
	car:SetAttribute("OwnerUserId", player.UserId)
	car.Parent = carsFolder
	cars[player] = car

	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		if cars[player] ~= car then
			return
		end
		if humanoid.SeatPart then
			-- Seating welds the character into the car's assembly.
			giveOwnership(car, player)
			return
		end
		task.delay(RESEAT_DELAY, function()
			if cars[player] == car and humanoid.SeatPart == nil then
				seatDriver(car, humanoid)
			end
		end)
	end)

	seatDriver(car, humanoid)
	giveOwnership(car, player)
end

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
