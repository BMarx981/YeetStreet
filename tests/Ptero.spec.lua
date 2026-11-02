--!strict
local Check = require("./Check")
local Ptero = require("../src/shared/Ptero")
local Rng = require("../src/shared/Rng")
local Scatter = require("../src/shared/Scatter")

local TUNING: Ptero.Tuning = {
	CruiseHeight = 300,
	CruiseSpeed = 70,
	TurnRate = 40,
	Accel = 60,
	ClimbRate = 40,
	Edge = 250,
	GoalReach = 60,
	GoalTime = 30,
	Sight = 400,
	AirHeight = 8,
	Warn = 1.5,
	DiveSpeed = 150,
	DiveTurnRate = 90,
	DiveDrop = 150,
	SwoopTime = 6,
	Lose = 600,
	Grab = 14,
	CarTop = 1,
	Recover = 5,
	CarryHeight = 800,
	CarryClimb = 110,
	CarrySpeed = 90,
	CarryRadius = 150,
	CarryEdge = 450,
	EscapeJets = 0.6,
	FumbleChance = 0.3,
	FumbleFrom = 250,
	FumbleTo = 650,
	PerchTime = 10,
	PerchReach = 20,
	SnatchReach = 48,
	SnatchHeight = 12,
}

local CIRCLE: Scatter.Line = { AX = 400, AZ = 0, BX = 400, BZ = 0, Radius = 150 }

local TERRITORY: Ptero.Territory = {
	rect = { MinX = -2000, MaxX = 2000, MinZ = -2000, MaxZ = 2000 },
	keepOut = { CIRCLE },
	floor = 0,
}

local DT = 1 / 60
local GROUND = 2 -- a parked car's hull height
local PERCH_Y = 260

local function car(id: string, x: number, y: number, z: number, vx: number?, vz: number?): Ptero.Car
	return { id = id, x = x, y = y, z = z, vx = vx or 0, vy = 0, vz = vz or 0 }
end

-- A pterodactyl circling over the middle at its cruise height.
local function circling(x: number?, z: number?): Ptero.State
	local s = Ptero.new(0, PERCH_Y, 0, 0)
	s.x, s.z = x or 0, z or 0
	s.mode = "circle"
	s.y = TUNING.CruiseHeight
	s.speed = TUNING.CruiseSpeed
	return s
end

-- Steps for `seconds`, driving each car on by its speed and calling `each`
-- after every step. Returns the id of the first car grabbed and when, if any.
local function run(s: Ptero.State, cars: { Ptero.Car }, seconds: number, each: ((t: number) -> ())?): (any?, number?)
	local rng = Rng.new(5)
	local grabbed, at = nil, nil
	for i = 1, math.floor(seconds / DT + 0.5) do
		local id = Ptero.step(s, cars, TERRITORY, rng, DT, TUNING)
		if id ~= nil and grabbed == nil then
			grabbed, at = id, i * DT
		end
		for _, c in cars do
			c.x += c.vx * DT
			c.z += c.vz * DT
		end
		if each then
			each(i * DT)
		end
	end
	return grabbed, at
end

-- Steps until `done` says so, for at most `seconds`. Returns the id of the
-- first car grabbed, if any, and the seconds it took.
local function runUntil(s: Ptero.State, cars: { Ptero.Car }, seconds: number, done: () -> boolean): (any?, number)
	local rng = Rng.new(5)
	local grabbed = nil
	for i = 1, math.floor(seconds / DT + 0.5) do
		local id = Ptero.step(s, cars, TERRITORY, rng, DT, TUNING)
		if id ~= nil and grabbed == nil then
			grabbed = id
		end
		if done() then
			return grabbed, i * DT
		end
	end
	return grabbed, seconds
end

local function flat(s: Ptero.State): number
	return math.sqrt(s.x * s.x + s.z * s.z)
end

Check.test("a new pterodactyl sits on its perch", function()
	local s = Ptero.new(10, PERCH_Y, -20, math.rad(30))
	Check.eq(s.mode, "perch", "mode")
	Check.eq(s.x, 10, "x")
	Check.eq(s.y, PERCH_Y, "y")
	Check.eq(s.z, -20, "z")
	Check.near(s.heading, math.rad(30), "heading")
	Check.eq(s.speed, 0, "speed")
end)

Check.test("it sits PerchTime ignoring cars, then flies up to its cruise height", function()
	local s = Ptero.new(0, PERCH_Y, 0, 0)
	local cars = { car("below", 50, GROUND, 50) }
	run(s, cars, TUNING.PerchTime - 0.1)
	Check.eq(s.mode, "perch", "still perched")
	Check.eq(s.x, 0, "has not moved")
	run(s, {}, 0.2)
	Check.eq(s.mode, "circle", "took off")
	run(s, {}, 20)
	Check.near(s.y, TUNING.CruiseHeight, "cruise height", 1e-3)
end)

Check.test("circling stays over its territory at cruise height and speed", function()
	local s = circling()
	local farthest = 0
	run(s, {}, 300, function()
		Check.eq(s.speed <= TUNING.CruiseSpeed + 1e-6, true, `speed {s.speed}`)
		Check.eq(math.abs(s.x) <= 2000 and math.abs(s.z) <= 2000, true, `out at {s.x}, {s.z}`)
		Check.near(s.y, TUNING.CruiseHeight, "height", 1e-3)
		farthest = math.max(farthest, flat(s))
	end)
	Check.eq(farthest > 500, true, `wandered only {farthest}`)
end)

Check.test("the same seed circles the same way", function()
	local a, b = circling(), circling()
	run(a, {}, 30)
	run(b, {}, 30)
	Check.eq(a.x, b.x, "x")
	Check.eq(a.z, b.z, "z")
end)

Check.test("circling, it swoops on the nearest car on the ground within Sight", function()
	local s = circling()
	Ptero.step(s, { car("far", -350, GROUND, 0), car("near", 0, GROUND, 200) }, TERRITORY, Rng.new(1), DT, TUNING)
	Check.eq(s.mode, "swoop", "mode")
	Check.eq(s.target, "near", "target")
end)

Check.test("it never swoops on a car in the air, past Sight, in a keep-out or outside its territory", function()
	for _, c in
		{
			car("flying", 0, 40, 200),
			car("far", 0, GROUND, 450),
			car("kept out", 400, GROUND, 50),
			car("outside", -2100, GROUND, 0),
		}
	do
		local s = circling(if c.id == "outside" then -1900 else 0)
		Ptero.step(s, { c }, TERRITORY, Rng.new(1), DT, TUNING)
		Check.eq(s.mode, "circle", c.id)
	end
end)

Check.test("it holds its height through the warning, then dives and grabs a parked car", function()
	local s = circling()
	local cars = { car("parked", 0, GROUND, 300) }
	local grabbed, at = run(s, cars, TUNING.Warn + TUNING.SwoopTime, function(t)
		if t < TUNING.Warn - DT then
			Check.near(s.y, TUNING.CruiseHeight, `height at {t}`, 1e-3)
		end
	end)
	Check.eq(grabbed, "parked", "grabbed")
	Check.eq(s.mode, "carry", "mode")
	Check.eq((at :: number) > TUNING.Warn, true, `grabbed at {at}`)
end)

Check.test("it grabs a car driving slowly along", function()
	local s = circling()
	local grabbed = run(s, { car("slow", 0, GROUND, 250, 30, 0) }, TUNING.Warn + TUNING.SwoopTime)
	Check.eq(grabbed, "slow", "grabbed")
end)

Check.test("a fast car gets away, and it climbs back ignoring cars before circling", function()
	local s = circling()
	local cars = { car("fast", 0, GROUND, 300, 0, 250) }
	run(s, cars, DT)
	Check.eq(s.mode, "swoop", "swooping")
	local grabbed = runUntil(s, cars, TUNING.Warn + TUNING.SwoopTime + 0.1, function()
		return s.mode ~= "swoop"
	end)
	Check.eq(grabbed, nil, "grabbed")
	Check.eq(s.mode, "recover", "mode")
	-- A parked car right under it while it recovers.
	local under = { car("under", s.x, GROUND, s.z) }
	run(s, under, TUNING.Recover - 0.2)
	Check.eq(s.mode, "recover", "still recovering")
	run(s, under, 0.3)
	Check.eq(s.mode ~= "recover", true, "done recovering")
end)

Check.test("it gives up on a car that takes off", function()
	local s = circling()
	local cars = { car("jumper", 0, GROUND, 300) }
	run(s, cars, 0.5)
	Check.eq(s.mode, "swoop", "swooping")
	cars[1].y = 50
	run(s, cars, DT)
	Check.eq(s.mode, "recover", "mode")
end)

Check.test("carrying, it spirals up to CarryHeight at CarrySpeed and stays there", function()
	local s = circling()
	run(s, { car("parked", 0, GROUND, 300) }, TUNING.Warn + TUNING.SwoopTime)
	Check.eq(s.mode, "carry", "mode")
	local climb = (TUNING.CarryHeight - s.y) / TUNING.CarryClimb
	local cx, cz = s.spinX, s.spinZ
	run(s, {}, climb + 20, function()
		Check.eq(s.y <= TUNING.CarryHeight + 1e-6, true, `height {s.y}`)
	end)
	Check.near(s.y, TUNING.CarryHeight, "height", 1e-6)
	Check.near(s.speed, TUNING.CarrySpeed, "speed", 1e-6)
	local r = math.sqrt((s.x - cx) ^ 2 + (s.z - cz) ^ 2)
	Check.near(r, TUNING.CarryRadius, "spiral radius", 15)
end)

Check.test("its spiral stays CarryEdge inside its territory", function()
	local s = circling(1900, 0)
	s.heading = math.pi / 2 -- facing -X, its left toward +Z
	run(s, { car("edge", 1900, GROUND, 200) }, TUNING.Warn + TUNING.SwoopTime)
	Check.eq(s.mode, "carry", "mode")
	Check.eq(s.spinX <= 2000 - TUNING.CarryEdge + 1e-6, true, `centre x {s.spinX}`)
end)

Check.test("let go, it flies home ignoring cars and perches again", function()
	local s = circling(800, 800)
	s.mode = "carry"
	s.y = TUNING.CarryHeight
	Ptero.letGo(s)
	Check.eq(s.mode, "home", "mode")
	local cars = { car("under", 0, GROUND, 100) }
	local grabbed = runUntil(s, cars, 60, function()
		return s.mode ~= "home"
	end)
	Check.eq(grabbed, nil, "grabbed")
	Check.eq(s.mode, "perch", "mode")
	Check.eq(s.x, 0, "x")
	Check.eq(s.y, PERCH_Y, "y")
	Check.eq(s.z, 0, "z")
end)

Check.test("a catch fumbles under FumbleChance, somewhere between FumbleFrom and FumbleTo", function()
	Check.eq(Ptero.fumble(0.3, 0.5, TUNING), nil, "at the chance")
	Check.eq(Ptero.fumble(0.9, 0.5, TUNING), nil, "above it")
	Check.near(Ptero.fumble(0.1, 0, TUNING) :: number, 250, "lowest")
	Check.near(Ptero.fumble(0.1, 1, TUNING) :: number, 650, "highest")
	Check.near(Ptero.fumble(0.29, 0.5, TUNING) :: number, 450, "middle")
end)

Check.test("it lets go on EscapeJets of jets, at a fumble's height, or at the top", function()
	Check.eq(Ptero.releases(100, 0, nil, TUNING), false, "low, no jets")
	Check.eq(Ptero.releases(100, 0.6, nil, TUNING), true, "jets")
	Check.eq(Ptero.releases(400, 0.5, 450, TUNING), false, "under the fumble")
	Check.eq(Ptero.releases(450, 0, 450, TUNING), true, "at the fumble")
	Check.eq(Ptero.releases(799, 0, nil, TUNING), false, "under the top")
	Check.eq(Ptero.releases(800, 0, nil, TUNING), true, "the top")
end)

-- A car parked on top of the spire, whose top is the perch at the middle.
local function onTop(id: string?): Ptero.Car
	return car(id or "climber", 25, PERCH_Y + 3, 10)
end

Check.test("a car reaching the top wakes it on its perch and is grabbed at once", function()
	local s = Ptero.new(0, PERCH_Y, 0, 0)
	local grabbed, at = run(s, { onTop() }, 5)
	Check.eq(grabbed, "climber", "grabbed")
	Check.eq(at ~= nil and at < 3, true, "soon")
	Check.eq(s.mode, "carry", "mode")
end)

Check.test("it comes straight back from far away, up from low down, and grabs", function()
	for _, start in { { 1500, 300 }, { -1200, 20 }, { 60, 10 } } do
		local s = circling(start[1])
		s.y = start[2]
		local grabbed, at = run(s, { onTop() }, 25)
		Check.eq(grabbed, "climber", `grabbed from {start[1]}, {start[2]}`)
		Check.eq(at ~= nil and at < 20, true, `soon from {start[1]}, {start[2]}`)
	end
end)

Check.test("it comes straight back while recovering or flying home", function()
	for _, mode: Ptero.Mode in { "recover", "home" } do
		local s = circling(500)
		s.mode = mode
		local grabbed = run(s, { onTop() }, 15)
		Check.eq(grabbed, "climber", mode)
	end
end)

Check.test("it drops a car it was swooping on for the one on top", function()
	local s = circling(300)
	local parked = car("parked", 300, GROUND, 200)
	run(s, { parked }, 0.5)
	Check.eq(s.mode, "swoop", "swooping")
	Check.eq(s.target, "parked", "on the parked car")
	local grabbed = run(s, { parked, onTop() }, 15)
	Check.eq(grabbed, "climber", "grabbed")
end)

Check.test("a car in its talons comes first: the one on top waits its turn", function()
	local s = circling(1000)
	s.mode = "carry"
	local grabbed = run(s, { onTop() }, 3)
	Check.eq(grabbed, nil, "nothing new")
	Check.eq(s.mode, "carry", "still carrying")
	Ptero.letGo(s)
	Check.eq(run(s, { onTop() }, 20), "climber", "grabbed after letting go")
end)

Check.test("it never gives up on a car on top, however long it takes", function()
	local s = circling(1900)
	s.y = TUNING.CruiseHeight
	-- Far past Lose, and further than SwoopTime of flying.
	local grabbed = run(s, { onTop() }, 30)
	Check.eq(grabbed, "climber")
end)

Check.test("a car still climbing, below the top, wakes nothing", function()
	local s = Ptero.new(0, PERCH_Y, 0, 0)
	Check.eq(run(s, { car("climber", 40, PERCH_Y - 8, 0) }, 5), nil, "below")
	Check.eq(s.mode, "perch", "still perched")
end)

Check.test("a car flying over the top, or past its edge, wakes nothing", function()
	local s = Ptero.new(0, PERCH_Y, 0, 0)
	Check.eq(run(s, { car("over", 0, PERCH_Y + 13, 0) }, 2), nil, "over it")
	Check.eq(run(s, { car("past", 49, PERCH_Y + 3, 0) }, 2), nil, "past the edge")
	Check.eq(s.mode, "perch", "still perched")
end)

Check.test("a car that reached the top is still caught after driving off it", function()
	local s = circling(800)
	local climber = onTop()
	run(s, { climber }, 1)
	Check.eq(s.mode, "swoop", "on its way")
	climber.y = 100 -- back down the ledge or falling, and past the top's edge
	climber.x = 120
	Check.eq(run(s, { climber }, 15), "climber", "grabbed")
end)

Check.test("it catches a car still driving away after reaching the top", function()
	local s = circling(800)
	local climber = onTop()
	run(s, { climber }, 0.1)
	climber.x, climber.z = 60, 0
	climber.vx, climber.vz = -40, 0
	climber.y = PERCH_Y - 20
	local grabbed = run(s, { climber }, 25)
	Check.eq(grabbed, "climber")
end)

Check.test("it gives up on a car that gets back to the ground out of reach", function()
	local s = circling(800)
	local climber = onTop()
	run(s, { climber }, 1)
	-- On the ground inside a keep-out, where it never swoops.
	climber.x, climber.y, climber.z = 400, GROUND, 0
	Check.eq(run(s, { climber }, 1), nil, "no grab")
	Check.eq(s.mode, "recover", "gave up")
	climber.y = 100
	Check.eq(run(s, { climber }, 1), nil, "forgotten once given up")
end)

Check.test("the car it drops is not chased again", function()
	local s = circling(100)
	local climber = onTop()
	Check.eq(run(s, { climber }, 15), "climber", "grabbed")
	Ptero.letGo(s)
	climber.x, climber.y, climber.z = 500, 500, 500 -- falling from where it was dropped
	Check.eq(run(s, { climber }, 2), nil, "no second grab")
	Check.eq(s.mode, "home", "flies home")
end)

Check.finish("Ptero")
