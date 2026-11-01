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
	Rows = { Foot = 6, Outer = 14, Crest = 10, Inner = 12, Floor = 6 },
}

local profile = CoolingTower.profile(SHAPE)

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
		Check.eq(turn < 20, true, `turn of {turn} degrees at point {i}`)
	end
end)

Check.test("the surface always faces away from the solid wall", function()
	-- Up the outside it faces out, over the crest up, down the inside in.
	local nr, ny = CoolingTower.normal(profile[10], profile[11])
	Check.eq(nr > 0.9, true, `outer faces out: {nr}, {ny}`)
	local top = 1
	for i, point in profile do
		if point.Y > profile[top].Y then
			top = i
		end
	end
	nr, ny = CoolingTower.normal(profile[top], profile[top + 1])
	Check.eq(ny > 0.9, true, `crest faces up: {nr}, {ny}`)
	nr, ny = CoolingTower.normal(profile[#profile - 12], profile[#profile - 11])
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
	local r, y = midpoint(12)
	local nr, ny = CoolingTower.normal(profile[12], profile[13])
	local px, py, pz = CoolingTower.pull(profile, 14, r + 5 * nr, y + 5 * ny, 0)
	Check.near(px :: number, -nr, "x", 1e-6)
	Check.near(py :: number, -ny, "y", 1e-6)
	Check.near(pz :: number, 0, "z", 1e-6)
end)

Check.test("the pull turns with the car's place round the tower", function()
	local r, y = midpoint(12)
	local nr, ny = CoolingTower.normal(profile[12], profile[13])
	local px, _, pz = CoolingTower.pull(profile, 14, 0, y + 5 * ny, r + 5 * nr)
	Check.near(px :: number, 0, "x", 1e-6)
	Check.near(pz :: number, -nr, "z", 1e-6)
end)

Check.test("the crest pulls down into the rim", function()
	local _, py = CoolingTower.pull(profile, 14, 140, SHAPE.Height + 5, 0)
	Check.eq((py :: number) < -0.95, true, `pull y {py}`)
end)

Check.test("the inside wall pulls out toward the wall", function()
	local r, y = midpoint(#profile - 12)
	local nr, ny = CoolingTower.normal(profile[#profile - 12], profile[#profile - 11])
	local px, py = CoolingTower.pull(profile, 14, r + 5 * nr, y + 5 * ny, 0)
	Check.eq((px :: number) > 0.7, true, `pull x {px}`)
	Check.near(py :: number, -ny, "y", 1e-6)
end)

Check.test("a car a little under the surface is still pulled onto it", function()
	local r, y = midpoint(12)
	local nr, ny = CoolingTower.normal(profile[12], profile[13])
	local px = CoolingTower.pull(profile, 14, r - 2 * nr, y - 2 * ny, 0)
	Check.near(px :: number, -nr, "x", 1e-6)
end)

Check.test("nothing pulls out of reach, on the flat floors, or in the middle", function()
	local r, y = midpoint(12)
	local nr, ny = CoolingTower.normal(profile[12], profile[13])
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

Check.finish("CoolingTower")
