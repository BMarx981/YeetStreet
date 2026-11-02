--!strict
-- FlightProbe (ModuleScript) -> ServerStorage.Dev.FlightProbe
-- A Studio tool that measures what the server sees of each car while it is
-- off the ground or grinding, so the limits for checking runs can be picked
-- from real flights. The game never requires it. Start it once in a Play
-- server (execute_luau, or the command bar on the Server view):
--
--   require(game.ServerStorage.Dev.FlightProbe).start("http://127.0.0.1:8787/")
--
-- The url is optional. With it, each stretch is posted there as JSON with
-- every update the server saw, for test cases (needs HttpEnabled for the
-- session). Starting it twice does nothing.
--
-- A stretch runs from leaving the ground (or starting a grind) to touching
-- down. For each one longer than MIN_STRETCH it prints the car's jet stats
-- and what the server saw: how often the hull actually moved (updates),
-- peak speed, climb, height and spin rate, the longest step between updates,
-- hits (a change in speed gravity does not explain of at least ShowImpact),
-- the push left over once hits are taken out, and how much the car's energy
-- rose, as the seconds of burn its JetPower would need for that rise. Energy
-- and push are worked out twice: from the velocity the client reports, and
-- from positions alone. Drift is how far the hull strayed from where the
-- reported velocity would have taken it, since a client can report any
-- velocity.
--
-- Every car's gaps between updates while moving are also kept, and the
-- ServerStorage.FlightProbeReport BindableFunction prints them.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CarSensor = require(ReplicatedStorage.CarSensor)
local Tuning = require(ReplicatedStorage.Tuning)

local FlightProbe = {}

local MIN_STRETCH = 0.4 -- seconds
local MOVING = 5 -- studs per second; slower and a car may not be sending updates
local MAX_GAPS = 20000

type Point = {
	t: number,
	p: Vector3,
	v: Vector3,
	cf: CFrame,
}

type Stretch = {
	started: number,
	heartbeats: number,
	points: { Point },
	events: { string },
	pad: string?,
	grind: boolean,
	flags: { [string]: boolean },
}

type Track = {
	car: Model,
	hull: BasePart,
	player: Player?,
	sensor: CarSensor.Sensor,
	last: CFrame?,
	lastAt: number,
	padAt: number,
	pad: string?,
	stretch: Stretch?,
}

local tracks: { [Model]: Track } = {}
local gaps: { number } = {}
local heartbeatsMoving = 0
local postUrl: string? = nil

local function number(car: Model, name: string): number
	local value = car:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function trackFor(car: Model): Track?
	local existing = tracks[car]
	if existing then
		return existing
	end
	local hull = car:FindFirstChild("Hull")
	local userId = car:GetAttribute("OwnerUserId")
	local player = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local character = player and player.Character
	if not (hull and hull:IsA("BasePart") and character) then
		return nil
	end
	local sensor = CarSensor.new(car, { character })
	if not sensor then
		return nil
	end
	local track: Track = {
		car = car,
		hull = hull,
		player = player,
		sensor = sensor,
		last = nil,
		lastAt = os.clock(),
		padAt = -math.huge,
		pad = nil,
		stretch = nil,
	}
	tracks[car] = track
	return track
end

local function event(car: Model, what: string)
	local track = tracks[car]
	local stretch = track and track.stretch
	if stretch then
		table.insert(stretch.events, `{what}@{string.format("%.2f", os.clock() - stretch.started)}`)
	end
end

local function median(list: { number }): number
	if #list == 0 then
		return 0
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.max(math.floor(#sorted * 0.5 + 0.5), 1)]
end

local function percentile(sorted: { number }, p: number): number
	if #sorted == 0 then
		return 0
	end
	return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

local function summarize(track: Track, stretch: Stretch): { [string]: any }
	local g = workspace.Gravity
	local car = track.car
	local jetPower = math.max(number(car, "JetPower"), 1)
	local points = stretch.points
	local first, last = points[1], points[#points]
	local s: { [string]: any } = {
		player = if track.player then track.player.Name else "?",
		carId = car:GetAttribute("CarId") or car.Name,
		jetPower = number(car, "JetPower"),
		jetFuel = number(car, "JetFuel"),
		turnRate = number(car, "TurnRate"),
		pad = stretch.pad,
		events = stretch.events,
		grind = stretch.grind,
		flags = stretch.flags,
		seconds = last.t - first.t,
		heartbeats = stretch.heartbeats,
		updates = #points,
		distance = Vector3.new(last.p.X - first.p.X, 0, last.p.Z - first.p.Z).Magnitude,
		peakSpeed = 0,
		peakSpeedFromPositions = 0,
		peakClimb = -math.huge,
		peakHeight = 0,
		maxGap = 0,
		medianGap = 0,
		maxStep = 0,
		peakSpin = 0,
		totalTurn = 0,
		hits = 0,
		peakPush = 0, -- largest push left over, studs per second squared
		push = 0, -- push left over, summed, studs per second
		pushFromPositions = 0,
		jetSeconds = 0,
		jetSecondsFromPositions = 0,
		hitEnergy = 0, -- energy gained in steps with a hit, per unit mass
		-- How far the hull moved from where the reported velocity says it
		-- should be: in the worst step, and over the whole stretch.
		stepDrift = 0,
		drift = 0,
	}
	local expected = Vector3.zero
	local stepGaps: { number } = {}
	local lastPositionVelocity: Vector3? = nil
	for i, point in points do
		s.peakSpeed = math.max(s.peakSpeed, point.v.Magnitude)
		s.peakClimb = math.max(s.peakClimb, point.v.Y)
		s.peakHeight = math.max(s.peakHeight, point.p.Y - first.p.Y)
		if i == 1 then
			continue
		end
		local before = points[i - 1]
		local dt = point.t - before.t
		if dt <= 0 then
			continue
		end
		table.insert(stepGaps, dt)
		local step = point.p - before.p
		s.maxStep = math.max(s.maxStep, step.Magnitude)
		local _, angle = before.cf:ToObjectSpace(point.cf):ToAxisAngle()
		s.totalTurn += angle
		s.peakSpin = math.max(s.peakSpin, angle / dt)

		-- From the reported velocity.
		local change = point.v - before.v + Vector3.new(0, g * dt, 0)
		local hit = change.Magnitude >= Tuning.Toughness.ShowImpact
		local gain = 0.5 * (point.v.Magnitude ^ 2 - before.v.Magnitude ^ 2) + g * step.Y
		local speed = math.max((point.v.Magnitude + before.v.Magnitude) / 2, 10)
		local stepExpected = (point.v + before.v) / 2 * dt
		expected += stepExpected
		s.stepDrift = math.max(s.stepDrift, (step - stepExpected).Magnitude)
		if hit then
			s.hits += 1
			s.hitEnergy += math.max(gain, 0)
		else
			s.push += change.Magnitude
			s.peakPush = math.max(s.peakPush, change.Magnitude / dt)
			s.jetSeconds += math.max(gain, 0) / (jetPower * speed)
		end

		-- From positions alone: the velocity over each step between updates.
		local positionVelocity = step / dt
		s.peakSpeedFromPositions = math.max(s.peakSpeedFromPositions, positionVelocity.Magnitude)
		if lastPositionVelocity then
			local lastDt = stepGaps[#stepGaps - 1] or dt
			local mid = (dt + lastDt) / 2
			local positionChange = positionVelocity - lastPositionVelocity + Vector3.new(0, g * mid, 0)
			local midRise = (point.p.Y - points[i - 2].p.Y) / 2
			local positionGain = 0.5 * (positionVelocity.Magnitude ^ 2 - lastPositionVelocity.Magnitude ^ 2)
				+ g * midRise
			if positionChange.Magnitude < Tuning.Toughness.ShowImpact then
				s.pushFromPositions += positionChange.Magnitude
				local positionSpeed = math.max((positionVelocity.Magnitude + lastPositionVelocity.Magnitude) / 2, 10)
				s.jetSecondsFromPositions += math.max(positionGain, 0) / (jetPower * positionSpeed)
			end
		end
		lastPositionVelocity = positionVelocity
	end
	s.maxGap = 0
	for _, gap in stepGaps do
		s.maxGap = math.max(s.maxGap, gap)
	end
	s.medianGap = median(stepGaps)
	s.drift = (last.p - first.p - expected).Magnitude
	s.pushBudget = number(car, "JetPower") * number(car, "JetFuel")
	return s
end

local function round(x: number, places: number?): string
	return string.format(`%.{places or 0}f`, x)
end

local function report(s: { [string]: any })
	local flags = {}
	for name in s.flags do
		table.insert(flags, name)
	end
	print(
		`[FlightProbe] {s.player} {s.carId} jets {s.jetPower}/{round(s.jetFuel, 1)}s turn {round(s.turnRate, 1)}`
			.. ` pad {s.pad or "-"}{if s.grind then " grind" else ""} {table.concat(flags, ",")} {table.concat(
				s.events,
				","
			)}`
	)
	print(
		`  {round(s.seconds, 2)}s, {s.updates} updates in {s.heartbeats} heartbeats, gap median {round(
			s.medianGap * 1000
		)}ms max {round(s.maxGap * 1000)}ms, step max {round(s.maxStep, 1)}`
	)
	print(
		`  speed {round(s.peakSpeed)} (positions {round(s.peakSpeedFromPositions)}), climb {round(s.peakClimb)}, height {round(
			s.peakHeight
		)}, distance {round(s.distance)}, spin {round(s.peakSpin, 1)} rad/s, turned {round(s.totalTurn, 1)} rad`
	)
	print(
		`  hits {s.hits} (energy {round(s.hitEnergy)}), push {round(s.push)} (positions {round(s.pushFromPositions)}) of budget {round(
			s.pushBudget
		)}, peak push {round(s.peakPush)}, jet seconds {round(s.jetSeconds, 2)} (positions {round(
			s.jetSecondsFromPositions,
			2
		)}) of {round(s.jetFuel, 1)}`
	)
	print(`  drift from reported velocity: step max {round(s.stepDrift, 2)}, whole stretch {round(s.drift, 1)}`)
end

local function post(s: { [string]: any }, points: { Point })
	local url = postUrl
	if not url then
		return
	end
	local rows = {}
	for _, point in points do
		local cf = point.cf
		table.insert(
			rows,
			{ point.t, point.p.X, point.p.Y, point.p.Z, point.v.X, point.v.Y, point.v.Z, cf:GetComponents() }
		)
	end
	local body = HttpService:JSONEncode({ summary = s, points = rows })
	task.spawn(function()
		local ok, problem = pcall(HttpService.PostAsync, HttpService, url, body)
		if not ok then
			warn(`[FlightProbe] post failed: {problem}`)
		end
	end)
end

local function finish(track: Track)
	local stretch = track.stretch
	track.stretch = nil
	if not stretch or #stretch.points < 2 then
		return
	end
	local s = summarize(track, stretch)
	if s.seconds < MIN_STRETCH then
		return
	end
	report(s)
	post(s, stretch.points)
end

local function step(dt: number)
	local now = os.clock()
	local carsFolder = workspace:FindFirstChild("Cars")
	if not carsFolder then
		return
	end
	for car, track in tracks do
		if car.Parent ~= carsFolder then
			finish(track)
			tracks[car] = nil
		end
	end
	for _, car in carsFolder:GetChildren() do
		local track = if car:IsA("Model") then trackFor(car) else nil
		if not track then
			continue
		end
		local cf = track.hull.CFrame
		local velocity = track.hull.AssemblyLinearVelocity
		local fresh = cf ~= track.last
		local moving = velocity.Magnitude > MOVING
		if moving then
			heartbeatsMoving += 1
		end
		if fresh then
			if moving and track.last and #gaps < MAX_GAPS then
				table.insert(gaps, now - track.lastAt)
			end
			track.last = cf
			track.lastAt = now
		end

		local reading = CarSensor.read(track.sensor, dt)
		local pad = reading.pad or reading.padBelow
		if pad then
			track.pad = `{pad.Name} {pad:GetAttribute("LaunchSpeed") or "?"}`
			track.padAt = now
		end
		local off = reading.airborne or reading.sample.grinding
		local stretch = track.stretch
		if off and not stretch then
			stretch = {
				started = now,
				heartbeats = 0,
				points = {},
				events = {},
				pad = if now - track.padAt < 2 then track.pad else nil,
				grind = false,
				flags = {},
			}
			track.stretch = stretch
			table.insert(stretch.points, { t = now, p = cf.Position, v = velocity, cf = cf })
		elseif stretch and not off then
			finish(track)
			continue
		end
		if stretch then
			stretch.heartbeats += 1
			if fresh then
				table.insert(stretch.points, { t = now, p = cf.Position, v = velocity, cf = cf })
			end
			stretch.grind = stretch.grind or reading.sample.grinding
			for _, name in { "WingsOut", "RotorOut", "OnMissile", "PlaneCar", "HeliCar" } do
				if car:GetAttribute(name) == true then
					stretch.flags[name] = true
				end
			end
			if track.hull.Anchored then
				stretch.flags.Anchored = true
			end
		end
	end
end

-- Prints the gaps between updates seen from every moving car since start.
local function printGaps()
	local sorted = table.clone(gaps)
	table.sort(sorted)
	local ms = function(x: number): string
		return round(x * 1000)
	end
	print(
		`[FlightProbe] {#sorted} updates in {heartbeatsMoving} moving heartbeats; gap median {ms(
			percentile(sorted, 0.5)
		)}ms, p90 {ms(percentile(sorted, 0.9))}ms, p99 {ms(percentile(sorted, 0.99))}ms, max {ms(
			percentile(sorted, 1)
		)}ms`
	)
end

function FlightProbe.start(url: string?)
	if ServerStorage:FindFirstChild("FlightProbeReport") then
		return
	end
	postUrl = url
	for _, name in { "CarZapped", "CarCarried", "CarEaten", "CarBlasted" } do
		local bindable = ServerStorage:FindFirstChild(name)
		if bindable and bindable:IsA("BindableEvent") then
			bindable.Event:Connect(function(car: any, moment: any)
				if typeof(car) == "Instance" and car:IsA("Model") then
					event(car, if typeof(moment) == "string" then `{name}:{moment}` else name)
				end
			end)
		end
	end
	local reportFn = Instance.new("BindableFunction")
	reportFn.Name = "FlightProbeReport"
	reportFn.OnInvoke = printGaps
	reportFn.Parent = ServerStorage
	RunService.Heartbeat:Connect(step)
	print(`[FlightProbe] started, gravity {workspace.Gravity}`)
end

return FlightProbe
