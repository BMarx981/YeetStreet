--!strict
local Check = require("./Check")
local Laser = require("../src/shared/Laser")

local TUNING: Laser.Tuning = {
	MinRange = 140,
	MaxRange = 500,
	Charge = 1.5,
	Lock = 0.4,
	Cooldown = 5,
	Cancel = 1.5,
	BeamRadius = 10,
	Lift = 200,
	Push = 60,
	Keep = 0.5,
	Gravity = 130,
}

local DT = 1 / 60
local EYE = { x = 0, y = 140, z = 0 }

local function car(id: string, x: number, z: number, visible: boolean?, vx: number?): Laser.Car
	return { id = id, x = x, y = 2, z = z, vx = vx or 0, vy = 0, vz = 0, visible = visible ~= false, air = false }
end

-- Steps for `seconds`; returns when it fired, if it did.
local function run(s: Laser.State, cars: { Laser.Car }, seconds: number, canFire: boolean?): number?
	for i = 1, math.floor(seconds / DT + 0.5) do
		for _, c in cars do
			c.x += c.vx * DT
		end
		if Laser.step(s, EYE.x, EYE.y, EYE.z, cars, canFire ~= false, DT, TUNING) then
			return i * DT
		end
	end
	return nil
end

Check.test("it charges at a car it can see that is too far to bite", function()
	local s = Laser.new()
	run(s, { car("near", 0, -100), car("far", 0, -300), car("beyond", 0, -600) }, DT)
	Check.eq(s.mode, "charge")
	Check.eq(s.target, "far")
end)

Check.test("it never charges at a car it cannot see", function()
	local s = Laser.new()
	run(s, { car("hidden", 0, -300, false) }, 1)
	Check.eq(s.mode, "ready")
end)

Check.test("it fires Charge seconds after it starts, then cools down", function()
	local s = Laser.new()
	local fired = run(s, { car("far", 0, -300) }, 3) :: number
	Check.near(fired, TUNING.Charge + DT, "fired", DT + 1e-6)
	Check.eq(s.mode, "cool")
	Check.eq(run(s, { car("far", 0, -300) }, TUNING.Cooldown - 0.1), nil, "no shot while cooling")
end)

Check.test("the aim locks Lock before the shot, leading the car", function()
	local s = Laser.new()
	local cars = { car("moving", 0, -300, true, 50) }
	run(s, cars, TUNING.Charge - TUNING.Lock + DT)
	Check.eq(s.locked, true)
	Check.near(s.aimX, cars[1].x + 50 * TUNING.Lock, "where it will be when the shot lands", 1)
	local lockedX = s.aimX
	run(s, cars, 0.2)
	Check.near(s.aimX, lockedX, "the aim no longer follows it")
end)

Check.test("a car in the air is led falling", function()
	local s = Laser.new()
	local flying: Laser.Car =
		{ id = "air", x = 0, y = 100, z = -300, vx = 0, vy = 0, vz = 0, visible = true, air = true }
	run(s, { flying }, TUNING.Charge - TUNING.Lock + DT)
	Check.near(s.aimY, 100 - 0.5 * 130 * TUNING.Lock ^ 2, "falls Lock seconds' worth", 0.5)
end)

Check.test("losing sight of its car before the lock calls the shot off", function()
	local s = Laser.new()
	local cars = { car("ducks", 0, -300) }
	run(s, cars, 0.5)
	cars[1].visible = false
	run(s, cars, DT)
	Check.eq(s.mode, "cool")
	Check.near(s.timer, TUNING.Cancel, "cools down for Cancel", DT)
end)

Check.test("once locked, it fires even if its car hides", function()
	local s = Laser.new()
	local cars = { car("late", 0, -300) }
	run(s, cars, TUNING.Charge - TUNING.Lock + DT)
	cars[1].visible = false
	Check.eq(run(s, cars, 1) ~= nil, true, "fired")
end)

Check.test("it calls the shot off when it may not fire", function()
	local s = Laser.new()
	run(s, { car("far", 0, -300) }, 0.5)
	run(s, { car("far", 0, -300) }, DT, false)
	Check.eq(s.mode, "cool")
end)

Check.test("struck is the car nearest the beam within BeamRadius", function()
	-- The beam slopes down from the eyes to the ground at its end.
	local cars = { car("off", 30, -400), car("on", 5, -398), car("past", 0, -450) }
	Check.eq(Laser.struck(0, 140, 0, 0, 2, -400, cars, TUNING), "on")
	Check.eq(Laser.struck(0, 140, 0, 0, 2, -400, { cars[1], cars[3] }, TUNING), nil, "none in the beam")
end)

Check.test("a blast throws the car up Lift and away along the beam, keeping some of its speed", function()
	local vx, vy, vz = Laser.blast(0, -1, 10, -5, 20, TUNING)
	Check.near(vx, 10 * 0.5, "half its own speed across")
	Check.near(vy, 200, "up")
	Check.near(vz, -60 + 20 * 0.5, "pushed away plus half its own")
end)

Check.finish("Laser")
