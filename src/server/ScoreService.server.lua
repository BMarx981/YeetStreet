--!strict
-- ScoreService (Script) -> ServerScriptService.ScoreService
-- Scores every run on the server. Each Heartbeat it reads every car in
-- workspace.Cars through the same CarSensor, RunTracker, and Scoring the
-- driving client uses, but from the motion the server sees. The client never
-- sends a score; this one is the one that counts.
--
-- When a run ends, the driver's client gets the server's result on
-- ReplicatedStorage.RunResult, the total pays out as cash (Garage), scaled by
-- the PayScale of the launch pad the run started from, and a
-- better total becomes their Best in leaderstats and saves through PlayerData.
--
-- It also owns toughness. Every hit a car takes is measured (CarSensor) and
-- placed on a slot (Impact). Body hits during a run drain the car's
-- ToughnessLeft attribute and break parts off that slot (Toughness,
-- CarDamage), and each part broken pays Smash points on the run. Toughness
-- refills to the car's Toughness stat when the run ends. Hits of at least
-- Tuning.Toughness.ShowImpact go to the driver on ReplicatedStorage.CarImpact
-- and print to Output, for tuning.
--
-- Targets a car smashes through during a run (PropService fires
-- ServerStorage.PropSmashed, such as for Downtown's billboard) pay their
-- Target points on that run.
--
-- A car coming down on lava (CarSensor) banks its run as a landing with a
-- Lava splash target. Lava, and smashing through a boulder too fast
-- (PropService fires ServerStorage.BoulderSmashed), damage the car run or
-- not; lava burns it until it drives out or wrecks, and sets its Burning
-- attribute while it does. The driver is never hurt.
--
-- The T-Rex catching a car (Parks.DinoRex fires ServerStorage.CarEaten) ends
-- its run as a wreck, paying a T-Rex target if it was in the air: base
-- points kept, combo and clean bonus lost. Run or not, it is chewed: its
-- toughness drains evenly over Tuning.Dino.Rex.Chew seconds, then it wrecks.
--
-- At zero toughness the car wrecks: every part left flies off, every client
-- bursts sparks there (ReplicatedStorage.CarWrecked), and the run ends as
-- "wrecked". WreckBeat seconds later, so the driver sees it, the car respawns.
-- A reset (the client asks on ReplicatedStorage.ResetCar, or Garage fires
-- ServerStorage.ResetPlayerCar after a purchase) respawns at once.
-- Both build a fresh car at the last launcher the player used, through
-- CarService's ServerStorage.RespawnCar. A teleport (TeleportService invokes
-- ServerStorage.MovePlayerCar) ends the run the same way and builds the car
-- at its destination.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CarSensor = require(ReplicatedStorage.CarSensor)
local Economy = require(ReplicatedStorage.Economy)
local GapZones = require(ReplicatedStorage.GapZones)
local Impact = require(ReplicatedStorage.Impact)
local RunTracker = require(ReplicatedStorage.RunTracker)
local Scoring = require(ReplicatedStorage.Scoring)
local Toughness = require(ReplicatedStorage.Toughness)
local Tuning = require(ReplicatedStorage.Tuning)
local CarDamage = require(ServerScriptService.CarDamage)
local Garage = require(ServerScriptService.Garage)
local Leaderstats = require(ServerScriptService.Leaderstats)
local PlayerData = require(ServerScriptService.PlayerData)

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
	targets: { string }, -- kinds of the targets smashed this run
	-- The PayScale of the last launch pad touched (1 if it has none), which
	-- scales the cash the next run pays.
	payScale: number,
	wrecked: boolean,
	respawning: boolean, -- a respawn was asked for; the car is about to go
	burning: boolean, -- as the car's Burning attribute shows
	burnedAt: number, -- os.clock() when lava last burned it
	eaten: boolean, -- in the T-Rex's jaws
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

local carWrecked = Instance.new("RemoteEvent")
carWrecked.Name = "CarWrecked"
carWrecked.Parent = ReplicatedStorage

local watches: { [Model]: Watch } = {}
-- The RespawnCFrame of the last launch pad each player touched.
local lastLaunch: { [Player]: CFrame } = {}
local lastResetAt: { [Player]: number } = {}
local respawns = 0

local function onPlayerAdded(player: Player)
	local best = Leaderstats.value(player, "Best")
	-- A run can finish before the saved data arrives, so keep the better one.
	local data = PlayerData.waitFor(player)
	if data then
		best.Value = math.max(best.Value, data.Best)
		data.Best = best.Value
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
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
		targets = {},
		payScale = 1,
		wrecked = false,
		respawning = false,
		burning = false,
		burnedAt = -math.huge,
		eaten = false,
	}
	car:SetAttribute("ToughnessLeft", maxToughness)
	watches[car] = watch
	return watch
end

-- Takes `amount` of the car's toughness and breaks the parts that much
-- damage is worth in `slot`, or in any slot when nil. Broken parts pay Smash
-- points only on a run.
local function damageCar(watch: Watch, amount: number, slot: string?)
	watch.toughness = math.max(watch.toughness - amount, 0)
	watch.car:SetAttribute("ToughnessLeft", watch.toughness)
	local key = slot or "any"
	local before = watch.slotDamage[key] or 0
	local after = before + amount
	watch.slotDamage[key] = after
	local broken = CarDamage.breakParts(watch.car, slot, Toughness.breaks(before, after, T))
	if watch.run.phase == "flying" then
		watch.smashes += broken
	end
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
		damageCar(watch, damage, slot)
	end
	print(
		`Hit {math.floor(strength + 0.5)} {slot}{if inRun then "" else " (no run)"}, damage {math.floor(damage + 0.5)}, toughness {math.floor(
			watch.toughness + 0.5
		)} left, {watch.player.Name}`
	)
	carImpact:FireClient(watch.player, strength, slot, inRun, damage, watch.toughness)
end

local function finish(watch: Watch, result: RunTracker.Result)
	result.gaps = GapZones.find(result)
	result.targets = watch.targets
	watch.targets = {}
	local score = Scoring.score(result, Tuning.Score, watch.smashes)
	watch.smashes = 0
	watch.toughness = watch.maxToughness
	watch.car:SetAttribute("ToughnessLeft", watch.toughness)
	local best = Leaderstats.value(watch.player, "Best")
	if score.total > best.Value then
		best.Value = score.total
	end
	PlayerData.update(watch.player, function(data)
		data.Best = math.max(data.Best, score.total)
	end)
	Garage.pay(watch.player, Economy.payout(score.total, Tuning.Cash.PerPoint * watch.payScale))
	watch.payScale = 1
	runResult:FireClient(watch.player, result, score)
end

local carsFolder = workspace:WaitForChild("Cars")
local respawnCar = ServerStorage:WaitForChild("RespawnCar") :: BindableEvent
local propSmashed = ServerStorage:WaitForChild("PropSmashed") :: BindableEvent
local boulderSmashed = ServerStorage:WaitForChild("BoulderSmashed") :: BindableEvent

-- Only a smash in the air on a run counts.
propSmashed.Event:Connect(function(car: Model, target: string)
	local watch = watches[car]
	if watch and watch.run.phase == "flying" then
		table.insert(watch.targets, target)
	end
end)

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

-- Every part left flies off and pays Smash points on a run, for up to
-- WreckSmashes of them, sparks burst, the run ends as a wreck, and the car
-- respawns fresh after WreckBeat.
local function wreck(watch: Watch)
	watch.wrecked = true
	local broken = math.min(CarDamage.breakParts(watch.car, nil, math.huge), T.WreckSmashes)
	if watch.run.phase == "flying" then
		watch.smashes += broken
	end
	carWrecked:FireAllClients(watch.sensor.hull.Position)
	local result = RunTracker.abort(watch.run, "wrecked")
	if result then
		finish(watch, result)
	end
	task.delay(T.WreckBeat, respawn, watch)
end

-- Coming down in lava ends the run as a landing, never clean, paying a Lava
-- splash target on it. Then the lava burns the car (burn).
local function splash(watch: Watch)
	table.insert(watch.targets, "Lava")
	local result = RunTracker.abort(watch.run, "landed")
	if result then
		finish(watch, result)
	end
end

-- Burns `dt` seconds' worth of the car's toughness, all of it over
-- LavaBurnTime, breaking parts as it goes. Not before its first launch pad
-- near where it was built, as its wreck would only bring it back into the
-- lava. Returns whether it burned.
local function burn(watch: Watch, dt: number): boolean
	local spawn = watch.car:GetAttribute("SpawnCFrame")
	if
		not lastLaunch[watch.player]
		and typeof(spawn) == "CFrame"
		and (spawn.Position - watch.sensor.hull.Position).Magnitude < Tuning.Reset.LavaSpawnClear
	then
		return false
	end
	damageCar(watch, Toughness.burn(watch.maxToughness, dt, T.LavaBurnTime), nil)
	return true
end

-- Smashing through a boulder costs toughness for the speed over its
-- BreakSpeed, on the side of the car that hit it, run or not.
boulderSmashed.Event:Connect(function(car: Model, velocity: Vector3, breakSpeed: number)
	local watch = watches[car]
	if not watch or watch.wrecked then
		return
	end
	local push = watch.sensor.hull.CFrame:VectorToObjectSpace(-velocity)
	local slot = Impact.slot(push.X, push.Y, push.Z)
	local strength = velocity.Magnitude
	local amount = Toughness.damage(strength, slot, {
		HitThreshold = breakSpeed,
		DamagePerSpeed = T.BoulderDamagePerSpeed,
		BreakDamage = T.BreakDamage,
	})
	if amount > 0 then
		damageCar(watch, amount, slot)
	end
	print(`Boulder {math.floor(strength + 0.5)} {slot}, damage {math.floor(amount + 0.5)}, {watch.player.Name}`)
	carImpact:FireClient(watch.player, strength, slot, watch.run.phase == "flying", amount, watch.toughness)
end)

local carEaten = Instance.new("BindableEvent")
carEaten.Name = "CarEaten"
carEaten.Event:Connect(function(car: Model)
	local watch = watches[car]
	if not watch or watch.wrecked or watch.eaten then
		return
	end
	watch.eaten = true
	if watch.run.phase == "flying" then
		table.insert(watch.targets, "T-Rex")
	end
	local result = RunTracker.abort(watch.run, "wrecked")
	if result then
		finish(watch, result)
	end
end)
carEaten.Parent = ServerStorage

-- Ends the player's run, if any, and respawns their car.
local function reset(player: Player)
	for _, watch in watches do
		if watch.player == player then
			local result = RunTracker.abort(watch.run)
			if result then
				finish(watch, result)
			end
			respawn(watch)
		end
	end
end

-- A reset only ends the player's own run and moves their car back to the
-- launcher, so it is safe to take from the client, with a gap against spam.
resetCar.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (lastResetAt[player] or -math.huge) < Tuning.Reset.RequestGap then
		return
	end
	lastResetAt[player] = now
	-- If the player has a car, reset it. If they are on foot, respawn
	-- their character so R always does something.
	local hasCar = false
	for _, watch in watches do
		if watch.player == player then
			hasCar = true
			break
		end
	end
	if hasCar then
		reset(player)
	else
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end
end)

local resetPlayerCar = Instance.new("BindableEvent")
resetPlayerCar.Name = "ResetPlayerCar"
resetPlayerCar.Event:Connect(reset)
resetPlayerCar.Parent = ServerStorage

-- Ends the player's run, if any, and builds their car at `cframe`. With
-- `home`, resets and wrecks come back here too until the next launch pad, and
-- the car takes a respawn lane there. False if the player has no car.
local function move(player: Player, cframe: CFrame, home: boolean): boolean
	if home then
		lastLaunch[player] = cframe
	end
	for _, watch in watches do
		if watch.player == player then
			local result = RunTracker.abort(watch.run)
			if result then
				finish(watch, result)
			end
			if home then
				respawn(watch)
			elseif not watch.respawning then
				watch.respawning = true
				respawnCar:Fire(player, cframe)
			end
			return true
		end
	end
	return false
end

local movePlayerCar = Instance.new("BindableFunction")
movePlayerCar.Name = "MovePlayerCar"
movePlayerCar.OnInvoke = move
movePlayerCar.Parent = ServerStorage

RunService.Heartbeat:Connect(function(dt: number)
	for car in watches do
		if car.Parent ~= carsFolder then
			watches[car] = nil
		end
	end
	for _, car in carsFolder:GetChildren() do
		if car:IsA("Model") then
			local watch = watchFor(car)
			if watch and watch.eaten then
				if not watch.wrecked then
					damageCar(watch, Toughness.burn(watch.maxToughness, dt, Tuning.Dino.Rex.Chew), nil)
					if watch.toughness <= 0 then
						wreck(watch)
					end
				end
			elseif watch then
				local reading = CarSensor.read(watch.sensor, dt)
				local respawnAt = reading.pad and reading.pad:GetAttribute("RespawnCFrame")
				if typeof(respawnAt) == "CFrame" then
					lastLaunch[watch.player] = respawnAt
				end
				if reading.pad then
					local payScale = reading.pad:GetAttribute("PayScale")
					watch.payScale = if typeof(payScale) == "number" then payScale else 1
				end
				if reading.lava and watch.run.phase == "flying" then
					splash(watch)
				end
				-- Still burning for LavaFireHold after it last touched lava, so a
				-- bounce does not put the fire out, and the boulders at the
				-- lake's edge let it out (PropService, CarController).
				if reading.lava and burn(watch, dt) then
					watch.burnedAt = os.clock()
				end
				local burning = os.clock() - watch.burnedAt < T.LavaFireHold
				if burning ~= watch.burning then
					watch.burning = burning
					car:SetAttribute("Burning", burning)
				end
				hurt(watch, reading.impact)
				if watch.toughness <= 0 and not watch.wrecked then
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
