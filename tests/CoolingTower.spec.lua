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

Check.finish("CoolingTower")
