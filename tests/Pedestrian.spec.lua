--!strict
local Check = require("./Check")
local Pedestrian = require("../src/shared/Pedestrian")

local TUNING: Pedestrian.Tuning = {
	SeeDistance = 80,
	SeeTime = 1.2,
	SeeSpeed = 15,
	DiveRadius = 12,
	NearMiss = 12,
	HitRadius = 5,
	HitHeight = 10,
	DiveTime = 0.35,
	DiveDistance = 7,
	DiveDown = 0.6,
	FlopTime = 0.4,
	FlopDistance = 10,
	FlopDown = 1.2,
	GetUp = 0.6,
	Fist = 1.4,
	ReturnSpeed = 6,
	Cooldown = 10,
	FleeRadius = 120,
	CalmRadius = 180,
	FleeRate = 2.5,
}

-- Walking along +X at the park's middle, on the curb.
local SPOT: Pedestrian.Spot = { x = 0, z = 0, headingX = 1, headingZ = 0, road = false, toCurb = 0 }
local DIVE_TIME = TUNING.DiveTime
	+ TUNING.DiveDown
	+ TUNING.GetUp
	+ TUNING.Fist
	+ TUNING.DiveDistance / TUNING.ReturnSpeed

local function car(x: number, z: number, vx: number, vz: number): Pedestrian.Car
	return { id = "car", x = x, y = 3, z = z, vx = vx, vy = 0, vz = vz, air = false, visible = true }
end

-- Steps the walker from `from` to `to` seconds, 20 a second, with `at`
-- giving the cars then. Returns the events in order.
local function run(
	s: Pedestrian.State,
	from: number,
	to: number,
	at: (now: number) -> { Pedestrian.Car }
): { Pedestrian.Event }
	local events = {}
	local now = from
	while now <= to + 1e-9 do
		local event = Pedestrian.step(s, SPOT, 0, at(now), now, TUNING)
		if event then
			table.insert(events, event)
		end
		now += 0.05
	end
	return events
end

local function kinds(events: { Pedestrian.Event }): string
	local list = {}
	for _, event in events do
		table.insert(list, event.kind)
	end
	return table.concat(list, " ")
end

-- A car coming up +Z from 40 back, `x` off the walker's line, at 60.
local function passing(x: number, start: number): (now: number) -> { Pedestrian.Car }
	return function(now)
		return { car(x, -40 + 60 * (now - start), 0, 60) }
	end
end

Check.test("a walker sees a car coming at it along the ground and dives off its line", function()
	local s = Pedestrian.new()
	Check.eq(s.mode, "walk", "starts walking")
	local event = Pedestrian.step(s, SPOT, 0, { car(2, -40, 0, 60) }, 100, TUNING)
	assert(event, "an event")
	Check.eq(event.kind, "dive", "dives")
	Check.eq(event.car, "car", "from that car")
	Check.eq(s.mode, "dive", "diving")
	Check.near(s.dirX, -1, "away from the car's line")
	Check.near(s.dirZ, 0, "square to the car's way")
end)

Check.test("it doesn't see a car in the air, round a corner, too slow, going away, passing wide or far off", function()
	local air = car(2, -40, 0, 60)
	air.air = true
	local hidden = car(2, -40, 0, 60)
	hidden.visible = false
	local high = car(2, -40, 0, 60)
	high.y = 40
	local cases = {
		air = air,
		hidden = hidden,
		high = high,
		slow = car(2, -40, 0, 10),
		away = car(2, 40, 0, 60),
		wide = car(30, -40, 0, 60),
		far = car(2, -100, 0, 200),
	}
	for name, c in cases do
		local s = Pedestrian.new()
		Check.eq(Pedestrian.step(s, SPOT, 0, { c }, 100, TUNING), nil, name)
		Check.eq(s.mode, "walk", name)
	end
end)

Check.test("in the road it dives for the nearer curb", function()
	local s = Pedestrian.new()
	local spot: Pedestrian.Spot = { x = 0, z = 0, headingX = 1, headingZ = 0, road = true, toCurb = -1 }
	-- Square to the car's line would be +X; the curb is behind it.
	Pedestrian.step(s, spot, 0, { car(-2, -40, 0, 60) }, 100, TUNING)
	Check.eq(s.mode, "dive", "dives")
	Check.near(s.dirX, -1, "back toward the curb")
end)

Check.test("a dive throws it out, it lies there, gets up, shakes a fist and walks back to its loop", function()
	local s = Pedestrian.new()
	Pedestrian.step(s, SPOT, 0, { car(2, -40, 0, 60) }, 100, TUNING)
	Check.near(Pedestrian.duration(s, TUNING), DIVE_TIME, "how long it all takes")
	local mid = Pedestrian.where(s, 100 + TUNING.DiveTime / 2, TUNING)
	Check.eq(mid.phase, "dive", "diving")
	assert(mid.x < 0 and mid.x > -TUNING.DiveDistance, "part way out")
	local out = Pedestrian.where(s, 100 + TUNING.DiveTime + 0.1, TUNING)
	Check.eq(out.phase, "down", "lying there")
	Check.near(out.x, -TUNING.DiveDistance, "a dive's distance out")
	Check.eq(Pedestrian.where(s, 100 + TUNING.DiveTime + TUNING.DiveDown + 0.1, TUNING).phase, "up", "getting up")
	local fist = Pedestrian.where(s, 100 + TUNING.DiveTime + TUNING.DiveDown + TUNING.GetUp + 0.1, TUNING)
	Check.eq(fist.phase, "fist", "shaking a fist")
	Check.near(fist.facingX, 1, "toward the car's line")
	local back = Pedestrian.where(s, 100 + DIVE_TIME - 0.1, TUNING)
	Check.eq(back.phase, "back", "walking back")
	Check.near(back.facingX, 1, "toward its loop")
	local done = Pedestrian.where(s, 100 + DIVE_TIME + 0.01, TUNING)
	Check.eq(done.phase, "walk", "walking on")
	Check.near(Pedestrian.where(s, 100 + DIVE_TIME - 1e-6, TUNING).x, 0, "back where it left its loop", 1e-3)
end)

Check.test("its loop waits for it: the clock stops at the dive and goes on from there after", function()
	local s = Pedestrian.new()
	Check.near(Pedestrian.clock(s, 99, TUNING), 99, "walking, the server's clock")
	Pedestrian.step(s, SPOT, 0, { car(2, -40, 0, 60) }, 100, TUNING)
	Check.near(Pedestrian.clock(s, 101, TUNING), 100, "stopped while it dives")
	Check.near(Pedestrian.clock(s, 100 + DIVE_TIME + 2, TUNING), 102, "on again after, before the server catches up")
	Pedestrian.step(s, SPOT, 0, {}, 100 + DIVE_TIME + 0.05, TUNING)
	Check.eq(s.mode, "walk", "walking again")
	Check.near(Pedestrian.clock(s, 100 + DIVE_TIME + 0.05, TUNING), 100.05, "from where it stopped")
end)

Check.test("a car that just misses a diving walker pays a near miss, once", function()
	local s = Pedestrian.new()
	local events = run(s, 100, 102, passing(3, 100))
	Check.eq(kinds(events), "dive nearMiss", "events")
	Check.eq(events[2].car, "car", "to that car")
end)

Check.test("a walker pays no near miss again until Cooldown is up", function()
	local s = Pedestrian.new()
	run(s, 100, 102, passing(3, 100))
	Check.eq(kinds(run(s, 102, 107, passing(3, 106))), "dive", "too soon")
	Check.eq(kinds(run(s, 107, 113, passing(3, 112))), "dive nearMiss", "after the cooldown")
end)

Check.test("a car it cannot see knocks it flat, thrown the way the car goes, and pays nothing", function()
	local s = Pedestrian.new()
	local events = run(s, 100, 102, function(now)
		local c = car(0, -40 + 60 * (now - 100), 0, 60)
		c.visible = false
		return { c }
	end)
	Check.eq(kinds(events), "hit", "events")
	Check.eq(s.mode, "flop", "flopped")
	Check.near(s.dirZ, 1, "thrown along the car's way")
	local t = Pedestrian.duration(s, TUNING)
	Check.near(
		t,
		TUNING.FlopTime + TUNING.FlopDown + TUNING.GetUp + TUNING.Fist + TUNING.FlopDistance / TUNING.ReturnSpeed,
		"how long"
	)
	Check.eq(Pedestrian.where(s, s.since + TUNING.FlopTime + 0.1, TUNING).phase, "down", "lying there")
end)

Check.test("landing on it hits it; flying high over it doesn't", function()
	local s = Pedestrian.new()
	local high = car(0, 0, 0, 60)
	high.y, high.air = 30, true
	Check.eq(Pedestrian.step(s, SPOT, 0, { high }, 100, TUNING), nil, "high over")
	local landing = car(0, 0, 0, 60)
	landing.y, landing.air = 4, true
	local event = Pedestrian.step(s, SPOT, 0, { landing }, 100.05, TUNING)
	Check.eq(event and event.kind, "hit", "landed on")
end)

Check.test("a car that swerves into a diving walker still hits it, and it still comes back to its loop", function()
	local s = Pedestrian.new()
	Pedestrian.step(s, SPOT, 0, { car(3, -40, 0, 60) }, 100, TUNING)
	local here = Pedestrian.where(s, 100.1, TUNING)
	local event = Pedestrian.step(s, SPOT, 0, { car(here.x, here.z, -60, 0) }, 100.1, TUNING)
	Check.eq(event and event.kind, "hit", "hit mid dive")
	Check.eq(s.mode, "flop", "flopped")
	Check.near(s.startX, here.x, "from where it had got to", 1e-6)
	Check.near(s.dirX, -1, "thrown the way the car was going")
	Check.near(Pedestrian.clock(s, 101, TUNING), 100, "its loop still waits from the dive")
	local t = Pedestrian.duration(s, TUNING)
	local last = Pedestrian.where(s, s.since + t - 1e-6, TUNING)
	Check.near(last.x, 0, "back to its loop", 1e-3)
	Check.near(last.z, 0, "back to its loop", 1e-3)
	Pedestrian.step(s, SPOT, 0, {}, s.since + t + 0.01, TUNING)
	Check.near(Pedestrian.clock(s, s.since + t + 0.01, TUNING), 100.01, "and walks on from where it dived", 1e-6)
end)

Check.test("knocked down it is left alone until it is walking again", function()
	local s = Pedestrian.new()
	local hidden = car(0, 0, 0, 60)
	hidden.visible = false
	Pedestrian.step(s, SPOT, 0, { hidden }, 100, TUNING)
	Check.eq(s.mode, "flop", "flopped")
	local down = Pedestrian.where(s, 100 + TUNING.FlopTime + 0.2, TUNING)
	local events = run(s, 100.05, 100 + Pedestrian.duration(s, TUNING) - 0.05, function()
		return { car(down.x, down.z, 0, 60) }
	end)
	Check.eq(kinds(events), "", "no hits while down or getting up")
end)

local function kaiju(x: number, z: number): Pedestrian.Point
	return { x = x, z = z }
end

Check.test("a walker near the kaiju runs away from it along its loop", function()
	local s = Pedestrian.new()
	local event = Pedestrian.step(s, SPOT, 0, {}, 100, TUNING, kaiju(-50, 0))
	Check.eq(event and event.kind, "flee", "flees")
	Check.eq(s.mode, "flee", "fleeing")
	Check.near(s.rate, TUNING.FleeRate, "on along its loop, away")
	Check.near(Pedestrian.clock(s, 101, TUNING), 100 + TUNING.FleeRate, "its loop's clock runs fast")
	Check.eq(Pedestrian.where(s, 100.5, TUNING).phase, "flee", "drawn running")
	Check.eq(Pedestrian.onLoop(s), true, "still on its loop")
end)

Check.test("with the kaiju ahead it runs back the way it came", function()
	local s = Pedestrian.new()
	Pedestrian.step(s, SPOT, 0, {}, 100, TUNING, kaiju(50, 0))
	Check.near(s.rate, -TUNING.FleeRate, "backward")
	Check.near(Pedestrian.clock(s, 101, TUNING), 100 - TUNING.FleeRate, "its loop's clock runs back")
end)

Check.test("it doesn't flee a kaiju beyond FleeRadius, or no kaiju at all", function()
	local s = Pedestrian.new()
	Check.eq(Pedestrian.step(s, SPOT, 0, {}, 100, TUNING, kaiju(-150, 0)), nil, "too far")
	Check.eq(Pedestrian.step(s, SPOT, 0, {}, 100.1, TUNING, nil), nil, "none")
	Check.eq(s.mode, "walk", "walking")
end)

Check.test("it keeps running until the kaiju is CalmRadius off, then walks on from where it ran to", function()
	local s = Pedestrian.new()
	Pedestrian.step(s, SPOT, 0, {}, 100, TUNING, kaiju(-50, 0))
	Pedestrian.step(s, SPOT, 0, {}, 101, TUNING, kaiju(-150, 0))
	Check.eq(s.mode, "flee", "still running between the radii")
	Pedestrian.step(s, SPOT, 0, {}, 102, TUNING, kaiju(-500, 0))
	Check.eq(s.mode, "walk", "calmed down")
	Check.near(Pedestrian.clock(s, 102, TUNING), 100 + 2 * TUNING.FleeRate, "where it ran to")
	Check.near(Pedestrian.clock(s, 103, TUNING), 101 + 2 * TUNING.FleeRate, "then at walking speed")
end)

Check.test("running, it still dives from a car, and walks on from where it had run to", function()
	local s = Pedestrian.new()
	Pedestrian.step(s, SPOT, 0, {}, 100, TUNING, kaiju(-100, 0))
	local event = Pedestrian.step(s, SPOT, 0, { car(2, -40, 0, 60) }, 101, TUNING, kaiju(-100, 0))
	Check.eq(event and event.kind, "dive", "dives")
	Check.near(Pedestrian.clock(s, 101.5, TUNING), 100 + TUNING.FleeRate, "its loop waits where it had run to")
	Pedestrian.step(s, SPOT, 0, {}, 101 + DIVE_TIME + 0.01, TUNING, nil)
	Check.eq(s.mode, "walk", "walks on after")
	Check.near(Pedestrian.clock(s, 101 + DIVE_TIME + 0.01, TUNING), 100.01 + TUNING.FleeRate, "from there", 1e-6)
end)

Check.test("running, a car reaching it still knocks it flat", function()
	local s = Pedestrian.new()
	Pedestrian.step(s, SPOT, 0, {}, 100, TUNING, kaiju(-100, 0))
	local hidden = car(0, 0, 0, 60)
	hidden.visible = false
	local event = Pedestrian.step(s, SPOT, 0, { hidden }, 101, TUNING, kaiju(-100, 0))
	Check.eq(event and event.kind, "hit", "hit")
	Check.near(Pedestrian.clock(s, 102, TUNING), 100 + TUNING.FleeRate, "its loop waits where it had run to")
end)

Check.finish("Pedestrian")
