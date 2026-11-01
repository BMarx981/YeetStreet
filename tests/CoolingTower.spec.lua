--!strict
local Check = require("./Check")
local CoolingTower = require("../src/shared/CoolingTower")

local SHAPE: CoolingTower.Shape = {
	Height = 400,
	WaistHeight = 300,
	WaistRadius = 190,
	Curve = 430,
	CrestRadius = 45,
	InnerLean = 15,
	FootHeight = 40,
	FloorHeight = 80,
	Rows = { Foot = 12, Outer = 10, Crest = 20, Inner = 10, Floor = 12 },
}

local profile = CoolingTower.profile(SHAPE)
-- A row part way up the outside wall, and one part way down the inside.
local OUTER = SHAPE.Rows.Foot + 5
local INNER = #profile - SHAPE.Rows.Floor - 5

local function angleBetween(a: CoolingTower.Point, b: CoolingTower.Point, c: CoolingTower.Point): number
	local ux, uy = b.R - a.R, b.Y - a.Y
	local vx, vy = c.R - b.R, c.Y - b.Y
	local dot = (ux * vx + uy * vy) / (math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy))
	return math.deg(math.acos(math.clamp(dot, -1, 1)))
end

Check.test("the profile starts and ends on the ground", function()
	Check.near(profile[1].Y, 0, "foot")
	Check.near(profile[#profile].Y, 0, "floor")
end)

Check.test("the foot is outside the floor", function()
	Check.eq(CoolingTower.footRadius(SHAPE) > CoolingTower.floorRadius(SHAPE), true)
	Check.near(CoolingTower.footRadius(SHAPE), profile[1].R, "foot radius")
	Check.near(CoolingTower.floorRadius(SHAPE), profile[#profile].R, "floor radius")
end)

Check.test("the top of the crest is at Height", function()
	local top = -math.huge
	for _, point in profile do
		top = math.max(top, point.Y)
	end
	Check.near(top, SHAPE.Height, "top", 0.5)
end)

Check.test("the surface has no kinks a car would feel", function()
	for i = 2, #profile - 1 do
		local turn = angleBetween(profile[i - 1], profile[i], profile[i + 1])
		Check.eq(turn < 10, true, `turn of {turn} degrees at point {i}`)
	end
end)

Check.test("the surface always faces away from the solid wall", function()
	-- Up the outside it faces out, over the crest up, down the inside in.
	local nr, ny = CoolingTower.normal(profile[OUTER], profile[OUTER + 1])
	Check.eq(nr > 0.9, true, `outer faces out: {nr}, {ny}`)
	local top = 1
	for i, point in profile do
		if point.Y > profile[top].Y then
			top = i
		end
	end
	nr, ny = CoolingTower.normal(profile[top], profile[top + 1])
	Check.eq(ny > 0.9, true, `crest faces up: {nr}, {ny}`)
	nr, ny = CoolingTower.normal(profile[INNER], profile[INNER + 1])
	Check.eq(nr < -0.7, true, `inner faces in: {nr}, {ny}`)
end)

Check.test("the inside stays inside the outside at every height", function()
	local function radiusAt(from: number, to: number, y: number): number?
		local step = if to > from then 1 else -1
		for i = from, to - step, step do
			local a, b = profile[i], profile[i + step]
			if math.min(a.Y, b.Y) <= y and y <= math.max(a.Y, b.Y) and a.Y ~= b.Y then
				return a.R + (b.R - a.R) * (y - a.Y) / (b.Y - a.Y)
			end
		end
		return nil
	end
	local top = 1
	for i, point in profile do
		if point.Y > profile[top].Y then
			top = i
		end
	end
	for y = 5, 390, 5 do
		local outer = radiusAt(1, top, y)
		local inner = radiusAt(#profile, top, y)
		if outer and inner then
			Check.eq(outer - inner > 20, true, `wall at {y} is {outer - inner} thick`)
		end
	end
end)

Check.test("the opening at the top and the floor are wide enough to play in", function()
	local narrowest = math.huge
	local seenTop = false
	for i, point in profile do
		seenTop = seenTop or point.Y >= SHAPE.Height - 0.5
		if seenTop and i < #profile then
			narrowest = math.min(narrowest, point.R)
		end
	end
	Check.eq(narrowest > 80, true, `opening radius {narrowest}`)
	Check.eq(CoolingTower.floorRadius(SHAPE) > 100, true, `floor radius {CoolingTower.floorRadius(SHAPE)}`)
end)

local function midpoint(i: number): (number, number)
	return (profile[i].R + profile[i + 1].R) / 2, (profile[i].Y + profile[i + 1].Y) / 2
end

Check.test("the outside wall pulls in toward the tower", function()
	local r, y = midpoint(OUTER)
	local nr, ny = CoolingTower.normal(profile[OUTER], profile[OUTER + 1])
	local px, py, pz = CoolingTower.pull(profile, 14, r + 5 * nr, y + 5 * ny, 0)
	Check.near(px :: number, -nr, "x", 1e-6)
	Check.near(py :: number, -ny, "y", 1e-6)
	Check.near(pz :: number, 0, "z", 1e-6)
end)

Check.test("the pull turns with the car's place round the tower", function()
	local r, y = midpoint(OUTER)
	local nr, ny = CoolingTower.normal(profile[OUTER], profile[OUTER + 1])
	local px, _, pz = CoolingTower.pull(profile, 14, 0, y + 5 * ny, r + 5 * nr)
	Check.near(px :: number, 0, "x", 1e-6)
	Check.near(pz :: number, -nr, "z", 1e-6)
end)

Check.test("the crest pulls down into the rim", function()
	local _, py = CoolingTower.pull(profile, 14, 140, SHAPE.Height + 5, 0)
	Check.eq((py :: number) < -0.95, true, `pull y {py}`)
end)

Check.test("the inside wall pulls out toward the wall", function()
	local r, y = midpoint(INNER)
	local nr, ny = CoolingTower.normal(profile[INNER], profile[INNER + 1])
	local px, py = CoolingTower.pull(profile, 14, r + 5 * nr, y + 5 * ny, 0)
	Check.eq((px :: number) > 0.7, true, `pull x {px}`)
	Check.near(py :: number, -ny, "y", 1e-6)
end)

Check.test("a car a little under the surface is still pulled onto it", function()
	local r, y = midpoint(OUTER)
	local nr, ny = CoolingTower.normal(profile[OUTER], profile[OUTER + 1])
	local px = CoolingTower.pull(profile, 14, r - 2 * nr, y - 2 * ny, 0)
	Check.near(px :: number, -nr, "x", 1e-6)
end)

Check.test("nothing pulls out of reach, on the flat floors, or in the middle", function()
	local r, y = midpoint(OUTER)
	local nr, ny = CoolingTower.normal(profile[OUTER], profile[OUTER + 1])
	Check.eq(CoolingTower.pull(profile, 14, r + 20 * nr, y + 20 * ny, 0), nil, "out of reach")
	Check.eq(CoolingTower.pull(profile, 14, profile[1].R + 5, 3, 0), nil, "the ground outside")
	Check.eq(CoolingTower.pull(profile, 14, profile[#profile].R - 5, 3, 0), nil, "the floor inside")
	Check.eq(CoolingTower.pull(profile, 14, 0, 3, 0), nil, "the middle of the floor")
	Check.eq(CoolingTower.pull(profile, 14, 0, 200, 0), nil, "the middle of the air")
	Check.eq(CoolingTower.pull(profile, 14, 140, SHAPE.Height + 20, 0), nil, "above the rim")
end)

Check.test("on a wall a slow car peels off and stays off", function()
	local peeled, holding = CoolingTower.stepHold(false, 0, 60, 40, 0.9)
	Check.eq(peeled, false, "fast: peeled")
	Check.eq(holding, true, "fast: holding")
	peeled, holding = CoolingTower.stepHold(false, 0, 30, 40, 0.9)
	Check.eq(peeled, true, "slow: peeled")
	Check.eq(holding, false, "slow: holding")
	peeled, holding = CoolingTower.stepHold(true, 0, 60, 40, 0.9)
	Check.eq(peeled, true, "falling fast: peeled")
	Check.eq(holding, false, "falling fast: holding")
end)

Check.test("on a gentle slope a stopped car can set off again", function()
	local peeled, holding = CoolingTower.stepHold(true, -0.95, 0, 40, 0.9)
	Check.eq(peeled, false, "stopped: peeled")
	Check.eq(holding, false, "stopped: left to gravity")
	peeled, holding = CoolingTower.stepHold(false, -0.95, 50, 40, 0.9)
	Check.eq(peeled, false, "moving: peeled")
	Check.eq(holding, true, "moving: holding")
	_, holding = CoolingTower.stepHold(true, -0.95, 50, 40, 0.9)
	Check.eq(holding, true, "landed moving: holding")
end)

local WATER: CoolingTower.Water = {
	Radius = 95,
	Reach = 8,
	Period = 10,
	Boil = 3,
	Burst = 1,
	Throw = { Speed = 410, AimTime = 1.2, KickHeight = 410, Side = 70 },
}

Check.test("each cycle is calm, then boils, then bursts", function()
	Check.eq((CoolingTower.eruption(WATER, 0, 2)), "calm", "start")
	Check.eq((CoolingTower.eruption(WATER, 5.9, 2)), "calm", "end of calm")
	Check.eq((CoolingTower.eruption(WATER, 6.1, 2)), "boil", "start of boil")
	Check.eq((CoolingTower.eruption(WATER, 8.9, 2)), "boil", "end of boil")
	Check.eq((CoolingTower.eruption(WATER, 9.1, 2)), "burst", "start of burst")
	Check.eq((CoolingTower.eruption(WATER, 9.9, 2)), "burst", "end of burst")
	Check.eq((CoolingTower.eruption(WATER, 10.1, 2)), "calm", "next cycle")
end)

Check.test("the phase says how far through it is, and each cycle has its own number", function()
	local _, progress, number = CoolingTower.eruption(WATER, 7.5, 2)
	Check.near(progress, 0.5, "half through the boil")
	Check.eq(number, 0)
	_, _, number = CoolingTower.eruption(WATER, 27.5, 2)
	Check.eq(number, 2)
end)

Check.test("the towers take turns, half a period apart", function()
	Check.eq((CoolingTower.eruption(WATER, 4.5, 1)), "burst", "tower 1")
	Check.eq((CoolingTower.eruption(WATER, 4.5, 2)), "calm", "tower 2")
	Check.eq((CoolingTower.eruption(WATER, 9.5, 1)), "calm", "tower 1 later")
	Check.eq((CoolingTower.eruption(WATER, 9.5, 2)), "burst", "tower 2 later")
end)

Check.test("the server's window runs a little past the burst at both ends", function()
	Check.eq(CoolingTower.erupting(WATER, 8.8, 2, 0.5), true, "just before")
	Check.eq(CoolingTower.erupting(WATER, 9.5, 2, 0.5), true, "during")
	Check.eq(CoolingTower.erupting(WATER, 10.4, 2, 0.5), true, "just after, into the next cycle")
	Check.eq(CoolingTower.erupting(WATER, 8, 2, 0.5), false, "well before")
	Check.eq(CoolingTower.erupting(WATER, 11, 2, 0.5), false, "well after")
end)

Check.test("the water is a low disc on the floor", function()
	Check.eq(CoolingTower.inWater(WATER, 0, 3, 0), true, "middle")
	Check.eq(CoolingTower.inWater(WATER, 60, 3, 70), true, "near the edge")
	Check.eq(CoolingTower.inWater(WATER, 80, 3, 80), false, "past the edge")
	Check.eq(CoolingTower.inWater(WATER, 0, 9, 0), false, "above it")
end)

Check.test("the throw goes up, aimed at the tower's middle", function()
	local vx, vy, vz = CoolingTower.throw(WATER, 0, 0)
	Check.near(vx, 0, "x")
	Check.near(vy, 410, "y")
	Check.near(vz, 0, "z")
	vx, _, vz = CoolingTower.throw(WATER, 60, -30)
	Check.near(vx, -50, "x")
	Check.near(vz, 25, "z")
end)

Check.test("the kick goes the way the car points, across the ground", function()
	local x, z = CoolingTower.kick(WATER, 0, -1)
	Check.near(x, 0, "x")
	Check.near(z, -70, "z")
	x, z = CoolingTower.kick(WATER, 3, 4)
	Check.near(x, 42, "x")
	Check.near(z, 56, "z")
end)

Check.test("a car pointing straight up still gets kicked clear", function()
	local x, z = CoolingTower.kick(WATER, 0, 0)
	Check.near(math.sqrt(x * x + z * z), 70, "sideways")
end)

Check.test("from anywhere in the water, any way it points, a throw clears the neck and lands outside", function()
	local gravity = 130
	for _, start in { { 0, 0 }, { 90, 0 }, { -90, 0 }, { 0, 90 }, { 60, -60 }, { -60, 60 } } do
		for turn = 0, 7 do
			local angle = turn * math.pi / 4
			local vx, vy, vz = CoolingTower.throw(WATER, start[1], start[2])
			local label = `from {start[1]},{start[2]} facing {turn}`
			local x, y, z = start[1], 3, start[2]
			local kicked = false
			while y > 0 do
				x += vx / 60
				z += vz / 60
				y += vy / 60
				vy -= gravity / 60
				if not kicked and y >= WATER.Throw.KickHeight then
					kicked = true
					vx, vz = CoolingTower.kick(WATER, math.cos(angle), math.sin(angle))
				end
				if y > 20 and not kicked then
					Check.eq(CoolingTower.pull(profile, 14, x, y, z), nil, `{label} touches the wall at y {y}`)
				end
			end
			Check.eq(kicked, true, `{label} got above the rim`)
			local landed = math.sqrt(x * x + z * z)
			Check.eq(landed > CoolingTower.footRadius(SHAPE), true, `{label} lands at r {landed}`)
		end
	end
end)

Check.finish("CoolingTower")
