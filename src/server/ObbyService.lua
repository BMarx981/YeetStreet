--!strict
-- ObbyService (ModuleScript) -> ServerScriptService.ObbyService
-- The car obby on the server. The rules are Obby's; this runs them for each
-- player in the obby and tells everyone else.
--
-- A visit starts when a player teleports in (TeleportService calls enter) and
-- ends when they teleport anywhere else (leave), get a new character, or
-- leave the game. Nothing about a visit is saved.
--
-- The course is workspace.Obby.World1, built here by ObbyBuilder unless it was
-- saved with the place. Checkpoint pads are parts tagged ObbyCheckpoint with
-- a Checkpoint number attribute, 0 for the start pad. Every heartbeat the server checks each
-- visiting player's car against the pads, so clients never report touches:
-- a hull over a pad, up to CheckpointReach above it, touches it. Resets and
-- wrecks come back on top of the current pad, facing its front (ScoreService's
-- SetPlayerCheckpoint), and so does a car more than FallDepth below the
-- lowest pad, or one hung on an edge with its wheels off the course
-- (Obby.hang).
--
-- Clearing a stage pays its cash at once, on every visit. The first finish
-- ever also pays WorldPrize, saved as PlayerData's ObbyCleared.
--
-- Clients see a visit as Player attributes ObbyReached and ObbyCheckpoint
-- (nil outside the obby) and hear about cash on ReplicatedStorage.ObbyReward
-- ({ Stage, Cash, Prize }). They respawn at a reached checkpoint by invoking
-- ReplicatedStorage.ObbySelect(checkpoint), which returns (ok, reason):
-- "TooSoon", "NotInObby", "NotReached", or "NoPad".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Obby = require(ReplicatedStorage.Obby)
local Tuning = require(ReplicatedStorage.Tuning)
local Garage = require(ServerScriptService.Garage)
local ObbyBuilder = require(ServerScriptService.ObbyBuilder)
local PlayerData = require(ServerScriptService.PlayerData)

local T = Tuning.Obby
local TAG = "ObbyCheckpoint"
-- The hull's center above the floor, the same as a car in a spawn lane.
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight
local WHEELS = { "FL", "FR", "RL", "RR" } -- CarBuilder's wheel names
-- A wheel this far past its radius above the course still counts as down.
local WHEEL_SLACK = 0.6

local ObbyService = {}

local visits: { [Player]: Obby.Visit } = {}
local lastSelectAt: { [Player]: number } = {}
local lastFallAt: { [Player]: number } = {}
local hangingSince: { [Player]: number } = {}

local setPlayerCheckpoint = ServerStorage:WaitForChild("SetPlayerCheckpoint") :: BindableFunction
local movePlayerCar = ServerStorage:WaitForChild("MovePlayerCar") :: BindableFunction
local resetPlayerCar = ServerStorage:WaitForChild("ResetPlayerCar") :: BindableEvent
local carsFolder = workspace:WaitForChild("Cars")

local obbyFolder = workspace:FindFirstChild("Obby") or Instance.new("Folder")
obbyFolder.Name = "Obby"
obbyFolder.Parent = workspace
if not obbyFolder:FindFirstChild("World1") then
	ObbyBuilder.build().Parent = obbyFolder
end

local obbyReward = Instance.new("RemoteEvent")
obbyReward.Name = "ObbyReward"
obbyReward.Parent = ReplicatedStorage

-- The pad for checkpoint `n`, if it is built.
local function pad(n: number): BasePart?
	for _, part in CollectionService:GetTagged(TAG) do
		if part:IsA("BasePart") and part:GetAttribute("Checkpoint") == n then
			return part
		end
	end
	return nil
end

local function respawnAt(part: BasePart): CFrame
	return part.CFrame * CFrame.new(0, part.Size.Y / 2 + HULL_HEIGHT, 0)
end

local function onPad(part: BasePart, position: Vector3): boolean
	local at = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(at.X) <= half.X
		and math.abs(at.Z) <= half.Z
		and at.Y >= -half.Y
		and at.Y <= half.Y + T.CheckpointReach
end

local function hullOf(player: Player): BasePart?
	for _, car in carsFolder:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("OwnerUserId") == player.UserId then
			return car.PrimaryPart
		end
	end
	return nil
end

-- Starts or changes the player's visit, moving their respawn point if its
-- checkpoint changed.
local function setVisit(player: Player, visit: Obby.Visit)
	local before = visits[player]
	visits[player] = visit
	player:SetAttribute("ObbyReached", visit.Reached)
	player:SetAttribute("ObbyCheckpoint", visit.Current)
	if not before or before.Current ~= visit.Current then
		local part = pad(visit.Current)
		setPlayerCheckpoint:Invoke(player, if part then respawnAt(part) else nil)
	end
end

local function touch(player: Player, visit: Obby.Visit, checkpoint: number)
	local after, cash = Obby.touch(visit, checkpoint, T)
	if after == visit then
		return
	end
	setVisit(player, after)
	if cash <= 0 then
		return
	end
	Garage.pay(player, cash)
	local prize = 0
	local data = PlayerData.get(player)
	if Obby.finished(after, T) and data and not data.ObbyCleared then
		data.ObbyCleared = true
		prize = T.WorldPrize
		Garage.pay(player, prize)
	end
	obbyReward:FireClient(player, { Stage = checkpoint, Cash = cash, Prize = prize })
end

-- Starts a fresh visit and returns where the car arrives: on the start pad.
-- Nil if the obby isn't built.
function ObbyService.enter(player: Player): CFrame?
	local start = pad(0)
	if not start then
		return nil
	end
	visits[player] = nil
	setVisit(player, Obby.newVisit())
	return respawnAt(start)
end

-- Ends the player's visit, if they have one.
function ObbyService.leave(player: Player)
	if not visits[player] then
		return
	end
	visits[player] = nil
	player:SetAttribute("ObbyReached", nil)
	player:SetAttribute("ObbyCheckpoint", nil)
	setPlayerCheckpoint:Invoke(player, nil)
end

local obbySelect = Instance.new("RemoteFunction")
obbySelect.Name = "ObbySelect"
obbySelect.OnServerInvoke = function(player: Player, checkpoint: any): (boolean, string?)
	local now = os.clock()
	if now - (lastSelectAt[player] or -math.huge) < T.SelectGap then
		return false, "TooSoon"
	end
	local visit = visits[player]
	if not visit then
		return false, "NotInObby"
	end
	local after = if typeof(checkpoint) == "number" then Obby.select(visit, checkpoint) else nil
	if not after then
		return false, "NotReached"
	end
	local part = pad(after.Current)
	if not part then
		return false, "NoPad"
	end
	lastSelectAt[player] = now
	setVisit(player, after)
	movePlayerCar:Invoke(player, respawnAt(part), false)
	return true, nil
end
obbySelect.Parent = ReplicatedStorage

local wheelRays = RaycastParams.new()
wheelRays.FilterType = Enum.RaycastFilterType.Include
wheelRays.FilterDescendantsInstances = { obbyFolder }

-- How many of the car's wheels are on the course.
local function wheelsDown(hull: BasePart): number
	local car = hull.Parent
	local reach = Vector3.new(0, -(Tuning.Chassis.WheelRadius + WHEEL_SLACK), 0)
	local down = 0
	for _, name in WHEELS do
		local wheel = car and car:FindFirstChild(`Wheel{name}`)
		if wheel and wheel:IsA("BasePart") and workspace:Raycast(wheel.Position, reach, wheelRays) then
			down += 1
		end
	end
	return down
end

-- Respawns a fallen or hung car at its checkpoint.
local function fallen(player: Player, now: number)
	hangingSince[player] = nil
	if now - (lastFallAt[player] or -math.huge) >= Tuning.Reset.RequestGap then
		lastFallAt[player] = now
		resetPlayerCar:Fire(player)
	end
end

RunService.Heartbeat:Connect(function()
	if next(visits) == nil then
		return
	end
	local pads = CollectionService:GetTagged(TAG)
	local lowest = math.huge
	for _, part in pads do
		if part:IsA("BasePart") then
			lowest = math.min(lowest, part.Position.Y)
		end
	end
	local now = os.clock()
	for player, visit in visits do
		local hull = hullOf(player)
		if not hull then
			continue
		end
		local position = hull.Position
		if position.Y < lowest - T.FallDepth then
			fallen(player, now)
			continue
		end
		local roll = math.deg(math.asin(math.clamp(math.abs(hull.CFrame.RightVector.Y), 0, 1)))
		local respawn
		hangingSince[player], respawn =
			Obby.hang(hangingSince[player], now, hull.AssemblyLinearVelocity.Magnitude, wheelsDown(hull), roll, T)
		if respawn then
			fallen(player, now)
			continue
		end
		for _, part in pads do
			local checkpoint = part:GetAttribute("Checkpoint")
			if part:IsA("BasePart") and typeof(checkpoint) == "number" and onPad(part, position) then
				touch(player, visit, checkpoint)
				break
			end
		end
	end
end)

local function onPlayerAdded(player: Player)
	-- A new character gets a new car at the hub, out of the obby.
	player.CharacterAdded:Connect(function()
		ObbyService.leave(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	visits[player] = nil
	lastSelectAt[player] = nil
	lastFallAt[player] = nil
	hangingSince[player] = nil
end)

return ObbyService
