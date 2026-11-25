--!strict
local Check = require("./Check")
local Rng = require("../src/shared/Rng")
local Tornado = require("../src/shared/Tornado")

local TUNING: Tornado.Tuning = {
	MinHeight = 200,
	MaxHeight = 600,
	LifeMin = 50,
	LifeMax = 80,
	TouchTime = 3,
	LiftTime = 3,
	Edge = 80,
	Apart = 600,
	Tries = 20,
	Speed = 20,
	GoalReach = 30,
	BaseRadius = 20,
	TopSpread = 0.3,
	CatchBelow = 10,
	Climb = 60,
	Spin = 2.5,
	RideRadius = 0.6,
	Tumble = 4,
	RiderGap = 0.8,
	EscapeJets = 0.6,
	Recatch = 4,
	FlingSpeed = 110,
	FlingUp = 70,
	FlingOut = 0.5,
}

local AREA: Tornado.Area = { X = 0, Z = 0, Width = 1000, Depth = 1000 }

-- A tornado at (x, z) that has touched down, `height` tall.
local function roaming(x: number, z: number, height: number): Tornado.State
	local s = Tornado.new(x, z, height, 60, AREA)
	Tornado.step(s, TUNING.TouchTime + 0.01, Rng.new(1), {}, TUNING)
	return s
end

-- Steps `s` until something is thrown out, up to `most` seconds.
local function stepUntilThrown(s: Tornado.State, jets: { [any]: boolean }, most: number): ({ Tornado.Throw }, number)
	local t = 0
	local rng = Rng.new(2)
	while t < most do
		local thrown = Tornado.step(s, 0.05, rng, jets, TUNING)
		t += 0.05
		if #thrown > 0 then
			return thrown, t
		end
	end
	return {}, t
end

Check.test("height: rolls 0 and 1 give the shortest and tallest", function()
	Check.eq(Tornado.height(0, TUNING), 200, "roll 0")
	Check.eq(Tornado.height(1, TUNING), 600, "roll 1")
	Check.eq(Tornado.height(0.5, TUNING), 400, "roll 0.5")
end)

Check.test("height: never under the minimum, even for a bad roll", function()
	Check.eq(Tornado.height(-1, TUNING), 200, "below 0")
	Check.eq(Tornado.height(2, TUNING), 600, "above 1")
end)

Check.test("pickSpot: lands inside an area, Edge in from its sides", function()
	local areas = { { X = 5000, Z = -3000, Width = 400, Depth = 300 } }
	local rng = Rng.new(7)
	for _ = 1, 50 do
		local spot = Tornado.pickSpot(areas, {}, rng, TUNING)
		assert(spot, "a spot")
		Check.eq(math.abs(spot.x - 5000) <= 200 - 80, true, "x inside")
		Check.eq(math.abs(spot.z + 3000) <= 150 - 80, true, "z inside")
		Check.eq(spot.area, areas[1], "its area")
	end
end)

Check.test("pickSpot: keeps Apart from other tornados", function()
	local areas = { AREA }
	local others = { { x = 0, z = 0 } }
	local rng = Rng.new(3)
	for _ = 1, 50 do
		local spot = Tornado.pickSpot(areas, others, rng, TUNING)
		if spot then
			Check.eq(math.sqrt(spot.x ^ 2 + spot.z ^ 2) >= 600, true, "apart")
		end
	end
end)

Check.test("pickSpot: nil when there is no room", function()
	local areas = { { X = 0, Z = 0, Width = 200, Depth = 200 } }
	Check.eq(Tornado.pickSpot(areas, { { x = 0, z = 0 } }, Rng.new(1), TUNING), nil, "no room")
end)

Check.test("pickSpot: bigger areas get picked more", function()
	local small = { X = -5000, Z = 0, Width = 300, Depth = 300 }
	local big = { X = 5000, Z = 0, Width = 3000, Depth = 3000 }
	local rng = Rng.new(11)
	local bigCount = 0
	for _ = 1, 200 do
		local spot = Tornado.pickSpot({ small, big }, {}, rng, TUNING)
		if spot and spot.area == big then
			bigCount += 1
		end
	end
	Check.eq(bigCount > 180, true, `big picked {bigCount} of 200`)
end)

Check.test("radiusAt: grows from BaseRadius at the ground to the top", function()
	local s = Tornado.new(0, 0, 400, 60, AREA)
	Check.near(Tornado.radiusAt(s, 0, TUNING), 20, "ground")
	Check.near(Tornado.radiusAt(s, 400, TUNING), 20 + 400 * 0.3, "top")
	Check.near(Tornado.radiusAt(s, -50, TUNING), 20, "below the ground")
	Check.near(Tornado.radiusAt(s, 900, TUNING), 140, "above the top")
end)

Check.test("phases: touches down, roams, lifts, then is gone", function()
	local s = Tornado.new(0, 0, 300, 10, AREA)
	local rng = Rng.new(1)
	Check.eq(s.phase, "touchdown", "starts")
	Tornado.step(s, 3.1, rng, {}, TUNING)
	Check.eq(s.phase, "roam", "after TouchTime")
	Tornado.step(s, 10, rng, {}, TUNING)
	Check.eq(s.phase, "lift", "after its life")
	Tornado.step(s, 3.1, rng, {}, TUNING)
	Check.eq(s.phase, "gone", "after LiftTime")
end)

Check.test("catch: only while roaming", function()
	local s = Tornado.new(0, 0, 300, 60, AREA)
	Check.eq(#Tornado.catch(s, { { id = "a", x = 0, up = 2, z = 0 } }, TUNING), 0, "touching down")
	Tornado.step(s, 3.1, Rng.new(1), {}, TUNING)
	Check.eq(#Tornado.catch(s, { { id = "a", x = 0, up = 2, z = 0 } }, TUNING), 1, "roaming")
end)

Check.test("catch: a car on the ground inside the base", function()
	local s = roaming(0, 0, 300)
	local caught =
		Tornado.catch(s, { { id = "in", x = 15, up = 2, z = 0 }, { id = "out", x = 30, up = 2, z = 0 } }, TUNING)
	Check.eq(#caught, 1, "one")
	Check.eq(caught[1], "in", "the one inside")
	Check.eq(#s.riders, 1, "riding")
end)

Check.test("catch: a car in the air inside the wider funnel, not above its top", function()
	local s = roaming(0, 0, 300)
	-- At 200 up the funnel is 20 + 60 = 80 wide.
	local caught = Tornado.catch(s, {
		{ id = "high", x = 70, up = 200, z = 0 },
		{ id = "over", x = 0, up = 320, z = 0 },
		{ id = "under", x = 0, up = -20, z = 0 },
	}, TUNING)
	Check.eq(#caught, 1, "one")
	Check.eq(caught[1], "high", "inside the funnel")
end)

Check.test("catch: never the same car twice", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 0, up = 2, z = 0 } }, TUNING)
	Check.eq(#Tornado.catch(s, { { id = "a", x = 0, up = 2, z = 0 } }, TUNING), 0, "again")
	Check.eq(#s.riders, 1, "one rider")
end)

Check.test("ride: a rider climbs and spins round the middle", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 10, up = 0, z = 0 } }, TUNING)
	local before = s.riders[1].angle
	Tornado.step(s, 1, Rng.new(1), {}, TUNING)
	local r = s.riders[1]
	Check.near(r.up, 60, "climbed Climb")
	Check.near(r.angle - before, 2.5, "spun Spin")
	local at = Tornado.riderAt(s, r, TUNING)
	local flat = math.sqrt((at.x - s.x) ^ 2 + (at.z - s.z) ^ 2)
	Check.near(flat, Tornado.radiusAt(s, 60, TUNING) * 0.6, "rides inside the funnel", 1e-6)
	Check.near(at.up, 60, "height")
end)

Check.test("ride: a rider faces the way it spins", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 10, up = 0, z = 0 } }, TUNING)
	-- On +X, spinning toward +Z: a yaw whose look (-sin, -cos) is (0, 1).
	local yaw = Tornado.riderAt(s, s.riders[1], TUNING).yaw
	Check.near(-math.sin(yaw), 0, "look x")
	Check.near(-math.cos(yaw), 1, "look z")
end)

Check.test("ride: riders move with the tornado", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 0, up = 0, z = 0 } }, TUNING)
	Tornado.step(s, 2, Rng.new(1), {}, TUNING)
	local at = Tornado.riderAt(s, s.riders[1], TUNING)
	local flat = math.sqrt((at.x - s.x) ^ 2 + (at.z - s.z) ^ 2)
	Check.near(flat, Tornado.radiusAt(s, at.up, TUNING) * 0.6, "still round the middle", 1e-6)
end)

Check.test("ride: a second car caught on the same side is spread out", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 10, up = 0, z = 0 } }, TUNING)
	Tornado.catch(s, { { id = "b", x = 10, up = 0, z = 1 } }, TUNING)
	Check.eq(#s.riders, 2, "both ride")
	local gap = math.abs(Tornado.angleGap(s.riders[1].angle, s.riders[2].angle))
	Check.eq(gap >= 0.8, true, `gap {gap}`)
end)

Check.test("ride: three cars on the same side all keep RiderGap", function()
	local s = roaming(0, 0, 300)
	for i, id in { "a", "b", "c" } do
		Tornado.catch(s, { { id = id, x = 10, up = 0, z = i * 0.1 } }, TUNING)
	end
	for i = 1, 3 do
		for j = i + 1, 3 do
			local gap = math.abs(Tornado.angleGap(s.riders[i].angle, s.riders[j].angle))
			Check.eq(gap >= 0.8, true, `riders {i} and {j} gap {gap}`)
		end
	end
end)

Check.test("throw: at the top", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 0, up = 0, z = 0 } }, TUNING)
	local thrown, t = stepUntilThrown(s, {}, 20)
	Check.eq(#thrown, 1, "thrown")
	Check.eq(thrown[1].id, "a", "the rider")
	Check.eq(thrown[1].why, "top", "why")
	Check.near(t, 5, "300 at 60 a second", 0.06)
	Check.eq(#s.riders, 0, "no riders left")
	Check.eq(thrown[1].up >= 300, true, "from the top")
end)

Check.test("throw: jets for EscapeJets break free on the way up", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 0, up = 0, z = 0 } }, TUNING)
	local thrown, t = stepUntilThrown(s, { a = true }, 20)
	Check.eq(#thrown, 1, "thrown")
	Check.eq(thrown[1].why, "jets", "why")
	Check.near(t, 0.6, "after EscapeJets", 0.06)
end)

Check.test("throw: only the jetting rider breaks free", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 0, up = 0, z = 0 } }, TUNING)
	Tornado.catch(s, { { id = "b", x = 0, up = 0, z = 0 } }, TUNING)
	local thrown = stepUntilThrown(s, { b = true }, 20)
	Check.eq(#thrown, 1, "one thrown")
	Check.eq(thrown[1].id, "b", "the jetting one")
	Check.eq(#s.riders, 1, "the other still rides")
end)

Check.test("throw: flung out along the spin, up, at FlingSpeed flat", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 0, up = 0, z = 0 } }, TUNING)
	local thrown = stepUntilThrown(s, {}, 20)
	local t = thrown[1]
	Check.near(t.vy, 70, "up")
	Check.near(math.sqrt(t.vx ^ 2 + t.vz ^ 2), 110, "flat speed", 1e-6)
	-- Outward: moving away from the middle.
	local ox, oz = t.x - s.x, t.z - s.z
	Check.eq(ox * t.vx + oz * t.vz > 0, true, "outward")
end)

Check.test("throw: a thrown car is not caught again for Recatch seconds", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 0, up = 0, z = 0 } }, TUNING)
	local thrown = stepUntilThrown(s, {}, 20)
	local t = thrown[1]
	-- Still inside the funnel at the top, where it was let go.
	local car = { id = "a", x = t.x, up = t.up, z = t.z }
	Check.eq(#Tornado.catch(s, { car }, TUNING), 0, "not at once")
	Tornado.step(s, 3.9, Rng.new(1), {}, TUNING)
	Check.eq(#Tornado.catch(s, { { id = "a", x = s.x, up = 2, z = s.z } }, TUNING), 0, "not before Recatch")
	Tornado.step(s, 0.2, Rng.new(1), {}, TUNING)
	Check.eq(#Tornado.catch(s, { { id = "a", x = s.x, up = 2, z = s.z } }, TUNING), 1, "after Recatch")
end)

Check.test("drop: takes a rider off without throwing it", function()
	local s = roaming(0, 0, 300)
	Tornado.catch(s, { { id = "a", x = 0, up = 0, z = 0 }, { id = "b", x = 0, up = 0, z = 0 } }, TUNING)
	Check.eq(Tornado.drop(s, "a"), true, "dropped a")
	Check.eq(Tornado.drop(s, "a"), false, "a already gone")
	Check.eq(#s.riders, 1, "one left")
	Check.eq(s.riders[1].id, "b", "b still rides")
end)

Check.test("life: a tornado with riders keeps roaming until they are thrown", function()
	local s = Tornado.new(0, 0, 600, 5, AREA)
	local rng = Rng.new(1)
	Tornado.step(s, 3.1, rng, {}, TUNING)
	Tornado.catch(s, { { id = "a", x = 0, up = 0, z = 0 } }, TUNING)
	Tornado.step(s, 6, rng, {}, TUNING)
	Check.eq(s.phase, "roam", "still roaming past its life")
	stepUntilThrown(s, {}, 20)
	Tornado.step(s, 0.05, rng, {}, TUNING)
	Check.eq(s.phase, "lift", "lifts once empty")
end)

Check.test("roam: stays Edge inside its area", function()
	local area = { X = 100, Z = -200, Width = 400, Depth = 300 }
	local s = Tornado.new(100, -200, 300, 1000, area)
	local rng = Rng.new(5)
	for _ = 1, 4000 do
		Tornado.step(s, 0.1, rng, {}, TUNING)
		Check.eq(math.abs(s.x - 100) <= 200 - 80 + 1e-6, true, `x {s.x}`)
		Check.eq(math.abs(s.z + 200) <= 150 - 80 + 1e-6, true, `z {s.z}`)
	end
end)

Check.test("roam: moves at Speed", function()
	local s = roaming(0, 0, 300)
	local x, z = s.x, s.z
	Tornado.step(s, 0.5, Rng.new(1), {}, TUNING)
	local moved = math.sqrt((s.x - x) ^ 2 + (s.z - z) ^ 2)
	Check.eq(moved <= 10 + 1e-6, true, `moved {moved}`)
	Check.eq(moved > 0, true, "moved some")
end)

Check.test("angleGap: the short way round", function()
	Check.near(Tornado.angleGap(0.1, 2 * math.pi - 0.1), -0.2, "across zero")
	Check.near(Tornado.angleGap(1, 0.5), -0.5, "back")
end)

Check.finish("Tornado")
