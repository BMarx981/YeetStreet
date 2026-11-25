--!strict
-- ScoreService (Script) -> ServerScriptService.ScoreService
-- Scores every run on the server. Each Heartbeat it reads every car in
-- workspace.Cars through the same CarSensor, RunTracker, and Scoring the
-- driving client uses, but from the motion the server sees. The client never
-- sends a score; this one is the one that counts.
--
-- When a run ends, the driver's client gets the server's result on
-- ReplicatedStorage.RunResult, the total pays out as cash (Garage), scaled by
-- the PayScale of the launch pad the run started from, by the squad boost
-- for friends in the server (InviteRewards), and by the player's rebirth
-- multiplier (Rebirth), and, about 1 run in 12, by a lucky tier (Bonus), and
-- on a clean landing by the player's clean streak (Bonus), capped together at
-- Tuning.Bonus.Cap. The client gets these with the result (Bonus.Extras). A
-- better total becomes their Best in leaderstats and saves through PlayerData,
-- and goes out on ReplicatedStorage.NewBest for the banner (NewBest).
-- So do their longest airtime and this week's bests, for the leaderboards
-- (Leaderboard). A run from one of the record launchers (LaunchRecords), the
-- launcher of the last pad touched, is reported on ServerStorage.LauncherRun
-- with its distance, unless RunCheck flagged it.
-- InviteRewards hears of every run that ends, so a first run can credit the
-- player's inviter.
--
-- Each update of the car the server gets during a run also goes through
-- RunCheck, which says whether it could have been flown with the car's own
-- jets, and the result prints to Output when the run ends. The game's own
-- throws are excused (checkStep). A run that fails still pays as usual, but
-- never becomes the player's Best, and is logged (Analytics.flaggedRun).
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
-- Target points on that run. A run landing on a roof helipad (a part tagged
-- Helipad, CityRoofs) counts the Helipad target.
--
-- A car dropping into a roof pool's water (a part tagged Pool, CityRoofs)
-- banks its run as a landing with a Pool splash target, before it reaches
-- the bottom, so the touchdown does no damage. Falling in fast, run or not,
-- splashes on every client (ReplicatedStorage.PoolSplash).
--
-- A car coming down on lava (CarSensor) banks its run as a landing with a
-- Lava splash target. Lava, and smashing through a boulder too fast
-- (PropService fires ServerStorage.BoulderSmashed), damage the car run or
-- not; lava burns it until it drives out or wrecks, and sets its Burning
-- attribute while it does. The driver is never hurt.
--
-- The T-Rex catching a car (Parks.DinoRex fires ServerStorage.CarEaten with
-- "caught" and its name, the kaiju too) ends its run as a wreck, paying its
-- name as a target if it was in the air: base points kept, combo and clean
-- bonus lost. While held it takes no hits and starts no run. If it slips
-- free ("dropped") it carries on untouched; if it is chewed ("chewed") its
-- toughness drains evenly over
-- the creature's Chew seconds, then it wrecks. The pterodactyl carrying a
-- car (ServerStorage.CarCarried) holds it the same way, with no chewing,
-- until it drops it, which starts a run counting the whole fall. A player
-- the T-Rex swallows on foot (ServerStorage.PlayerEaten) comes back in a
-- fresh car at their last
-- launcher, or at the hub before their first, through CarService's
-- ServerStorage.GiveCar. Raptor bites (ServerStorage.CarBitten) cost
-- toughness, and shaking off or surviving a pack pays cash at once. A
-- PlaneCar's shot (ServerStorage.CarShot) costs toughness the same way, and
-- the shot that wrecks a car pays its shooter cash at once. The Scrapyard's
-- crusher (ServerStorage.CarCrushed) holds a car and chews it like the
-- T-Rex, over a time it works out from the car's toughness, and the crush
-- pays cash at once. So does a Hammer Alley hit. Each pays at most once
-- every so often per player (ScrapPay).
-- The shredder (ServerStorage.CarShredded) holds and chews a car the same
-- way; a run that comes down in it ends as a landing with a shredder target.
--
-- A train's nose pushing a car (Trains) does no damage. Nor does a
-- wrecking ball smacking a car (the driver's client pushes it,
-- WreckingBalls): that pays a Wrecking ball target on a run, or arms one
-- like a launch pad and pays the target once it takes off. The kaiju's
-- laser blasting a car (ServerStorage.CarZapped) is the same, paying a
-- Zapped target. So is a Scrapyard TNT barrel (ServerStorage.TntBlast),
-- paying a TNT target, but its blast also costs some toughness.
--
-- The gravitron (GravitronRide) does no damage either. High up its wall a
-- car on the surface is armed like on a launch pad, sets its respawn at the
-- nearest tube's funnel, and a run from there pays a Gravitron target, by
-- how fast it spins, once the car goes over the rim.
--
-- At zero toughness the car wrecks: every part left flies off, every client
-- bursts sparks and crunches there (ReplicatedStorage.CarWrecked, fired with
-- the position and the car, which the driver's replay records), and the run
-- ends as "wrecked". WreckBeat seconds later, so the driver sees it, the car
-- respawns.
-- A reset (the client asks on ReplicatedStorage.ResetCar, or ObbyService
-- fires ServerStorage.ResetPlayerCar after a fall) respawns at once.
-- Both build a fresh car at the last launcher the player used, through
-- CarService's ServerStorage.RespawnCar. A teleport (TeleportService invokes
-- ServerStorage.MovePlayerCar) ends the run the same way and builds the car
-- at its destination. In the obby, ObbyService sets a checkpoint
-- (ServerStorage.SetPlayerCheckpoint) that resets and wrecks come back to
-- instead, ahead of any launcher, until it clears it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Bonus = require(ReplicatedStorage.Bonus)
local CarSensor = require(ReplicatedStorage.CarSensor)
local CoolingTower = require(ReplicatedStorage.CoolingTower)
local Economy = require(ReplicatedStorage.Economy)
local GapZones = require(ReplicatedStorage.GapZones)
local GrindRails = require(ReplicatedStorage.GrindRails)
local GlobeRide = require(ReplicatedStorage.GlobeRide)
local GravitronRide = require(ReplicatedStorage.GravitronRide)
local Guns = require(ReplicatedStorage.Guns)
local Hammers = require(ReplicatedStorage.Hammers)
local Impact = require(ReplicatedStorage.Impact)
local Leaderboard = require(ReplicatedStorage.Leaderboard)
local MapLayout = require(ReplicatedStorage.MapLayout)
local NewBest = require(ReplicatedStorage.NewBest)
local Rebirth = require(ReplicatedStorage.Rebirth)
local RunCheck = require(ReplicatedStorage.RunCheck)
local RunTracker = require(ReplicatedStorage.RunTracker)
local Scoring = require(ReplicatedStorage.Scoring)
local ScrapPay = require(ReplicatedStorage.ScrapPay)
local Shredder = require(ReplicatedStorage.Shredder)
local Toughness = require(ReplicatedStorage.Toughness)
local Trains = require(ReplicatedStorage.Trains)
local Tuning = require(ReplicatedStorage.Tuning)
local WreckingBalls = require(ReplicatedStorage.WreckingBalls)
local Analytics = require(ServerScriptService.Analytics)
local CarDamage = require(ServerScriptService.CarDamage)
local DailyRewards = require(ServerScriptService.DailyRewards)
local Garage = require(ServerScriptService.Garage)
local InviteRewards = require(ServerScriptService.InviteRewards)
local Leaderstats = require(ServerScriptService.Leaderstats)
local PlayerData = require(ServerScriptService.PlayerData)

local T = Tuning.Toughness
-- Seconds a car off Hammer Alley's kicker stays armed with its target, long
-- enough to climb the kicker.
local ALLEY_ARM = 3

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
	-- The record launcher (LaunchRecords) of the last launch pad touched;
	-- nil if that pad is on none, or something else threw the car since.
	launcher: string?,
	wrecked: boolean,
	respawning: boolean, -- a respawn was asked for; the car is about to go
	burning: boolean, -- as the car's Burning attribute shows
	burnedAt: number, -- os.clock() when lava last burned it
	held: boolean, -- in the T-Rex's jaws or the pterodactyl's talons
	chewed: boolean, -- and being chewed
	chewFor: number, -- seconds the chewing takes
	-- os.clock() until which hits are not measured: a dropped car's speed
	-- jumps when its driver's game takes it back, which is not a hit.
	hitsFrom: number,
	ballAt: number, -- os.clock() when a wrecking ball last smacked it
	hammerAt: number, -- os.clock() when a Hammer Alley hammer last hit it
	alleyRun: boolean, -- running Hammer Alley from its start (ScrapPay.alleyRun)
	crushing: boolean, -- being crushed in the Scrapyard's crusher, which pays when it wrecks
	-- Launched off the ground by something other than a launch pad (a
	-- wrecking ball, the kaiju's laser): the run it arms pays this target
	-- once it takes off, and it stays armed until armUntil (os.clock()).
	armTarget: string?,
	armUntil: number,
	-- Armed high on the gravitron's wall: the run pays a Gravitron target
	-- once it goes over the rim.
	gravitronArmed: boolean,
	wet: boolean, -- in a pool's water at the last step
	-- Whether the run could have been flown (RunCheck), from each update of
	-- the hull the server gets while it flies, the last one being checkedAt.
	check: RunCheck.State?,
	checkedAt: CFrame?,
	-- The run started during Mega Boosters (EventService), by this server's
	-- Event attribute when its check began.
	mega: boolean,
	-- os.clock() when a launch pad, swing seat or rail last moved the car.
	thrownAt: number,
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

-- A run beat its player's Best (NewBest): sent to that player, or to every
-- client when it is big enough to shout, with the player and the new Best.
local newBest = Instance.new("RemoteEvent")
newBest.Name = "NewBest"
newBest.Parent = ReplicatedStorage

local watches: { [Model]: Watch } = {}
-- The RespawnCFrame of the last launch pad each player touched.
local lastLaunch: { [Player]: CFrame } = {}
-- The obby checkpoint each player in the obby respawns at.
local checkpoints: { [Player]: CFrame } = {}
local lastResetAt: { [Player]: number } = {}
local respawns = 0
-- Rolls lucky runs (Bonus).
local luckRandom = Random.new()
-- Each player's clean landings in a row (Bonus), also their CleanStreak
-- attribute for the HUD. Never saved, so it starts over on rejoin.
local streaks: { [Player]: number } = {}

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
	checkpoints[player] = nil
	lastResetAt[player] = nil
	streaks[player] = nil
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
		held = false,
		chewed = false,
		chewFor = Tuning.Dino.Rex.Chew,
		hitsFrom = -math.huge,
		ballAt = -math.huge,
		hammerAt = -math.huge,
		alleyRun = false,
		crushing = false,
		armTarget = nil,
		armUntil = -math.huge,
		gravitronArmed = false,
		wet = false,
		check = nil,
		checkedAt = nil,
		thrownAt = -math.huge,
		mega = false,
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

-- Fired with (player, launcher id, distance) when a run from a record
-- launcher (LaunchRecords) ends and RunCheck passed it.
local launcherRun = Instance.new("BindableEvent")
launcherRun.Name = "LauncherRun"
launcherRun.Parent = ServerStorage

-- By pad, its record launcher's id, worked out the first time the pad is
-- touched, so parks built or loaded at any time are covered; "" for a pad on
-- none.
local padLaunchers: { [BasePart]: string } = setmetatable({}, { __mode = "k" }) :: any

local function launcherOf(pad: BasePart): string?
	local known = padLaunchers[pad]
	if not known then
		known = ""
		for _, launcher in Tuning.LaunchRecords.Launchers do
			local model: Instance? = workspace
			for name in string.gmatch(launcher.Path, "[^%.]+") do
				model = if model then model:FindFirstChild(name) else nil
			end
			if model and pad:IsDescendantOf(model) then
				known = launcher.Id
				break
			end
		end
		padLaunchers[pad] = known
	end
	return if known ~= "" then known else nil
end

-- Whether a helipad lies just under the car.
local function onHelipad(watch: Watch): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged("Helipad")
	local reach = Vector3.new(0, -Tuning.Score.HelipadReach, 0)
	return workspace:Raycast(watch.sensor.hull.Position, reach, params) ~= nil
end

-- The Id of the area holding the player's last launch pad, or their car if
-- they have none; "None" outside every area.
local function parkOf(watch: Watch): string
	local launch = lastLaunch[watch.player]
	local at = if launch then launch.Position else watch.sensor.hull.Position
	for _, area: MapLayout.Area in Tuning.Map.Areas :: any do
		if MapLayout.contains(area, at.X, at.Z) then
			return area.Id
		end
	end
	return "None"
end

-- The car's own jets, as the server built it.
local function jets(watch: Watch): RunCheck.Stats
	local power = watch.car:GetAttribute("JetPower")
	local fuel = watch.car:GetAttribute("JetFuel")
	return {
		JetPower = if typeof(power) == "number" then power else 0,
		JetFuel = if typeof(fuel) == "number" then fuel else 0,
	}
end

-- Feeds RunCheck the hull as the server sees it now, if it moved since the
-- last update. The game's own throws are excused: while hits are not
-- measured (hitsFrom: the zap, a tower burst, a wrecking ball, a train, the
-- gravitron, the globe, a pterodactyl drop), and for ThrowGrace after a
-- launch pad, swing seat or rail moved it.
local function checkStep(watch: Watch)
	local hull = watch.sensor.hull
	local cf = hull.CFrame
	if cf == watch.checkedAt then
		return
	end
	watch.checkedAt = cf
	if not watch.check then
		watch.mega = workspace:GetAttribute("Event") == "Mega"
	end
	local check = watch.check or RunCheck.new()
	watch.check = check
	local now = os.clock()
	local velocity = hull.AssemblyLinearVelocity
	local excused = now < watch.hitsFrom or now - watch.thrownAt < Tuning.RunCheck.ThrowGrace
	local rail, railAt = GrindRails.ridden(cf.Position, velocity)
	RunCheck.step(check, {
		t = now,
		x = cf.X,
		y = cf.Y,
		z = cf.Z,
		vx = velocity.X,
		vy = velocity.Y,
		vz = velocity.Z,
		excused = excused,
		rail = rail,
		railAt = if rail then railAt else nil,
	}, jets(watch), Tuning.RunCheck)
end

local function finish(watch: Watch, result: RunTracker.Result)
	local check = watch.check
	watch.check = nil
	local flagged: RunCheck.Reason? = nil
	if check then
		local report = RunCheck.finish(check, jets(watch), Tuning.RunCheck)
		flagged = report.reason
		print(
			`Run check {report.reason or "ok"}: fuel {string.format("%.1f", report.fuel)} of {string.format(
				"%.1f",
				report.fuelLimit
			)} s, drift {math.floor(report.drift * 100 + 0.5)}% of limit, grind {math.floor(report.grind * 100 + 0.5)}% of limit, boost {math.floor(
				report.boost + 0.5
			)}, {watch.player.Name}`
		)
	end
	if result.ending == "landed" and onHelipad(watch) then
		table.insert(watch.targets, "Helipad")
	end
	result.gaps = GapZones.find(result)
	result.targets = watch.targets
	watch.targets = {}
	local score = Scoring.score(result, Tuning.Score, watch.smashes)
	watch.smashes = 0
	watch.toughness = watch.maxToughness
	watch.car:SetAttribute("ToughnessLeft", watch.toughness)
	local mega = watch.mega
	watch.mega = false
	local banner, shout = false, false
	if mega and not flagged then
		-- Mega Boosters runs pay, but count only for the Mega board.
		PlayerData.update(watch.player, function(data)
			data.MegaBest = math.max(data.MegaBest, score.total)
			local week = Leaderboard.weekRecord(data.ThisWeek, Leaderboard.week(os.time()))
			data.ThisWeek = Leaderboard.recordMega(week, score.total, Tuning.Leaderboards)
		end)
	elseif not flagged then
		local best = Leaderstats.value(watch.player, "Best")
		banner, shout = NewBest.check(best.Value, score.total, Tuning.NewBest)
		if score.total > best.Value then
			best.Value = score.total
		end
		PlayerData.update(watch.player, function(data)
			data.Best = math.max(data.Best, score.total)
			data.BestAirtime = math.max(data.BestAirtime, result.airtime)
			local week = Leaderboard.weekRecord(data.ThisWeek, Leaderboard.week(os.time()))
			data.ThisWeek = Leaderboard.recordRun(week, score.total, result.airtime, Tuning.Leaderboards)
		end)
	end
	local data = PlayerData.get(watch.player)
	local reborn = Rebirth.payMultiplier(if data then data.Rebirths else 0, Tuning.Rebirth)
	local rate = Tuning.Cash.PerPoint * watch.payScale * InviteRewards.squadBoost(watch.player) * reborn
	-- A flagged run is never doubled, and doesn't use up a double launch.
	local daily = if flagged then 1 else DailyRewards.launchMultiplier(watch.player, Economy.payout(score.total, rate))
	-- A flagged run, or one that scored nothing, is never lucky.
	local lucky = if flagged or score.total <= 0 then nil else Bonus.lucky(luckRandom:NextNumber(), Tuning.Bonus)
	-- A flagged run leaves the clean streak alone and is never paid for it.
	local streak = streaks[watch.player] or 0
	local streakPay = 1
	if not flagged then
		streak = Bonus.streakAfter(streak, result.ending, result.clean)
		streaks[watch.player] = streak
		watch.player:SetAttribute("CleanStreak", streak)
		if result.ending == "landed" and result.clean then
			streakPay = Bonus.streakMultiplier(streak, Tuning.Bonus)
		end
	end
	local bonus = Bonus.combined({ if lucky then lucky.Multiplier else 1, streakPay }, Tuning.Bonus)
	local paid = Economy.payout(score.total, rate * daily * bonus)
	Garage.pay(watch.player, paid, "Run")
	watch.payScale = 1
	local recordLauncher = if flagged or mega then nil else watch.launcher
	if recordLauncher then
		launcherRun:Fire(watch.player, recordLauncher, result.distance)
	end
	watch.launcher = nil
	local cash = watch.player:GetAttribute("Cash")
	local extras: Bonus.Extras = {
		lucky = lucky,
		streak = streak,
		paid = paid,
		cash = if typeof(cash) == "number" then cash else 0,
		launcher = recordLauncher,
	}
	runResult:FireClient(watch.player, result, score, extras)
	if shout then
		newBest:FireAllClients(watch.player, score.total)
	elseif banner then
		newBest:FireClient(watch.player, watch.player, score.total)
	end
	InviteRewards.ranRun(watch.player)
	Analytics.ranRun(watch.player, parkOf(watch), score.total, result.ending, paid)
	if flagged then
		local carId = watch.car:GetAttribute("CarId")
		Analytics.flaggedRun(watch.player, flagged, parkOf(watch), if typeof(carId) == "string" then carId else "None")
	end
end

local carsFolder = workspace:WaitForChild("Cars")
local respawnCar = ServerStorage:WaitForChild("RespawnCar") :: BindableEvent
local giveCar = ServerStorage:WaitForChild("GiveCar") :: BindableEvent
local propSmashed = ServerStorage:WaitForChild("PropSmashed") :: BindableEvent
local boulderSmashed = ServerStorage:WaitForChild("BoulderSmashed") :: BindableEvent

-- Only a smash in the air on a run counts.
propSmashed.Event:Connect(function(car: Model, target: string)
	local watch = watches[car]
	if watch and watch.run.phase == "flying" then
		table.insert(watch.targets, target)
	end
end)

-- Where a reset or wreck puts the car: its obby checkpoint, or the last
-- launcher's respawn point, in the next lane over, or the car's own spawn
-- lane before it has launched. Checkpoints take no lanes, as their pads are
-- narrow.
local function launcherPoint(player: Player): CFrame?
	local checkpoint = checkpoints[player]
	if checkpoint then
		return checkpoint
	end
	local base = lastLaunch[player]
	if not base then
		return nil
	end
	local R = Tuning.Reset
	respawns += 1
	local lane = respawns % R.RespawnLanes
	return base * CFrame.new((lane - (R.RespawnLanes - 1) / 2) * R.RespawnLaneSpacing, 0, 0)
end

local function respawnPoint(watch: Watch): CFrame?
	local point = launcherPoint(watch.player)
	if point then
		return point
	end
	local spawn = watch.car:GetAttribute("SpawnCFrame")
	return if typeof(spawn) == "CFrame" then spawn else nil
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
-- respawns fresh after `beat`, WreckBeat if not given.
local function wreck(watch: Watch, beat: number?)
	watch.wrecked = true
	local broken = math.min(CarDamage.breakParts(watch.car, nil, math.huge), T.WreckSmashes)
	if watch.run.phase == "flying" then
		watch.smashes += broken
	end
	carWrecked:FireAllClients(watch.sensor.hull.Position, watch.car)
	local result = RunTracker.abort(watch.run, "wrecked")
	if result then
		finish(watch, result)
	end
	task.delay(beat or T.WreckBeat, respawn, watch)
end

-- Coming down in lava or a pool ends the run as a landing, never clean,
-- paying the target (Lava or Pool) on it. Then lava burns the car (burn).
local function splash(watch: Watch, target: string)
	table.insert(watch.targets, target)
	local result = RunTracker.abort(watch.run, "landed")
	if result then
		finish(watch, result)
	end
end

local PS = Tuning.City.Roofs.PoolSplash

local poolSplash = Instance.new("RemoteEvent")
poolSplash.Name = "PoolSplash"
poolSplash.Parent = ReplicatedStorage

-- Whether a point is in a pool's water, or up to Margin above it.
local function inPool(position: Vector3): boolean
	for _, water in CollectionService:GetTagged("Pool") do
		if water:IsA("BasePart") then
			local at = water.CFrame:PointToObjectSpace(position)
			local half = water.Size / 2
			if
				math.abs(at.X) <= half.X
				and math.abs(at.Z) <= half.Z
				and at.Y >= -half.Y
				and at.Y <= half.Y + PS.Margin
			then
				return true
			end
		end
	end
	return false
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

-- A hit with a wrecking ball in reach of the car lately is the ball
-- smacking it (CarController), so no hit is measured for a moment. A jump
-- in its speed of at least Kick is a new smack, once every Cooldown: it pays
-- a Wrecking ball target on the run, or arms a run like a launch pad.
local function smack(watch: Watch, reading: CarSensor.Reading)
	local S = Tuning.City.Cranes.Server
	local strength = reading.impact.Magnitude
	if strength < T.ShowImpact then
		return
	end
	local time = workspace:GetServerTimeNow()
	if not WreckingBalls.smacked(watch.sensor.hull.Position, time - S.Lag, time, S.Slack) then
		return
	end
	local now = os.clock()
	watch.hitsFrom = math.max(watch.hitsFrom, now + S.HitGrace)
	if strength < S.Kick or now - watch.ballAt < S.Cooldown then
		return
	end
	watch.ballAt = now
	print(`Wrecking ball smack, {watch.player.Name}`)
	if watch.run.phase == "flying" then
		table.insert(watch.targets, "Wrecking ball")
	else
		watch.armTarget, watch.armUntil = "Wrecking ball", now
		reading.sample.onPad = true
	end
end

-- When each player was last paid by each of the Scrapyard's machines, by
-- kind. scrapDue says whether one is due now (ScrapPay.due), and if so
-- counts it as paid.
local scrapPaidAt: { [Player]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function scrapDue(player: Player, kind: string, gap: number): boolean
	local paid = scrapPaidAt[player]
	if not paid then
		paid = {}
		scrapPaidAt[player] = paid
	end
	local now = os.clock()
	if not ScrapPay.due(paid[kind], now, gap) then
		return false
	end
	paid[kind] = now
	return true
end

-- A Hammer Alley hammer in reach of the car lately is it knocking the car
-- (CarController, Hammers), so no hit is measured for a moment. A jump in
-- its speed of at least Kick is a hammer hit, once every Cooldown: it costs
-- HitDamage toughness on the side it hit, run or not, and can wreck it.
-- Returns whether it hit, for its pay (payHammerHit). In the lane, resets
-- and wrecks come back to its start, and it tracks whether the car is
-- running the lane from the start (ScrapPay.alleyRun) for the kicker's
-- Hammer Alley target.
local function hammer(watch: Watch, reading: CarSensor.Reading): boolean
	local A = Tuning.Scrapyard.Alley
	local S = A.Server
	local position = watch.sensor.hull.Position
	if Hammers.inLane(position) then
		lastLaunch[watch.player] = Hammers.respawn
	end
	local x, _, a = Hammers.toLane(position)
	watch.alleyRun = ScrapPay.alleyRun(A :: any, watch.alleyRun, x, a)
	local time = workspace:GetServerTimeNow()
	if not Hammers.smacked(position, time - S.Lag, time, S.Slack) then
		return false
	end
	local now = os.clock()
	watch.hitsFrom = math.max(watch.hitsFrom, now + S.HitGrace)
	local hit = reading.impact
	if hit.Magnitude < S.Kick or now - watch.hammerAt < S.Cooldown then
		return false
	end
	watch.hammerAt = now
	local slot = Impact.slot(hit.X, hit.Y, hit.Z)
	damageCar(watch, A.HitDamage, slot)
	print(
		`Hammer hit {slot}, damage {A.HitDamage}, toughness {math.floor(watch.toughness + 0.5)} left, {watch.player.Name}`
	)
	carImpact:FireClient(watch.player, hit.Magnitude, slot, watch.run.phase == "flying", A.HitDamage, watch.toughness)
	return true
end

-- A car in the gravitron takes no hits, nor for HitGrace after. On the
-- surface ArmHeight up it is armed like on a launch pad, and the run it
-- starts pays a Gravitron target, by how fast it spins, once over the rim.
-- Like a launch pad it also sets where resets and wrecks come back: the
-- nearest tube's funnel.
local function gravitron(watch: Watch, reading: CarSensor.Reading)
	local G = Tuning.Corkscrew.Gravitron
	local position = watch.sensor.hull.Position
	local inside = GravitronRide.inside(position)
	if inside then
		watch.hitsFrom = math.max(watch.hitsFrom, os.clock() + G.HitGrace)
	end
	if inside and not reading.airborne and GravitronRide.arms(position) then
		reading.sample.onPad = true
		watch.payScale = G.PayScale
		watch.launcher = nil
		watch.gravitronArmed = true
		lastLaunch[watch.player] = GravitronRide.respawn(position)
	elseif watch.gravitronArmed and watch.run.phase == "flying" and GravitronRide.overRim(position) then
		watch.gravitronArmed = false
		table.insert(watch.targets, GravitronRide.target(workspace:GetServerTimeNow()))
	elseif watch.run.phase == "idle" then
		watch.gravitronArmed = false
	end
end

-- A car in the globe takes no hits, nor for HitGrace after: its wall
-- pushing the car round the curve reads as a steady stream of them. Resets
-- and wrecks there, and leaving through its hatch (GlobeHatch asks for a
-- reset), come back to the globe's funnel, facing out.
local function globe(watch: Watch)
	if not GlobeRide.inside(watch.sensor.hull.Position) then
		return
	end
	watch.hitsFrom = math.max(watch.hitsFrom, os.clock() + Tuning.Corkscrew.Globe.HitGrace)
	local respawn = GlobeRide.exit()
	if respawn then
		lastLaunch[watch.player] = respawn
	end
end

-- A car rising fast out of a cooling tower's water during a burst was thrown
-- (CarController): no hit is measured for the jump in its speed, and it arms a
-- run like a launch pad, paying as usual. Resets and wrecks come back to the
-- tower's foot.
local plantArea = MapLayout.find(Tuning.Map.Areas :: any, "Plant")
local towerFoot = CoolingTower.footRadius(Tuning.Plant.Tower :: any)
local function towerBurst(watch: Watch, reading: CarSensor.Reading)
	if not plantArea then
		return
	end
	local W = Tuning.Plant.Water
	local p = watch.sensor.hull.Position
	local rising = watch.sensor.hull.AssemblyLinearVelocity.Y
	if rising < W.Server.Rise or p.Y - Tuning.Map.FloorTop > W.Server.Column then
		return
	end
	local time = workspace:GetServerTimeNow()
	for i, place in Tuning.Plant.Towers do
		local x, z = p.X - plantArea.X - place.X, p.Z - plantArea.Z - place.Z
		if x * x + z * z <= W.Radius * W.Radius and CoolingTower.erupting(W :: any, time, i, W.Server.Slack) then
			watch.hitsFrom = math.max(watch.hitsFrom, os.clock() + W.Server.HitGrace)
			reading.sample.onPad = true
			watch.payScale = 1
			watch.launcher = nil
			local at = Vector3.new(
				plantArea.X + place.X,
				Tuning.Map.FloorTop + Tuning.TestPark.SpawnHeight,
				plantArea.Z + place.Z + towerFoot + W.Respawn
			)
			lastLaunch[watch.player] = CFrame.lookAt(at, at - Vector3.zAxis)
			return
		end
	end
end

-- A hit with a train's nose where it pushes the car lately is the train
-- pushing it (CarController), so no hit is measured for a moment.
local function trainPush(watch: Watch, reading: CarSensor.Reading)
	if reading.impact.Magnitude < T.ShowImpact then
		return
	end
	local S = Tuning.City.Railway.Server
	local time = workspace:GetServerTimeNow()
	if Trains.touching(watch.sensor.hull.Position, time - S.Lag, time, S.Slack) then
		watch.hitsFrom = math.max(watch.hitsFrom, os.clock() + S.HitGrace)
	end
end

-- The kaiju's laser striking a car (Parks.CityKaiju fires
-- ServerStorage.CarZapped with the velocity it blasts it to): its driver's
-- game is told on ReplicatedStorage.Zapped and blasts it. That is no hit,
-- so for Grace no hit is measured and the run stays armed while the blast
-- reaches that game. It pays a Zapped target on the run, or on the run it
-- arms once it takes off.
local zapped = Instance.new("RemoteEvent")
zapped.Name = "Zapped"
zapped.Parent = ReplicatedStorage

local carZapped = Instance.new("BindableEvent")
carZapped.Name = "CarZapped"
carZapped.Event:Connect(function(car: Model, velocity: Vector3)
	local watch = watches[car]
	if not watch or watch.wrecked or watch.held then
		return
	end
	local now = os.clock()
	local grace = Tuning.City.Kaiju.Laser.Grace
	watch.hitsFrom = math.max(watch.hitsFrom, now + grace)
	if watch.run.phase == "flying" then
		table.insert(watch.targets, "Zapped")
	else
		watch.armTarget, watch.armUntil = "Zapped", now + grace
	end
	print(`Zapped {watch.player.Name}`)
	zapped:FireClient(watch.player, velocity)
end)
carZapped.Parent = ServerStorage

-- A Scrapyard TNT barrel blowing up near a car (Parks.ScrapyardTnt fires
-- ServerStorage.TntBlast with the velocity it throws the car at): it costs
-- BlastDamage toughness from underneath, run or not, and can wreck it.
-- Otherwise it is thrown like the kaiju's laser blasts a car, through the
-- same Zapped remote, paying a TNT target on the run, or on the run it arms.
-- A blast arms a run at most once every RunGap seconds, paying PayScale of
-- its cash; between, it only throws the car, with no run on either side.
local tntBlast = Instance.new("BindableEvent")
tntBlast.Name = "TntBlast"
tntBlast.Event:Connect(function(car: Model, velocity: Vector3)
	local watch = watches[car]
	if not watch or watch.wrecked or watch.held then
		return
	end
	local B = Tuning.Scrapyard.Tnt
	damageCar(watch, B.BlastDamage, "underside")
	if watch.toughness <= 0 then
		wreck(watch)
		return
	end
	local now = os.clock()
	watch.hitsFrom = math.max(watch.hitsFrom, now + B.Grace)
	local run = true
	if watch.run.phase == "flying" then
		table.insert(watch.targets, "TNT")
	elseif scrapDue(watch.player, "TntRun", B.RunGap) then
		watch.armTarget, watch.armUntil = "TNT", now + B.Grace
		watch.payScale = B.PayScale
	else
		run = false
	end
	print(
		`TNT blast{if run then "" else " (no run)"}, toughness {math.floor(watch.toughness + 0.5)} left, {watch.player.Name}`
	)
	zapped:FireClient(watch.player, velocity, not run)
end)
tntBlast.Parent = ServerStorage

local carEaten = Instance.new("BindableEvent")
carEaten.Name = "CarEaten"
carEaten.Event:Connect(function(car: Model, moment: "caught" | "chewed" | "dropped", kind: string?, chew: number?)
	local watch = watches[car]
	if not watch or watch.wrecked then
		return
	end
	if moment == "chewed" then
		watch.chewed = watch.held
		watch.chewFor = chew or Tuning.Dino.Rex.Chew
		return
	elseif moment == "dropped" then
		watch.held = false
		return
	elseif watch.held then
		return
	end
	watch.held = true
	if watch.run.phase == "flying" then
		table.insert(watch.targets, kind or "T-Rex")
	end
	local result = RunTracker.abort(watch.run, "wrecked")
	if result then
		finish(watch, result)
	end
end)
carEaten.Parent = ServerStorage

-- The pterodactyl carrying a car (Parks.DinoPtero fires
-- ServerStorage.CarCarried) ends any run it had, and while carried it takes
-- no hits and starts no run. When it is "dropped" a run starts there, its
-- height counted from the ground below (`groundY`) and its cash scaled by
-- `payScale`, or Tuning.Dino.Ptero.PayScale, and the driver's client is told
-- on ReplicatedStorage.DropRun so its live score starts too. The Scrapyard's
-- magnet crane (Parks.ScrapyardCrane) carries and drops cars the same way.
local dropRun = Instance.new("RemoteEvent")
dropRun.Name = "DropRun"
dropRun.Parent = ReplicatedStorage

local carCarried = Instance.new("BindableEvent")
carCarried.Name = "CarCarried"
carCarried.Event:Connect(function(car: Model, moment: "grabbed" | "dropped", groundY: number?, payScale: number?)
	local watch = watches[car]
	if not watch or watch.wrecked then
		return
	end
	if moment == "dropped" then
		watch.held = false
		local at = watch.sensor.hull.Position
		local ground = groundY or 0
		CarSensor.dropped(watch.sensor)
		watch.hitsFrom = os.clock() + Tuning.Dino.Ptero.DropGrace
		-- A plane with its wings out or a HeliCar with its rotor out never
		-- scores, so its drop is no run.
		if CarSensor.flying(car) then
			return
		end
		RunTracker.drop(watch.run, at.X, at.Y, at.Z, ground)
		watch.payScale = payScale or Tuning.Dino.Ptero.PayScale
		watch.launcher = nil
		dropRun:FireClient(watch.player, ground)
		return
	end
	watch.held = true
	local result = RunTracker.abort(watch.run)
	if result then
		finish(watch, result)
	end
end)
carCarried.Parent = ServerStorage

-- The raptors (Parks.DinoRaptors fires ServerStorage.CarBitten): a "bite"
-- takes Tuning.Dino.Raptors.BiteDamage of the car's full toughness on the
-- slot the raptor is on, run or not, and can wreck it. Shaking a pack off
-- ("shakeOff") and surviving its bites ("survived") pay cash at once, and
-- the driver's client shows it on ReplicatedStorage.CashBonus.
local cashBonus = Instance.new("RemoteEvent")
cashBonus.Name = "CashBonus"
cashBonus.Parent = ReplicatedStorage

local BITTEN_SLOTS: { [string]: string } =
	{ roof = "roof", hood = "nose", trunk = "tail", left = "sides", right = "sides" }

local carBitten = Instance.new("BindableEvent")
carBitten.Name = "CarBitten"
carBitten.Event:Connect(function(car: Model, moment: "bite" | "shakeOff" | "survived", slot: string?)
	local watch = watches[car]
	if not watch or watch.wrecked or watch.held then
		return
	end
	local Raptor = Tuning.Dino.Raptors
	if moment == "bite" then
		local amount = watch.maxToughness * Raptor.BiteDamage
		damageCar(watch, amount, slot and BITTEN_SLOTS[slot])
		print(
			`Raptor bite {slot}, damage {math.floor(amount + 0.5)}, toughness {math.floor(watch.toughness + 0.5)} left, {watch.player.Name}`
		)
		if watch.toughness <= 0 then
			wreck(watch)
		end
		return
	end
	local label, amount = "Raptor shake", Raptor.ShakeBonus
	if moment == "survived" then
		label, amount = "Survived the raptors", Raptor.SurviveBonus
	end
	Garage.pay(watch.player, amount, if moment == "survived" then "RaptorSurvive" else "RaptorShake")
	print(`{label}, paid {amount}, {watch.player.Name}`)
	cashBonus:FireClient(watch.player, label, amount)
end)
carBitten.Parent = ServerStorage

-- A PlaneCar's shot hitting a car (GunService fires ServerStorage.CarShot
-- with the car, the shooter, and which way the shot flew): it takes
-- Tuning.Guns.ShotDamage of the car's full toughness on the side it hit,
-- run or not, and can wreck it. The shot that wrecks it pays the shooter
-- Tuning.Guns.WreckBonus at once, shown on ReplicatedStorage.CashBonus, but
-- only once every BountyGap seconds for the same player shot down.
--
-- When each shooter was last paid for shooting down each player.
local bountyPaidAt: { [Player]: { [Player]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function payBounty(shooter: Player, victim: Player)
	local G = Tuning.Guns
	local paid = bountyPaidAt[shooter]
	if not paid then
		paid = setmetatable({}, { __mode = "k" }) :: any
		bountyPaidAt[shooter] = paid
	end
	local now = os.clock()
	if shooter.Parent ~= Players or not Guns.bountyDue(paid[victim], now, G.BountyGap) then
		return
	end
	paid[victim] = now
	Garage.pay(shooter, G.WreckBonus, "Bounty")
	local label = `Shot down {victim.DisplayName}`
	print(`{label}, paid {G.WreckBonus}, {shooter.Name}`)
	cashBonus:FireClient(shooter, label, G.WreckBonus)
end

local carShot = Instance.new("BindableEvent")
carShot.Name = "CarShot"
carShot.Event:Connect(function(car: Model, shooter: Player, direction: Vector3)
	local watch = watches[car]
	if not watch or watch.wrecked or watch.held then
		return
	end
	local push = watch.sensor.hull.CFrame:VectorToObjectSpace(direction)
	local slot = Impact.slot(push.X, push.Y, push.Z)
	local amount = watch.maxToughness * Tuning.Guns.ShotDamage
	damageCar(watch, amount, slot)
	print(
		`Shot by {shooter.Name} {slot}, damage {math.floor(amount + 0.5)}, toughness {math.floor(watch.toughness + 0.5)} left, {watch.player.Name}`
	)
	carImpact:FireClient(watch.player, amount, slot, watch.run.phase == "flying", amount, watch.toughness)
	if watch.toughness <= 0 then
		wreck(watch)
		payBounty(shooter, watch.player)
	end
end)
carShot.Parent = ServerStorage

-- A Downtown walker diving clear of a car (Parks.CityPedestrians fires
-- ServerStorage.PedestrianNearMiss) pays its driver at once, run or not.
-- Hitting one pays nothing and costs nothing.
local pedestrianNearMiss = Instance.new("BindableEvent")
pedestrianNearMiss.Name = "PedestrianNearMiss"
pedestrianNearMiss.Event:Connect(function(car: Model)
	local watch = watches[car]
	if not watch or watch.wrecked or watch.held then
		return
	end
	local amount = Tuning.City.Pedestrians.NearMissBonus
	Garage.pay(watch.player, amount, "NearMiss")
	print(`Near miss, paid {amount}, {watch.player.Name}`)
	cashBonus:FireClient(watch.player, "Near miss", amount)
end)
pedestrianNearMiss.Parent = ServerStorage

local playerEaten = Instance.new("BindableEvent")
playerEaten.Name = "PlayerEaten"
playerEaten.Event:Connect(function(player: Player)
	giveCar:Fire(player, launcherPoint(player))
end)
playerEaten.Parent = ServerStorage

-- A silo missile's blast (Parks.SiloMissile fires ServerStorage.CarBlasted):
-- the car wrecks at once, whatever its toughness, and respawns after `beat`
-- if given.
local carBlasted = Instance.new("BindableEvent")
carBlasted.Name = "CarBlasted"
carBlasted.Event:Connect(function(car: Model, beat: number?)
	local watch = watches[car]
	if watch and not watch.wrecked then
		wreck(watch, beat)
	end
end)
carBlasted.Parent = ServerStorage

-- A car crushed flat pays at once, by the tons the crusher reached
-- (ScrapPay.crush), at most once every PayGap seconds. One let out early
-- pays nothing.
local function payCrush(watch: Watch)
	local C = Tuning.Scrapyard.Crusher
	if not scrapDue(watch.player, "Crush", C.PayGap) then
		return
	end
	local amount = ScrapPay.crush(C, watch.chewFor)
	Garage.pay(watch.player, amount, "Crush")
	print(`Crushed, paid {amount}, {watch.player.Name}`)
	cashBonus:FireClient(watch.player, "Crushed", amount)
end

-- A Hammer Alley hit pays HitPay cash at once, at most once every HitPayGap
-- seconds.
local function payHammerHit(watch: Watch)
	local A = Tuning.Scrapyard.Alley
	if scrapDue(watch.player, "HammerHit", A.HitPayGap) then
		Garage.pay(watch.player, A.HitPay, "HammerHit")
		cashBonus:FireClient(watch.player, "Hammer hit", A.HitPay)
	end
end

-- The Scrapyard's crusher (Parks.ScrapyardCrusher fires
-- ServerStorage.CarCrushed). "grabbed" holds the car like the T-Rex does,
-- ending any run, and resets and wrecks come back to `respawnAt`, in front
-- of the crusher. "crush" drains all its toughness evenly over `seconds`,
-- breaking parts as it goes, then it wrecks and pays (payCrush).
local carCrushed = Instance.new("BindableEvent")
carCrushed.Name = "CarCrushed"
carCrushed.Event:Connect(function(car: Model, moment: "grabbed" | "crush", respawnAt: CFrame?, seconds: number?)
	local watch = watches[car]
	if not watch or watch.wrecked then
		return
	end
	if moment == "crush" then
		watch.chewed = watch.held
		watch.crushing = watch.held
		watch.chewFor = seconds or Tuning.Scrapyard.Crusher.CrushBase
		return
	end
	if watch.held then
		return
	end
	watch.held = true
	if respawnAt then
		lastLaunch[watch.player] = respawnAt
	end
	local result = RunTracker.abort(watch.run)
	if result then
		finish(watch, result)
	end
end)
carCrushed.Parent = ServerStorage

-- The Scrapyard's shredder (Parks.ScrapyardShredder fires
-- ServerStorage.CarShredded) holds a car like the T-Rex does and chews it
-- over `seconds` until it wrecks. Coming down in it is the jump's goal, so
-- a run ends as a landing (combo kept, never clean), paying a target by how
-- far it flew (Shredder.target).
local carShredded = Instance.new("BindableEvent")
carShredded.Name = "CarShredded"
carShredded.Event:Connect(function(car: Model, seconds: number)
	local watch = watches[car]
	if not watch or watch.wrecked or watch.held then
		return
	end
	watch.held = true
	watch.chewed = true
	watch.chewFor = seconds
	local result = RunTracker.abort(watch.run, "landed")
	if result then
		table.insert(watch.targets, Shredder.target(Tuning.Scrapyard.Shredder :: any, result.distance))
		finish(watch, result)
	end
end)
carShredded.Parent = ServerStorage

-- Ends the player's run, if any, and respawns their car. A rider stays on
-- their missile until it hits.
local function reset(player: Player)
	for _, watch in watches do
		if watch.player == player and watch.car:GetAttribute("OnMissile") ~= true then
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

-- Sets where the player's resets and wrecks come back, or clears it with nil.
-- A function, not an event, so it has taken effect by the time a teleport
-- right after it respawns the car.
local setPlayerCheckpoint = Instance.new("BindableFunction")
setPlayerCheckpoint.Name = "SetPlayerCheckpoint"
setPlayerCheckpoint.OnInvoke = function(player: Player, cframe: CFrame?)
	checkpoints[player] = cframe
end
setPlayerCheckpoint.Parent = ServerStorage
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
			if watch and watch.held then
				if watch.chewed and not watch.wrecked then
					damageCar(watch, Toughness.burn(watch.maxToughness, dt, watch.chewFor), nil)
					if watch.toughness <= 0 then
						if watch.crushing then
							payCrush(watch)
						end
						wreck(watch)
					end
				end
			elseif watch then
				local reading = CarSensor.read(watch.sensor, dt)
				local pad = reading.pad or if watch.run.phase ~= "flying" then reading.padBelow else nil
				local respawnAt = pad and pad:GetAttribute("RespawnCFrame")
				if typeof(respawnAt) == "CFrame" then
					lastLaunch[watch.player] = respawnAt
				end
				if pad then
					local payScale = pad:GetAttribute("PayScale")
					watch.payScale = if typeof(payScale) == "number" then payScale else 1
					watch.launcher = launcherOf(pad)
					-- Off Hammer Alley's kicker, having run the lane from the start.
					if pad:GetAttribute("AlleyKicker") == true and watch.alleyRun then
						watch.alleyRun = false
						watch.armTarget, watch.armUntil = "Hammer Alley", os.clock() + ALLEY_ARM
					end
				end
				if reading.pad or reading.padBelow or reading.sample.swing or reading.sample.grinding then
					watch.thrownAt = os.clock()
				end
				if reading.lava and watch.run.phase == "flying" then
					splash(watch, "Lava")
				end
				local wet = inPool(watch.sensor.hull.Position)
				if wet and not watch.wet then
					local falling = -watch.sensor.hull.AssemblyLinearVelocity.Y
					if falling > PS.Speed then
						poolSplash:FireAllClients(watch.sensor.hull.Position, falling)
					end
					if watch.run.phase == "flying" then
						splash(watch, "Pool")
					end
				end
				watch.wet = wet
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
				smack(watch, reading)
				if hammer(watch, reading) then
					payHammerHit(watch)
				end
				trainPush(watch, reading)
				gravitron(watch, reading)
				globe(watch)
				towerBurst(watch, reading)
				if os.clock() >= watch.hitsFrom then
					hurt(watch, reading.impact)
				end
				-- Armed until it leaves the ground, so the run counts from
				-- there; in the air already, armed once, and it flies.
				local waiting = not reading.airborne or watch.run.phase == "idle"
				if watch.armTarget and os.clock() < watch.armUntil and watch.run.phase ~= "flying" and waiting then
					reading.sample.onPad = true
				end
				if watch.toughness <= 0 and not watch.wrecked then
					wreck(watch)
				else
					local wasFlying = watch.run.phase == "flying"
					local result = RunTracker.step(watch.run, reading.sample, Tuning.Run)
					if result then
						finish(watch, result)
					end
					if not wasFlying and watch.run.phase == "flying" then
						Analytics.reach(watch.player, "FirstLaunch")
					end
					if watch.run.phase == "flying" then
						checkStep(watch)
					end
				end
				local armTarget = watch.armTarget
				if armTarget and watch.run.phase == "flying" then
					watch.armTarget = nil
					table.insert(watch.targets, armTarget)
				elseif armTarget and watch.run.phase == "idle" and os.clock() >= watch.armUntil then
					watch.armTarget = nil
				end
			end
		end
	end
end)
