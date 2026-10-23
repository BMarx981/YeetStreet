--!strict
local Check = require("./Check")
local Rex = require("../src/shared/Rex")
local Rng = require("../src/shared/Rng")
local Scatter = require("../src/shared/Scatter")

local TUNING: Rex.Tuning = {
	WalkSpeed = 20,
	RunSpeed = 70,
	Accel = 60,
	TurnRate = 60,
	Sight = 300,
	Lose = 450,
	RoamRadius = 400,
	GoalReach = 20,
	GoalTime = 30,
	Body = 50,
	Neck = 30,
	Reach = 110,
	BiteHeight = 110,
	Cone = 45,
	WindUp = 0.6,
	AirWindUp = 0.2,
	Snap = 0.2,
	Recover = 1,
	Rest = 4,
	Chew = 2.5,
	Bite = 14,
	AirHeight = 8,
	Gravity = 130,
}

local CIRCLE: Scatter.Line = { AX = 400, AZ = 0, BX = 400, BZ = 0, Radius = 150 }

local TERRITORY: Rex.Territory = {
	rect = { MinX = -5000, MaxX = 5000, MinZ = -5000, MaxZ = 5000 },
	keepOut = { CIRCLE },
	floor = 0,
}

local DT = 1 / 60
local GROUND = 2 -- a parked car's hull height

local function car(id: string, x: number, y: number, z: number, vx: number?, vy: number?, vz: number?): Rex.Car
	return { id = id, x = x, y = y, z = z, vx = vx or 0, vy = vy or 0, vz = vz or 0 }
end

-- Moves each car on by its speed, falling if it is in the air.
local function drive(cars: { Rex.Car }, dt: number)
	for _, c in cars do
		c.x += c.vx * dt
		c.z += c.vz * dt
		if c.y > TUNING.AirHeight or c.vy ~= 0 then
			c.vy -= TUNING.Gravity * dt
			c.y += c.vy * dt
		end
	end
end

-- Steps for `seconds`, calling `each` after every step. Returns the id of the
-- first car caught and when, if any.
local function run(
	s: Rex.State,
	cars: { Rex.Car },
	seconds: number,
	territory: Rex.Territory?,
	each: ((t: number) -> ())?
): (any?, number?)
	local rng = Rng.new(5)
	local caught, at = nil, nil
	for i = 1, math.floor(seconds / DT + 0.5) do
		local id = Rex.step(s, cars, territory or TERRITORY, rng, DT, TUNING)
		if id ~= nil and caught == nil then
			caught, at = id, i * DT
		end
		drive(cars, DT)
		if each then
			each(i * DT)
		end
	end
	return caught, at
end

Check.test("a new rex stands where it is put, roaming", function()
	local s = Rex.new(10, -20, math.rad(30))
	Check.eq(s.mode, "roam", "mode")
	Check.eq(s.x, 10, "x")
	Check.eq(s.z, -20, "z")
	Check.near(s.heading, math.rad(30), "heading")
	Check.eq(s.speed, 0, "speed")
end)

Check.test("forward faces -Z at heading 0 and turns left as heading grows", function()
	local fx, fz = Rex.forward(0)
	Check.near(fx, 0, "x at 0")
	Check.near(fz, -1, "z at 0")
	fx, fz = Rex.forward(math.pi / 2)
	Check.near(fx, -1, "x at 90")
	Check.near(fz, 0, "z at 90")
end)

Check.test("roaming walks no faster than WalkSpeed and stays in its territory, clear of keep-outs", function()
	local territory: Rex.Territory = {
		rect = { MinX = -600, MaxX = 600, MinZ = -600, MaxZ = 600 },
		keepOut = { CIRCLE },
		floor = 0,
	}
	local s = Rex.new(0, 0, 0)
	local farthest = 0
	run(s, {}, 300, territory, function()
		Check.eq(s.speed <= TUNING.WalkSpeed + 1e-6, true, `speed {s.speed}`)
		Check.eq(s.x >= -550 - 1e-6 and s.x <= 550 + 1e-6, true, `x {s.x}`)
		Check.eq(s.z >= -550 - 1e-6 and s.z <= 550 + 1e-6, true, `z {s.z}`)
		local clear = Scatter.distanceTo(CIRCLE, s.x, s.z)
		Check.eq(clear >= CIRCLE.Radius + TUNING.Body - 1e-6, true, `only {clear} from the keep-out`)
		farthest = math.max(farthest, math.sqrt(s.x * s.x + s.z * s.z))
	end)
	Check.eq(farthest > 200, true, `wandered only {farthest}`)
end)

Check.test("the same seed roams the same way", function()
	local a, b = Rex.new(0, 0, 0), Rex.new(0, 0, 0)
	run(a, {}, 30)
	run(b, {}, 30)
	Check.eq(a.x, b.x, "x")
	Check.eq(a.z, b.z, "z")
end)

Check.test("it chases the nearest car on the ground within Sight", function()
	local s = Rex.new(0, 0, 0)
	Rex.step(s, { car("far", -250, GROUND, 0), car("near", 0, GROUND, 200) }, TERRITORY, Rng.new(1), DT, TUNING)
	Check.eq(s.mode, "chase", "mode")
	Check.eq(s.target, "near", "target")

	local alone = Rex.new(0, 0, 0)
	Rex.step(alone, { car("away", 0, GROUND, 350) }, TERRITORY, Rng.new(1), DT, TUNING)
	Check.eq(alone.mode, "roam", "a car past Sight")
end)

Check.test("it never hunts a car in the air, in a keep-out, or outside its territory", function()
	local s = Rex.new(200, 0, 0)
	local cars = {
		car("flying", 200, 50, 150), -- behind it, so out of its jaws' reach too
		car("in keep-out", 400, GROUND, 0),
		car("outside", 200, GROUND, -150),
	}
	local territory: Rex.Territory = {
		rect = { MinX = -5000, MaxX = 5000, MinZ = -100, MaxZ = 5000 },
		keepOut = { CIRCLE },
		floor = 0,
	}
	run(s, cars, 0.5, territory)
	Check.eq(s.mode, "roam", "mode")
	Check.eq(s.target, nil, "target")
end)

Check.test("chasing, it turns at most TurnRate a second and runs no faster than RunSpeed", function()
	local s = Rex.new(0, 0, 0)
	local cars = { car("behind", 0, GROUND, 250) }
	local last = s.heading
	run(s, cars, 2, nil, function()
		local turned = math.abs((s.heading - last + math.pi) % (2 * math.pi) - math.pi)
		Check.eq(turned <= math.rad(TUNING.TurnRate) * DT + 1e-9, true, `turned {math.deg(turned)} in a step`)
		Check.eq(s.speed <= TUNING.RunSpeed + 1e-6, true, `speed {s.speed}`)
		last = s.heading
	end)
	Check.eq(s.mode, "chase", "still chasing")
	Check.near(math.abs(s.heading), math.rad(120), "turned 120 in 2 s", 1e-6)
end)

Check.test("a car driving away faster than RunSpeed gets away", function()
	local s = Rex.new(0, 0, 0)
	local cars = { car("quick", 0, GROUND, -200, 0, 0, -80) }
	run(s, cars, 60)
	Check.eq(s.mode, "roam", "gave up")
	Check.eq(s.target, nil, "no target")
	Check.eq(math.abs(cars[1].z - s.z) > TUNING.Lose, true, "left behind")
end)

Check.test("a parked car in front of its jaws is caught after WindUp + Snap", function()
	local s = Rex.new(0, 0, 0)
	local caught, at = run(s, { car("parked", 0, GROUND, -80) }, 1.5)
	Check.eq(caught, "parked", "caught")
	Check.near(at :: number, TUNING.WindUp + TUNING.Snap, "when", 3 * DT)
	Check.eq(s.mode, "rest", "rests after a catch")
	Check.near(s.jawX, 0, "jaw x")
	Check.near(s.jawY, GROUND, "jaw y")
	Check.near(s.jawZ, -80, "jaw z")
end)

Check.test("it bites where a moving car is going to be", function()
	local s = Rex.new(0, 0, 0)
	local caught = run(s, { car("passing", -60, GROUND, -80, 40, 0, 0) }, 1.5)
	Check.eq(caught, "passing", "caught")
	Check.near(s.jawX, -60 + 40 * (TUNING.WindUp + TUNING.Snap), "led the car", 1)
end)

Check.test("a car that gets out of the way during the wind-up is missed", function()
	local s = Rex.new(0, 0, 0)
	local cars = { car("dodger", 0, GROUND, -80) }
	Rex.step(s, cars, TERRITORY, Rng.new(1), DT, TUNING)
	Check.eq(s.mode, "lunge", "lunges")
	cars[1].vx = 80
	local caught = run(s, cars, TUNING.WindUp + TUNING.Snap + 0.05)
	Check.eq(caught, nil, "missed")
	Check.eq(s.mode, "recover", "recovers")
end)

Check.test("it never lunges at a car beside or behind it", function()
	local s = Rex.new(0, 0, 0)
	local caught = run(s, { car("beside", 90, GROUND, 0), car("behind", 0, GROUND, 60) }, 0.5)
	Check.eq(caught, nil, "caught")
	Check.eq(s.mode, "chase", "chases instead")
end)

Check.test("it snaps a car flying low past its head", function()
	local s = Rex.new(0, 0, 0)
	local caught = run(s, { car("low", -150, 60, -70, 150, 0, 0) }, 2)
	Check.eq(caught, "low", "caught")
end)

Check.test("a car flying high over its head is safe", function()
	local s = Rex.new(0, 0, 0)
	local caught = run(s, { car("high", -150, 300, -70, 150, 0, 0) }, 1.2)
	Check.eq(caught, nil, "caught")
	Check.eq(s.mode, "roam", "mode")
end)

Check.test("after a catch it rests for Rest seconds, ignoring cars, then hunts again", function()
	local s = Rex.new(0, 0, 0)
	local cars = { car("parked", 0, GROUND, -80) }
	local _, at = run(s, cars, 1.5)
	local resting = TUNING.Rest - (1.5 - (at :: number)) - 0.05
	local again = run(s, cars, resting, nil, function()
		Check.eq(s.mode, "rest", "still resting")
	end)
	Check.eq(again, nil, "caught while resting")
	run(s, cars, 0.2)
	Check.eq(s.mode ~= "rest", true, "hunting again")
end)

Check.test("it stands still for Chew seconds after a catch, then walks on", function()
	local s = Rex.new(0, 0, 0)
	local cars = { car("parked", 0, GROUND, -80) }
	local _, at = run(s, cars, TUNING.WindUp + TUNING.Snap + 0.1)
	cars[1].y = 500 -- held up in its jaws, out of the way
	local x, z = s.x, s.z
	run(s, cars, TUNING.Chew - (TUNING.WindUp + TUNING.Snap + 0.1 - (at :: number)) - 0.05, nil, function()
		Check.eq(s.x, x, "x while chewing")
		Check.eq(s.z, z, "z while chewing")
		Check.eq(s.speed, 0, "speed while chewing")
	end)
	run(s, cars, 1)
	Check.eq(s.x ~= x or s.z ~= z, true, "walks on")
end)

Check.test("chasing a car past a keep-out, it goes round, never in, and catches it", function()
	local small: Scatter.Line = { AX = 400, AZ = 0, BX = 400, BZ = 0, Radius = 60 }
	local territory: Rex.Territory = { rect = TERRITORY.rect, keepOut = { small }, floor = 0 }
	local s = Rex.new(250, 0, math.rad(-90)) -- facing +X, straight at it
	local caught = run(s, { car("beyond", 520, GROUND, 0) }, 20, territory, function()
		local clear = Scatter.distanceTo(small, s.x, s.z)
		Check.eq(clear >= small.Radius + TUNING.Body - 1e-6, true, `only {clear} from the keep-out`)
	end)
	Check.eq(caught, "beyond", "caught")
end)

Check.finish("Rex")
