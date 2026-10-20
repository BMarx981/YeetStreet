--!strict
local Check = require("./Check")
local Grind = require("../src/shared/Grind")
local Rng = require("../src/shared/Rng")

local TUNING: Grind.Tuning = {
	GrindHeight = 2,
	CaptureRadius = 6,
	HoldTolerance = 2,
	MinAlign = 0.8,
	MinSpeed = 20,
	ZoneHalf = 0.2,
	ZoneSpeed = 0.5,
	RetargetMin = 0.5,
	RetargetMax = 1.5,
	Tip = 1.5,
	Wobble = 2,
	WobbleGrowth = 0.15,
	GustTime = 0.25,
	SteerForce = 8,
	Damping = 3,
	Grace = 0.5,
	StartGrace = 0,
}

-- 100 studs along +Z at height 3; the grind line is 2 above it, at y 5.
local RAIL: Grind.Rail = { ax = 0, ay = 3, az = 0, bx = 0, by = 3, bz = 100 }

local function still(fields: { [string]: number }): Grind.Tuning
	local t = table.clone(TUNING)
	for key, value in fields do
		(t :: any)[key] = value
	end
	return t
end

Check.test("a car riding along beside the rail start is captured, in its direction", function()
	Check.eq(Grind.capture(RAIL, 1, 3, 10, 0, 0, 50, TUNING), 1, "forward")
	Check.eq(Grind.capture(RAIL, 1, 3, 90, 0, 0, -50, TUNING), -1, "backward")
end)

Check.test("a car too far from the rail is not captured", function()
	Check.eq(Grind.capture(RAIL, 10, 3, 50, 0, 0, 50, TUNING), nil)
end)

Check.test("a car crossing the rail sideways is not captured", function()
	Check.eq(Grind.capture(RAIL, 0, 5, 50, 50, 0, 10, TUNING), nil)
end)

Check.test("a slow car is not captured", function()
	Check.eq(Grind.capture(RAIL, 0, 5, 50, 0, 0, 10, TUNING), nil)
end)

Check.test("a car past either end is not captured", function()
	Check.eq(Grind.capture(RAIL, 0, 5, -3, 0, 0, 50, TUNING), nil, "before the start")
	Check.eq(Grind.capture(RAIL, 0, 5, 103, 0, 0, -50, TUNING), nil, "past the end")
end)

Check.test("point gives the grind line above the rail", function()
	local x, y, z = Grind.point(RAIL, 0.25, TUNING)
	Check.near(x, 0)
	Check.near(y, 5)
	Check.near(z, 25)
	Check.near(Grind.length(RAIL), 100)
end)

Check.test("a sloped rail's grind line follows the slope", function()
	local stairs: Grind.Rail = { ax = 0, ay = 30, az = 0, bx = 0, by = 0, bz = -120 }
	local _, y, z = Grind.point(stairs, 0.5, TUNING)
	Check.near(y, 17)
	Check.near(z, -60)
	-- Riding down it, the velocity points down the slope too.
	Check.eq(Grind.capture(stairs, 0, 17, -60, 0, -20, -80, TUNING), 1)
end)

Check.test("onRail is true only close to the grind line and moving along it", function()
	Check.eq(Grind.onRail(RAIL, 0, 5, 50, 0, 0, 60, TUNING), true, "on the line")
	Check.eq(Grind.onRail(RAIL, 0, 8, 50, 0, 0, 60, TUNING), false, "above it")
	Check.eq(Grind.onRail(RAIL, 0, 5, 50, 60, 0, 0, TUNING), false, "moving across")
	Check.eq(Grind.onRail(RAIL, 0, 5, 120, 0, 0, 60, TUNING), false, "past the end")
end)

Check.test("a new balance starts centered in the zone", function()
	local b = Grind.balance()
	Check.eq(b.marker, 0)
	Check.eq(b.zone, 0)
	Check.eq(Grind.inZone(b, TUNING), true)
end)

Check.test("outside the zone for less than the grace time does not fall", function()
	local calm = still({ Tip = 0, Wobble = 0, WobbleGrowth = 0, ZoneSpeed = 0 })
	local b = Grind.balance()
	b.marker = 0.9
	local rng = Rng.new(1)
	for _ = 1, 4 do
		Check.eq(Grind.stepBalance(b, 0, 0.1, rng, calm), false)
	end
	Check.eq(Grind.stepBalance(b, 0, 0.1, rng, calm), true, "at the grace time")
end)

Check.test("coming back inside resets the grace time", function()
	local calm = still({ Tip = 0, Wobble = 0, WobbleGrowth = 0, ZoneSpeed = 0 })
	local b = Grind.balance()
	b.marker = 0.9
	local rng = Rng.new(1)
	for _ = 1, 4 do
		Grind.stepBalance(b, 0, 0.1, rng, calm)
	end
	b.marker = 0
	b.velocity = 0
	Grind.stepBalance(b, 0, 0.1, rng, calm)
	Check.eq(b.outside, 0)
end)

Check.test("the car cannot fall during the start grace", function()
	local calm = still({ Tip = 0, Wobble = 0, WobbleGrowth = 0, ZoneSpeed = 0, StartGrace = 1.5 })
	local b = Grind.balance()
	b.marker = 0.9
	local rng = Rng.new(1)
	for i = 1, 6 do -- 1.5 seconds
		Check.eq(Grind.stepBalance(b, 0, 0.25, rng, calm), false, `step {i}`)
		Check.eq(b.outside, 0, `outside at step {i}`)
	end
	Check.eq(Grind.stepBalance(b, 0, 0.25, rng, calm), false, "grace time starts after")
	Check.eq(Grind.stepBalance(b, 0, 0.25, rng, calm), true, "at the grace time after")
end)

Check.test("the zone and gusts wait for the start grace to end", function()
	local b = Grind.balance()
	local rng = Rng.new(5)
	for _ = 1, 6 do -- 1.5 seconds
		Grind.stepBalance(b, 0, 0.25, rng, still({ StartGrace = 1.5 }))
	end
	Check.eq(b.zone, 0, "zone")
	Check.eq(b.marker, 0, "marker")
	Check.eq(b.gust, 0, "gust")
end)

Check.test("steering pushes the marker that way", function()
	local calm = still({ Tip = 0, Wobble = 0, WobbleGrowth = 0, ZoneSpeed = 0 })
	local b = Grind.balance()
	Grind.stepBalance(b, 1, 0.1, Rng.new(1), calm)
	Check.eq(b.marker > 0, true, "right")
	local c = Grind.balance()
	Grind.stepBalance(c, -1, 0.1, Rng.new(1), calm)
	Check.eq(c.marker < 0, true, "left")
end)

Check.test("the marker and zone stay on the bar", function()
	local b = Grind.balance()
	local rng = Rng.new(7)
	for _ = 1, 400 do
		Grind.stepBalance(b, 1, 0.05, rng, TUNING)
		Check.eq(math.abs(b.marker) <= 1, true, "marker")
		Check.eq(math.abs(b.zone) <= 1 - TUNING.ZoneHalf, true, "zone")
	end
end)

Check.test("left alone, the car falls off", function()
	local b = Grind.balance()
	local rng = Rng.new(3)
	local fell = false
	for _ = 1, 200 do -- 10 seconds
		if Grind.stepBalance(b, 0, 0.05, rng, TUNING) then
			fell = true
			break
		end
	end
	Check.eq(fell, true)
end)

Check.test("steering toward the zone keeps the car on for a long grind", function()
	for seed = 1, 5 do
		local b = Grind.balance()
		local rng = Rng.new(seed)
		for i = 1, 200 do -- 10 seconds
			local steer = math.clamp((b.zone - b.marker) * 6 - b.velocity, -1, 1)
			Check.eq(Grind.stepBalance(b, steer, 0.05, rng, TUNING), false, `seed {seed} step {i}`)
		end
	end
end)

Check.test("the wobble grows the longer the grind lasts", function()
	local b = Grind.balance()
	Grind.stepBalance(b, 0, 0.05, Rng.new(1), TUNING)
	Check.near(b.time, 0.05)
	Check.eq(Grind.wobble(b, TUNING) > TUNING.Wobble, true, "after a moment")
	b.time = 10
	Check.near(Grind.wobble(b, TUNING), TUNING.Wobble * (1 + TUNING.WobbleGrowth * 10))
end)

Check.finish("Grind")
