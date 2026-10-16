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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarSensor = require(ReplicatedStorage.CarSensor)
local RunTracker = require(ReplicatedStorage.RunTracker)
local Scoring = require(ReplicatedStorage.Scoring)
local Tuning = require(ReplicatedStorage.Tuning)

type Watch = {
	player: Player,
	sensor: CarSensor.Sensor,
	run: RunTracker.State,
}

local runResult = Instance.new("RemoteEvent")
runResult.Name = "RunResult"
runResult.Parent = ReplicatedStorage

local watches: { [Model]: Watch } = {}

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
	local sensor = CarSensor.new(car, { character })
	if not sensor then
		return nil
	end
	local watch = { player = player, sensor = sensor, run = RunTracker.new() }
	watches[car] = watch
	return watch
end

local function finish(watch: Watch, result: RunTracker.Result)
	local score = Scoring.score(result, Tuning.Score)
	local leaderstats = watch.player:FindFirstChild("leaderstats")
	local best = leaderstats and leaderstats:FindFirstChild("Best")
	if best and best:IsA("IntValue") and score.total > best.Value then
		best.Value = score.total
	end
	runResult:FireClient(watch.player, result, score)
end

local carsFolder = workspace:WaitForChild("Cars")

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
				local result = RunTracker.step(watch.run, reading.sample, Tuning.Run)
				if result then
					finish(watch, result)
				end
			end
		end
	end
end)
