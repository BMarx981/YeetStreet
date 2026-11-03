--!strict
local Check = require("./Check")
local RunCheck = require("../src/shared/RunCheck")

-- Same values as Tuning.RunCheck, which this test can't require.
local T: RunCheck.Tuning = {
	Gravity = 130,
	Window = 0.5,
	HitChange = 20,
	FuelMargin = 1.3,
	FuelSlack = 1,
	MinJetPower = 50,
	BoostSlack = 2000,
	DriftWindow = 1,
	DriftBase = 40,
	DriftGapScale = 2,
}

type Flight = {
	jetPower: number,
	jetFuel: number,
	excused: { { number } }?,
	points: { { number } },
}

local FLIGHTS: { [string]: Flight } = {
	LongJump450Triceratops = require("./flights/LongJump450Triceratops"),
	LongJump450Hatchback = require("./flights/LongJump450Hatchback"),
	SkateWallJets = require("./flights/SkateWallJets"),
	CorkscrewHitches = require("./flights/CorkscrewHitches"),
	VolcanoVent = require("./flights/VolcanoVent"),
	KaijuZap = require("./flights/KaijuZap"),
	TowerBurst = require("./flights/TowerBurst"),
	SiloFoldedHeli = require("./flights/SiloFoldedHeli"),
}

local function excused(flight: Flight, t: number): boolean
	for _, span in flight.excused or {} do
		if t >= span[1] and t <= span[2] then
			return true
		end
	end
	return false
end

-- Checks a recorded flight, keeping only every `every`th update (as a server
-- getting fewer updates would), against `stats` (the flight's own car if nil),
-- with its excused times marked unless `unmarked`.
local function check(flight: Flight, every: number?, stats: RunCheck.Stats?, unmarked: boolean?): RunCheck.Report
	local state = RunCheck.new()
	local car = stats or { JetPower = flight.jetPower, JetFuel = flight.jetFuel }
	for i, p in flight.points do
		if (i - 1) % (every or 1) == 0 or i == #flight.points then
			RunCheck.step(state, {
				t = p[1],
				x = p[2],
				y = p[3],
				z = p[4],
				vx = p[5],
				vy = p[6],
				vz = p[7],
				excused = not unmarked and excused(flight, p[1]),
			}, car, T)
		end
	end
	return RunCheck.finish(state, car, T)
end

-- Samples at 60 a second for `seconds`, from `at(t)` giving position and
-- velocity.
local function made(seconds: number, at: (number) -> (number, number, number, number, number, number)): RunCheck.Report
	local state = RunCheck.new()
	local car = { JetPower = 200, JetFuel = 3.9 }
	for i = 0, math.floor(seconds * 60) do
		local t = i / 60
		local x, y, z, vx, vy, vz = at(t)
		RunCheck.step(state, { t = t, x = x, y = y, z = z, vx = vx, vy = vy, vz = vz }, car, T)
	end
	return RunCheck.finish(state, car, T)
end

local function ballistic(t: number): (number, number, number, number, number, number)
	return 100 * t, 200 * t - 65 * t * t, 0, 100, 200 - 130 * t, 0
end

for name, flight in FLIGHTS do
	for _, every in { 1, 2, 3 } do
		Check.test(`real flight {name} passes with every {every} update(s)`, function()
			local report = check(flight, every)
			Check.eq(
				report.reason,
				nil,
				`reason (fuel {report.fuel} of {report.fuelLimit}, drift {report.drift}, boost {report.boost})`
			)
		end)
	end
end

Check.test("a full burn uses about the whole tank", function()
	local report = check(FLIGHTS.LongJump450Hatchback)
	Check.near(report.fuel, 3.9, "fuel", 0.4)
	Check.near(report.fuelLimit, 3.9 * 1.3 + 1, "limit")
end)

Check.test("a flight with no jets uses next to no fuel", function()
	local report = made(3, ballistic)
	Check.eq(report.reason, nil)
	Check.near(report.fuel, 0, "fuel", 0.05)
end)

Check.test("a real full burn is too much for a car with a smaller tank", function()
	-- What a cheat giving itself endless fuel looks like.
	local report = check(FLIGHTS.LongJump450Hatchback, 1, { JetPower = 200, JetFuel = 1.5 })
	Check.eq(report.reason, "Fuel")
end)

Check.test("a real full burn is too much for a car with weaker jets", function()
	local report = check(FLIGHTS.LongJump450Triceratops, 1, { JetPower = 80, JetFuel = 1.5 })
	Check.eq(report.reason, "Fuel")
end)

Check.test("the volcano's vent booster without its mark is a boost", function()
	Check.eq(check(FLIGHTS.VolcanoVent, 1, nil, true).reason, "Boost")
end)

Check.test("a tower burst without its mark is a boost", function()
	Check.eq(check(FLIGHTS.TowerBurst, 1, nil, true).reason, "Boost")
end)

Check.test("a zap without its mark is a boost", function()
	Check.eq(check(FLIGHTS.KaijuZap, 1, nil, true).reason, "Boost")
end)

Check.test("a car with no jets is measured as if it had MinJetPower", function()
	-- The Frog Car has JetPower 0; half a second held up is push it could
	-- only get from a scrape or a bounce.
	local state = RunCheck.new()
	local car = { JetPower = 0, JetFuel = 1 }
	for i = 0, 30 do
		RunCheck.step(state, { t = i / 60, x = 0, y = 300, z = 0, vx = 0, vy = 0, vz = 0 }, car, T)
	end
	local report = RunCheck.finish(state, car, T)
	Check.eq(report.reason, nil)
	Check.near(report.fuel, 65 / 50, "fuel", 0.05)
end)

Check.test("hovering in place for longer than the tank lasts runs out of fuel", function()
	local report = made(20, function()
		return 0, 300, 0, 0, 0, 0
	end)
	Check.eq(report.reason, "Fuel")
end)

Check.test("hovering for less than the tank lasts is fine", function()
	local report = made(3, function()
		return 0, 300, 0, 0, 0, 0
	end)
	Check.eq(report.reason, nil)
end)

Check.test("sliding a flying car sideways that its velocity doesn't show drifts", function()
	local report = made(3, function(t)
		local x, y, z, vx, vy, vz = ballistic(t)
		return x, y, z + 120 * t, vx, vy, vz
	end)
	Check.eq(report.reason, "Drift")
end)

Check.test("jumping a car 200 studs up in one step drifts", function()
	local report = made(3, function(t)
		local x, y, z, vx, vy, vz = ballistic(t)
		return x, y + (if t >= 1.5 then 200 else 0), z, vx, vy, vz
	end)
	Check.eq(report.reason, "Drift")
end)

Check.test("speeding a flying car up in one go is a boost", function()
	local report = made(3, function(t)
		local x, y, z, vx, vy, vz = ballistic(t)
		if t >= 1.5 then
			return x + 200 * (t - 1.5), y, z, vx + 200, vy, vz
		end
		return x, y, z, vx, vy, vz
	end)
	Check.eq(report.reason, "Boost")
end)

Check.test("speeding up in one go while excused passes", function()
	local state = RunCheck.new()
	local car = { JetPower = 200, JetFuel = 3.9 }
	for i = 0, 180 do
		local t = i / 60
		local x, y, z, vx, vy, vz = ballistic(t)
		if t >= 1.5 then
			x, vx = x + 200 * (t - 1.5), vx + 200
		end
		local sample = { t = t, x = x, y = y, z = z, vx = vx, vy = vy, vz = vz, excused = t >= 1.4 and t <= 2 }
		RunCheck.step(state, sample, car, T)
	end
	Check.eq(RunCheck.finish(state, car, T).reason, nil)
end)

Check.test("updates with the same time are skipped", function()
	local state = RunCheck.new()
	local car = { JetPower = 200, JetFuel = 3.9 }
	for i = 0, 60 do
		local x, y, z, vx, vy, vz = ballistic(i / 60)
		local sample = { t = i / 60, x = x, y = y, z = z, vx = vx, vy = vy, vz = vz }
		RunCheck.step(state, sample, car, T)
		RunCheck.step(state, sample, car, T)
	end
	Check.eq(RunCheck.finish(state, car, T).reason, nil)
end)

Check.test("the first failure is the reason", function()
	-- Slides sideways from the start, then hovers far past its fuel.
	local report = made(20, function(t)
		return 0, 300, 120 * t, 0, 0, 0
	end)
	Check.eq(report.reason, "Drift")
end)

Check.test("a run with one update passes", function()
	local state = RunCheck.new()
	local car = { JetPower = 200, JetFuel = 3.9 }
	RunCheck.step(state, { t = 0, x = 0, y = 0, z = 0, vx = 0, vy = 0, vz = 0 }, car, T)
	Check.eq(RunCheck.finish(state, car, T).reason, nil)
end)

Check.finish("RunCheck")
