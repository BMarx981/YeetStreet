--!strict
-- CarService (Script) -> ServerScriptService.CarService
-- Gives every character a car in a spawn lane, seats them in it, and hands the
-- player network ownership so their client drives it. The car is their
-- equipped one, with stats from their upgrade levels (Garage), so the first
-- car waits for their data to load. The car's looks go on it as attributes
-- (CarParts), and each client builds them (CarVisuals).
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CarParts = require(ReplicatedStorage.CarParts)
local CarBuilder = require(ServerScriptService.CarBuilder)
local CollisionGroups = require(ServerScriptService.CollisionGroups)
local Garage = require(ServerScriptService.Garage)
local TestPark = require(ServerScriptService.TestPark)
local Tuning = require(ReplicatedStorage.Tuning)

local RESEAT_DELAY = 0.2

-- Players who have intentionally exited; the reseat logic skips them.
local exited: { [Player]: boolean } = {}

local carsFolder = Instance.new("Folder")
carsFolder.Name = "Cars"
carsFolder.Parent = workspace

local cars: { [Player]: Model } = {}
local lanesUsed = 0
-- Touch connections for re-entering a car after exiting.
local enterConnections: { [Player]: { RBXScriptConnection } } = {}

local function clearEnterConnections(player: Player)
	local conns = enterConnections[player]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		enterConnections[player] = nil
	end
end

local function removeCar(player: Player)
	clearEnterConnections(player)
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

-- Restores a character to normal physics after exiting a car.
local function unghostPart(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = "Default"
		instance.Massless = false
	end
end

local function unghostCharacter(character: Model)
	for _, descendant in character:GetDescendants() do
		unghostPart(descendant)
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

-- Forward declaration so placeCar can dispatch to it.
local placeFrogCar

-- Replaces the player's car with a fresh one at `cframe` and seats them in it.
-- If the player has the frog car equipped, dispatches to placeFrogCar instead.
local function placeCar(player: Player, humanoid: Humanoid, cframe: CFrame)
	if player:GetAttribute("FrogCarEquipped") then
		placeFrogCar(player, humanoid, cframe)
		return
	end
	local ladderCar, stats, looks = Garage.car(player)
	if not (ladderCar and stats and looks) or humanoid.Parent ~= player.Character then
		return
	end
	removeCar(player)
	local car = CarBuilder.build(stats, cframe)
	car.Name = `Car_{player.Name}`
	car:SetAttribute("OwnerUserId", player.UserId)
	car:SetAttribute("CarId", ladderCar.Id)
	CarParts.setLook(car, ladderCar.Seed, ladderCar.Archetype, ladderCar.Tier, looks)
	if player:GetAttribute("HeliCarEquipped") == true then
		car:SetAttribute("HeliCar", true)
	end
	if player:GetAttribute("PlaneCarEquipped") == true then
		car:SetAttribute("PlaneCar", true)
	end
	car.Parent = carsFolder
	cars[player] = car
	seatDriver(car, humanoid)
	giveOwnership(car, player)
end

-- Builds a Frog Car for the player. Admin-only, spawned via the GiveFrogCar
-- BindableEvent. Uses CarBuilder with frog stats and sets the FrogCar attribute
-- so CarVisuals builds frog looks and CarController handles jumping.
placeFrogCar = function(player: Player, humanoid: Humanoid, cframe: CFrame)
	if humanoid.Parent ~= player.Character then
		return
	end
	removeCar(player)
	local car = CarBuilder.build(Tuning.FrogCar :: any, cframe)
	car.Name = `Car_{player.Name}`
	car:SetAttribute("OwnerUserId", player.UserId)
	car:SetAttribute("FrogCar", true)
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
			-- Only clear exited and take ownership if this is the player's own car seat.
			-- Sitting on a display car or other seat should not count as re-entering.
			local ownSeat = car:FindFirstChild("DriverSeat")
			if ownSeat and humanoid.SeatPart == ownSeat then
				exited[player] = nil
				giveOwnership(car, player)
			end
			return
		end
		-- If the player intentionally exited, do not reseat them.
		if exited[player] then
			return
		end
		task.delay(RESEAT_DELAY, function()
			local now = cars[player]
			if now and player.Character == character and humanoid.SeatPart == nil and not exited[player] then
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

-- Builds a fresh car at `cframe` for a player on foot and seats them in it,
-- as pressing Z does; with no cframe, in a spawn lane at the hub. ScoreService
-- sends a player here when the T-Rex swallows them.
local giveCar = Instance.new("BindableEvent")
giveCar.Name = "GiveCar"
giveCar.Event:Connect(function(player: Player, cframe: CFrame?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid and humanoid.Health > 0) then
		return
	end
	for _, desc in character:GetDescendants() do
		ghostPart(desc)
	end
	exited[player] = nil
	if not cframe then
		lanesUsed += 1
	end
	placeCar(player, humanoid, cframe or TestPark.spawnCFrame(lanesUsed))
end)
giveCar.Parent = ServerStorage

-- Admin command: give a player the Frog Car.
local giveFrogCar = Instance.new("BindableEvent")
giveFrogCar.Name = "GiveFrogCar"
giveFrogCar.Event:Connect(function(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then
		return
	end
	local cframe
	local existingCar = cars[player]
	if existingCar then
		cframe = existingCar:GetPivot()
	else
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		cframe = hrp.CFrame
		-- Ghost the character so it doesn't affect car physics.
		for _, desc in character:GetDescendants() do
			ghostPart(desc)
		end
		exited[player] = nil
	end
	player:SetAttribute("FrogCarEquipped", true)
	placeFrogCar(player, humanoid, cframe)
end)
giveFrogCar.Parent = ServerStorage

-- Admin command: switch a player's car to the HeliCar look and back, and
-- rebuild their car where it is. Only the looks change; the stats still come
-- from their equipped car. Lasts until they leave.
local toggleHeliCar = Instance.new("BindableEvent")
toggleHeliCar.Name = "ToggleHeliCar"
toggleHeliCar.Event:Connect(function(player: Player)
	player:SetAttribute("HeliCarEquipped", player:GetAttribute("HeliCarEquipped") ~= true)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local car = cars[player]
	if humanoid and humanoid.Health > 0 and car then
		placeCar(player, humanoid, car:GetPivot())
	end
end)
toggleHeliCar.Parent = ServerStorage

-- Admin command: switch a player's car to the PlaneCar and back, the same
-- way. It starts as a car; its WingsOut attribute makes it a plane.
local togglePlaneCar = Instance.new("BindableEvent")
togglePlaneCar.Name = "TogglePlaneCar"
togglePlaneCar.Event:Connect(function(player: Player)
	player:SetAttribute("PlaneCarEquipped", player:GetAttribute("PlaneCarEquipped") ~= true)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local car = cars[player]
	if humanoid and humanoid.Health > 0 and car then
		placeCar(player, humanoid, car:GetPivot())
	end
end)
togglePlaneCar.Parent = ServerStorage

-- Client requested to exit the car: unseat the driver and place them beside
-- the car so they can walk around. The exited flag prevents the SeatPart
-- changed signal from reseating them.
local function onExitCar(player: Player)
	local car = cars[player]
	local character = player.Character
	if not (car and character) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local seat = car:FindFirstChild("DriverSeat")
	if not (seat and seat:IsA("Seat")) then
		return
	end
	exited[player] = true
	seat:Sit(nil) -- break the seat weld
	humanoid.Jump = true -- nudge them out of the seat

	-- The client zeros the car's velocity before firing the exit remote,
	-- so the car stops in place.

	-- Restore the character to normal physics so they don't fall through
	-- the ground. lockDriver will re-ghost them if they respawn in a new car.
	unghostCharacter(character)

	-- Place the player standing beside the car.
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local carCFrame = car:GetPivot()
		local offset = carCFrame.RightVector * 8
		local landPos = carCFrame.Position + offset
		landPos = Vector3.new(landPos.X, math.max(landPos.Y, 3), landPos.Z)
		character:PivotTo(CFrame.new(landPos))
	end

	removeCar(player)
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
Players.PlayerRemoving:Connect(function(player)
	exited[player] = nil
	removeCar(player)
end)

-- Hook up the ExitCar RemoteEvent.
local exitCar = ReplicatedStorage:FindFirstChild("ExitCar")
if exitCar and exitCar:IsA("RemoteEvent") then
	exitCar.OnServerEvent:Connect(onExitCar)
end

-- Spawn a car at the player's position when they press Z on foot.
local spawnCar = ReplicatedStorage:FindFirstChild("SpawnCar")
if spawnCar and spawnCar:IsA("RemoteEvent") then
	spawnCar.OnServerEvent:Connect(function(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (humanoid and humanoid.Health > 0) then
			return
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		-- Re-ghost the character so it doesn't affect car physics.
		for _, desc in character:GetDescendants() do
			ghostPart(desc)
		end
		exited[player] = nil
		placeCar(player, humanoid, hrp.CFrame)
	end)
end
-- Toggle the Frog Car on/off. Only works if the player owns the FrogCar limited.
local toggleFrogCar = ReplicatedStorage:FindFirstChild("ToggleFrogCar")
if toggleFrogCar and toggleFrogCar:IsA("RemoteEvent") then
	toggleFrogCar.OnServerEvent:Connect(function(player: Player)
		local limitedsOwned = player:GetAttribute("LimitedsOwned")
		local owned = typeof(limitedsOwned) == "string" and string.find(limitedsOwned, "FrogCar") ~= nil
		if not owned then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (humanoid and humanoid.Health > 0) then
			return
		end
		local equipped = player:GetAttribute("FrogCarEquipped") == true
		player:SetAttribute("FrogCarEquipped", not equipped)

		local cframe
		local existingCar = cars[player]
		if existingCar then
			cframe = existingCar:GetPivot()
		else
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				return
			end
			cframe = hrp.CFrame
			for _, desc in character:GetDescendants() do
				ghostPart(desc)
			end
			exited[player] = nil
		end
		placeCar(player, humanoid, cframe)
	end)
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
