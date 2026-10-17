--!strict
-- ScoreService (Script) -> ServerScriptService.ScoreService
-- Scores every run on the server. Each Heartbeat it reads every car in
-- workspace.Cars through the same CarSensor, RunTracker, and Scoring the
-- driving client uses, but from the motion the server sees. The client never
-- sends a score; this one is the one that counts.
--
-- When a run ends, the driver's client gets the server's result on
-- ReplicatedStorage.RunResult, and a better total becomes their Best in
-- leaderstats. Nothing saves until M2.
--
-- It also owns toughness. Every hit a car takes is measured (CarSensor) and
-- placed on a slot (Impact). Body hits during a run drain the car's
-- ToughnessLeft attribute and break parts off that slot (Toughness,
-- CarDamage), and each part broken pays Smash points on the run. Toughness
-- refills to the car's Toughness stat when the run ends. Hits of at least
-- Tuning.Toughness.ShowImpact go to the driver on ReplicatedStorage.CarImpact
-- and print to Output, for tuning.
--
-- At zero toughness the car wrecks: every part left flies off, sparks burst,
-- and the run ends as "wrecked". A wreck and a reset (the client asks on
-- ReplicatedStorage.ResetCar) both respawn the car fresh at the last launcher
-- the player used, through CarService's ServerStorage.RespawnCar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CarSensor = require(ReplicatedStorage.CarSensor)
local Impact = require(ReplicatedStorage.Impact)
local RunTracker = require(ReplicatedStorage.RunTracker)
local Scoring = require(ReplicatedStorage.Scoring)
local Toughness = require(ReplicatedStorage.Toughness)
local Tuning = require(ReplicatedStorage.Tuning)
local CarDamage = require(ServerScriptService.CarDamage)

local T = Tuning.Toughness

type Watch = {
	player: Player,
	car: Model,
	sensor: CarSensor.Sensor,
	run: RunTracker.State,
	maxToughness: number,
	toughness: number,
	-- Running damage per slot since the car was built, for breaking parts.
	slotDamage: { [string]: number },
	smashes: number, -- parts broken this run
	respawning: boolean, -- a respawn was asked for; the car is about to go
}

local runResult = Instance.new("RemoteEvent")
runResult.Name = "RunResult"
runResult.Parent = ReplicatedStorage

local carImpact = Instance.new("RemoteEvent")
carImpact.Name = "CarImpact"
carImpact.Parent = ReplicatedStorage

local resetCar = Instance.new("RemoteEvent")
resetCar.Name = "ResetCar"
resetCar.Parent = ReplicatedStorage

local watches: { [Model]: Watch } = {}
-- The RespawnCFrame of the last launch pad each player touched.
local lastLaunch: { [Player]: CFrame } = {}
local lastResetAt: { [Player]: number } = {}
local respawns = 0

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local best = Instance.new("IntValue")
	best.Name = "Best"
	best.Parent = leaderstats
	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	lastLaunch[player] = nil
	lastResetAt[player] = nil
end)

-- The watch for a car, started the first time its owner, driver, and parts
-- are all there. CarService builds a new car for each character, so the
-- driver a watch ignores in its raycasts never changes.
local function watchFor(car: Model): Watch?
	local existing = watches[car]
	if existing then
		return existing
	end
	local userId = car:GetAttribute("OwnerUserId")
	if typeof(userId) ~= "number" then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	if not (player and character) then
		return nil
	end
	local maxToughness = car:GetAttribute("Toughness")
	if typeof(maxToughness) ~= "number" then
		return nil
	end
	local sensor = CarSensor.new(car, { character })
	if not sensor then
		return nil
	end
	local watch: Watch = {
		player = player,
		car = car,
		sensor = sensor,
		run = RunTracker.new(),
		maxToughness = maxToughness,
		toughness = maxToughness,
		slotDamage = {},
		smashes = 0,
		respawning = false,
	}
	car:SetAttribute("ToughnessLeft", maxToughness)
	watches[car] = watch
	return watch
end

-- Measures a hit. Only body hits during a run (including the touchdown that
-- ends it) do damage and break parts.
local function hurt(watch: Watch, hit: Vector3)
	local strength = hit.Magnitude
	if strength < T.ShowImpact then
		return
	end
	local inRun = watch.run.phase == "flying"
	local slot = Impact.slot(hit.X, hit.Y, hit.Z)
	local damage = if inRun then Toughness.damage(strength, slot, T) else 0
	if damage > 0 then
		watch.toughness = math.max(watch.toughness - damage, 0)
		watch.car:SetAttribute("ToughnessLeft", watch.toughness)
		local before = watch.slotDamage[slot] or 0
		local after = before + damage
		watch.slotDamage[slot] = after
		watch.smashes += CarDamage.breakParts(watch.car, slot, Toughness.breaks(before, after, T))
	end
	print(
		`Hit {math.floor(strength + 0.5)} {slot}{if inRun then "" else " (no run)"}, damage {math.floor(damage + 0.5)}, toughness {math.floor(
			watch.toughness + 0.5
		)} left, {watch.player.Name}`
	)
	carImpact:FireClient(watch.player, strength, slot, inRun, damage, watch.toughness)
end

local function finish(watch: Watch, result: RunTracker.Result)
	local score = Scoring.score(result, Tuning.Score, watch.smashes)
	watch.smashes = 0
	watch.toughness = watch.maxToughness
	watch.car:SetAttribute("ToughnessLeft", watch.toughness)
	local leaderstats = watch.player:FindFirstChild("leaderstats")
	local best = leaderstats and leaderstats:FindFirstChild("Best")
	if best and best:IsA("IntValue") and score.total > best.Value then
		best.Value = score.total
	end
	runResult:FireClient(watch.player, result, score)
end

local carsFolder = workspace:WaitForChild("Cars")
local respawnCar = ServerStorage:WaitForChild("RespawnCar") :: BindableEvent

-- Where a reset or wreck puts the car: the last launcher's respawn point, in
-- the next lane over, or the car's own spawn lane before it has launched.
local function respawnPoint(watch: Watch): CFrame?
	local base = lastLaunch[watch.player]
	if not base then
		local spawn = watch.car:GetAttribute("SpawnCFrame")
		return if typeof(spawn) == "CFrame" then spawn else nil
	end
	local R = Tuning.Reset
	respawns += 1
	local lane = respawns % R.RespawnLanes
	return base * CFrame.new((lane - (R.RespawnLanes - 1) / 2) * R.RespawnLaneSpacing, 0, 0)
end

local function respawn(watch: Watch)
	if watch.respawning then
		return
	end
	local point = respawnPoint(watch)
	if point then
		watch.respawning = true
		respawnCar:Fire(watch.player, point)
	end
end

-- Every part left flies off and pays Smash points, sparks burst, the run ends
-- as a wreck, and the car respawns fresh.
local function wreck(watch: Watch)
	watch.smashes += CarDamage.wreck(watch.car)
	local result = RunTracker.abort(watch.run, "wrecked")
	if result then
		finish(watch, result)
	end
	respawn(watch)
end

-- A reset only ends the player's own run and moves their car back to the
-- launcher, so it is safe to take from the client, with a gap against spam.
resetCar.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (lastResetAt[player] or -math.huge) < Tuning.Reset.RequestGap then
		return
	end
	lastResetAt[player] = now
	for _, watch in watches do
		if watch.player == player then
			local result = RunTracker.abort(watch.run)
			if result then
				finish(watch, result)
			end
			respawn(watch)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt: number)
	for car in watches do
		if car.Parent ~= carsFolder then
			watches[car] = nil
		end
	end
	for _, car in carsFolder:GetChildren() do
		if car:IsA("Model") then
			local watch = watchFor(car)
			if watch then
				local reading = CarSensor.read(watch.sensor, dt)
				local respawnAt = reading.pad and reading.pad:GetAttribute("RespawnCFrame")
				if typeof(respawnAt) == "CFrame" then
					lastLaunch[watch.player] = respawnAt
				end
				hurt(watch, reading.impact)
				if watch.toughness <= 0 and not watch.respawning then
					wreck(watch)
				else
					local result = RunTracker.step(watch.run, reading.sample, Tuning.Run)
					if result then
						finish(watch, result)
					end
				end
			end
		end
	end
end)
