--!strict
local Check = require("./Check")
local Gravitron = require("../src/shared/Gravitron")
local Tunnel = require("../src/shared/Tunnel")

Check.test("a straight runs along the heading", function()
	local pieces, finish = Tunnel.path(0, 0, 0, -1, { { Straight = 50 } })
	Check.eq(#pieces, 1)
	local piece = pieces[1]
	Check.eq(piece.kind, "straight")
	Check.near(piece.toX, 0)
	Check.near(piece.toZ, -50)
	Check.near(finish.x, 0)
	Check.near(finish.z, -50)
	Check.near(finish.headingZ, -1)
end)

Check.test("a left turn facing -Z ends facing -X, its center on the left", function()
	local pieces, finish = Tunnel.path(0, 0, 0, -1, { { Turn = 90, Radius = 80 } })
	local arc = pieces[1]
	Check.eq(arc.kind, "arc")
	Check.eq(arc.left, true)
	Check.near(arc.centerX, -80, "center x")
	Check.near(arc.centerZ, 0, "center z")
	Check.near(finish.x, -80, "end x")
	Check.near(finish.z, -80, "end z")
	Check.near(finish.headingX, -1, "heading x")
	Check.near(finish.headingZ, 0, "heading z", 1e-9)
	-- Swept counterclockwise from above, starting where the car enters.
	Check.near(arc.startX, 0, "start x")
	Check.near(arc.startZ, 0, "start z")
	Check.near(arc.sweep, math.pi / 2, "sweep")
end)

Check.test("a right turn sweeps from where the car leaves it", function()
	local pieces, finish = Tunnel.path(0, 0, 1, 0, { { Turn = -90, Radius = 80 } })
	local arc = pieces[1]
	Check.eq(arc.left, false)
	Check.near(arc.centerX, 0, "center x")
	Check.near(arc.centerZ, 80, "center z")
	Check.near(finish.x, 80, "end x")
	Check.near(finish.z, 80, "end z")
	Check.near(finish.headingZ, 1, "heading z")
	Check.near(arc.startX, 80, "starts at the exit")
	Check.near(arc.startZ, 80, "starts at the exit")
end)

Check.test("each piece starts where the last one ended", function()
	local pieces = Tunnel.path(0, 0, 0, 1, {
		{ Straight = 20 },
		{ Turn = 90, Radius = 50 },
		{ Turn = -90, Radius = 30 },
		{ Straight = 10 },
	})
	local x, z = 0, 0
	for i, piece in pieces do
		Check.near(piece.fromX, x, `piece {i} from x`, 1e-9)
		Check.near(piece.fromZ, z, `piece {i} from z`, 1e-9)
		x, z = piece.toX, piece.toZ
	end
end)

Check.test("rises add up from the starting height, piece by piece", function()
	local pieces, finish = Tunnel.path(0, 0, 1, 0, {
		{ Straight = 40 },
		{ Turn = 90, Radius = 50, Rise = 10 },
		{ Straight = 30, Rise = -4 },
	}, 30)
	Check.near(pieces[1].fromY, 30)
	Check.near(pieces[1].toY, 30, "a straight with no Rise stays level")
	Check.near(pieces[2].toY, 40)
	Check.near(pieces[3].fromY, 40)
	Check.near(finish.y, 36)
end)

Check.test("a climb eases in and out, level at both ends", function()
	Check.near(Tunnel.ease(0), 0)
	Check.near(Tunnel.ease(0.5), 0.5)
	Check.near(Tunnel.ease(1), 1)
	local slope = (Tunnel.ease(0.001) - Tunnel.ease(0)) / 0.001
	Check.eq(slope < 0.01, true, "level at the start")
end)

Check.test("a point along a turn is on its circle, as high as the climb has eased", function()
	local piece = Tunnel.path(0, 0, 0, -1, { { Turn = 90, Radius = 80, Rise = 20 } }, 10)[1]
	local x, y, z = Tunnel.pointAt(piece, 0.5)
	local a = math.rad(45)
	Check.near(x, -80 + 80 * math.cos(a), "x")
	Check.near(z, -80 * math.sin(a), "z")
	Check.near(y, 20, "halfway up")
	x, y, z = Tunnel.pointAt(piece, 1)
	Check.near(x, -80)
	Check.near(y, 30)
	Check.near(z, -80)
	local right = Tunnel.path(0, 0, 1, 0, { { Turn = -90, Radius = 80 } })[1]
	x, _, z = Tunnel.pointAt(right, 1)
	Check.near(x, 80, "a right turn goes the other way round")
	Check.near(z, 80)
end)

local CLIMB: { Tunnel.Segment } = {
	{ Straight = 80 },
	{ Turn = -60, Radius = 70, Rise = 8 },
	{ Turn = 120, Radius = 70, Rise = 16 },
	{ Turn = -60, Radius = 70, Rise = 8 },
}
local DROP: { Tunnel.Segment } = {
	{ Straight = 40 },
	{ Turn = -90, Radius = 150, Rise = -32 },
}

local function city(places: { Tunnel.Place }): Tunnel.City
	return {
		Avenue = { Width = 160 },
		Streets = { Width = 100, Z = { 1000, 200 } },
		Buildings = { TopZ = 1500, Setback = 20, Lot = 160, Alley = 50 },
		Tunnels = {
			Radius = 30,
			Sides = 24,
			Columns = 2,
			Rows = 2,
			Offset = 230,
			Climb = CLIMB,
			Drop = DROP,
			Places = places,
		},
	}
end

Check.test("blocks run between the streets, the first from TopZ", function()
	local blocks = Tunnel.blocks(city({}))
	Check.eq(#blocks, 2)
	Check.near(blocks[1].top, 1500)
	Check.near(blocks[1].bottom, 1050)
	Check.near(blocks[2].top, 950)
	Check.near(blocks[2].bottom, 250)
end)

Check.test("a chain's two buildings stand either side of an alley against the top street", function()
	local chain = Tunnel.layout(city({ { Side = 1, Block = 2, Street = "Top" } }))[1]
	local first, second = chain.rects[1], chain.rects[2]
	Check.near(first.x1, 100, "first from the avenue's setback")
	Check.near(first.x2, 470, "two lots and an alley wide")
	Check.near(second.x1, 520, "an alley on")
	Check.near(second.x2, 890)
	Check.near(first.z2, 930, "against the top street")
	Check.near(first.z1, 560, "two lots and an alley deep")
	Check.near(second.z1, 560)
end)

Check.test("a chain climbs in from the avenue, crosses the alley up high, and drops out onto the street", function()
	local chain = Tunnel.layout(city({ { Side = 1, Block = 2, Street = "Top" } }))[1]
	local ground = Tunnel.groundHeight(city({}).Tunnels)
	Check.near(chain.entry.x, 100, "enters on the avenue side")
	Check.near(chain.entry.z, 700, "Offset in from the street")
	Check.near(chain.alley[1].x, 470, "leaves the first building")
	Check.near(chain.alley[2].x, 520, "into the second")
	Check.near(chain.alley[1].z, 700, "the snake comes back to its line")
	Check.near(chain.alleyHeight, ground + 32, "up the whole Climb")
	Check.near(chain.exit.x, 710, "out past the drop's sweep")
	Check.near(chain.exit.z, 930, "onto the top street")
	Check.near(chain.pieces[#chain.pieces].toY, ground, "back on the ground")
	Check.eq(chain.warning, nil)
end)

Check.test("a chain against the bottom street on the other side is the mirror image", function()
	local chain = Tunnel.layout(city({ { Side = -1, Block = 2, Street = "Bottom" } }))[1]
	Check.near(chain.rects[1].x2, -100)
	Check.near(chain.rects[1].z1, 350, "against the lowest lots")
	Check.near(chain.entry.x, -100)
	Check.near(chain.entry.z, 580)
	Check.near(chain.exit.x, -710)
	Check.near(chain.exit.z, 350, "onto the bottom street")
	Check.eq(chain.warning, nil)
end)

Check.test("a place in a block that does not exist is skipped", function()
	Check.eq(#Tunnel.layout(city({ { Side = 1, Block = 5, Street = "Top" } })), 0)
end)

Check.test("the tube's middle sits so its bottom plank lies on the floor", function()
	Check.near(Tunnel.groundHeight(city({}).Tunnels), 30 * math.cos(math.pi / 24) + Tunnel.LIFT)
end)

local function vec(label: string, x: number?, y: number?, z: number?, ex: number, ey: number, ez: number)
	Check.eq(x ~= nil, true, `{label}: inside`)
	Check.near(x :: number, ex, `{label} x`, 1e-6)
	Check.near(y :: number, ey, `{label} y`, 1e-6)
	Check.near(z :: number, ez, `{label} z`, 1e-6)
end

local straight = Tunnel.path(0, 0, 0, -1, { { Straight = 100 } }, 30)

Check.test("in a straight tube the pull is out from its middle line", function()
	local x, y, z = Tunnel.pull(straight, 30, 0, 50, -50)
	vec("above", x, y, z, 0, 1, 0)
	x, y, z = Tunnel.pull(straight, 30, 20, 30, -50)
	vec("beside", x, y, z, 1, 0, 0)
	x, y, z = Tunnel.pull(straight, 30, 0, 10, -50)
	vec("below", x, y, z, 0, -1, 0)
end)

Check.test("on the middle line the pull is straight down", function()
	local x, y, z = Tunnel.pull(straight, 30, 0, 30, -50)
	vec("middle", x, y, z, 0, -1, 0)
end)

Check.test("outside the tube there is no pull", function()
	Check.eq(Tunnel.pull(straight, 30, 0, 10, 5), nil, "before the start")
	Check.eq(Tunnel.pull(straight, 30, 0, 10, -105), nil, "past the end")
	Check.eq(Tunnel.pull(straight, 30, 31, 30, -50), nil, "beyond the wall")
end)

Check.test("in a climbing tube the pull is square out from the middle line where it has climbed to", function()
	local climbing = Tunnel.path(0, 0, 0, -1, { { Straight = 100, Rise = 20 } }, 30)
	-- Halfway up it climbs 0.3 a stud toward -Z, so square up from it leans
	-- back toward +Z.
	local n = math.sqrt(1 + 0.3 ^ 2)
	local x, y, z = Tunnel.pull(climbing, 30, 0, 40 + 10, -50)
	Check.near(x :: number, 0, "above the middle halfway up x", 1e-6)
	Check.near(y :: number, 1 / n, "y", 0.01)
	Check.near(z :: number, 0.3 / n, "z", 0.01)
	x, y, z = Tunnel.pull(climbing, 30, 0, 40 - 10, -50)
	Check.near(y :: number, -1 / n, "below it y", 0.01)
	Check.near(z :: number, -0.3 / n, "z", 0.01)
	Check.eq(Tunnel.pull(climbing, 30, 0, 5, -100), nil, "under the floor at the top")
end)

Check.test("in a steep dive a car on the floor is still in the tube, pulled square to it", function()
	local dive = Tunnel.path(0, 0, 0, -1, { { Straight = 300, Rise = -300 } }, 30)
	-- Halfway down it drops 1.5 a stud. A car 27 square under the middle
	-- line there is 27 * sqrt(1 + 1.5^2), about 49, straight under it.
	local slope = 1.5
	local n = math.sqrt(1 + slope ^ 2)
	local _, my, mz = Tunnel.pointAt(dive[1], 0.5)
	-- Square down from the line, which runs toward -Z and down.
	local dy, dz = -1 / n, slope / n
	local x, y, z = Tunnel.pull(dive, 30, 0, my + 27 * dy, mz + 27 * dz)
	Check.eq(x ~= nil, true, "inside")
	Check.near(y :: number, dy, "y", 0.01)
	Check.near(z :: number, dz, "z", 0.01)
end)

-- Facing -Z, a quarter turn left around (-80, 0).
local left = Tunnel.path(0, 0, 0, -1, { { Turn = 90, Radius = 80 } }, 30)

Check.test("in a turn the pull is out from the middle line around the turn", function()
	local a = math.rad(45)
	-- 45 degrees around from the start, 20 out from the middle line, level with it.
	local ox, oz = math.cos(a), -math.sin(a)
	local x, y, z = Tunnel.pull(left, 30, -80 + 100 * ox, 30, 100 * oz)
	vec("outer side", x, y, z, ox, 0, oz)
	x, y, z = Tunnel.pull(left, 30, -80 + 80 * ox, 50, 80 * oz)
	vec("roof", x, y, z, 0, 1, 0)
end)

Check.test("past either end of a turn there is no pull", function()
	Check.eq(Tunnel.pull(left, 30, 0, 30, 10), nil, "before it")
	Check.eq(Tunnel.pull(left, 30, -90, 30, 80), nil, "around the far side")
end)

Check.test("a right turn's tube is found from either end", function()
	local right = Tunnel.path(0, 0, 0, -1, { { Turn = -90, Radius = 80 } }, 30)
	Check.eq(Tunnel.pull(right, 30, 1, 30, -5) ~= nil, true, "near its start")
	Check.eq(Tunnel.pull(right, 30, 75, 30, -80) ~= nil, true, "near its end")
	Check.eq(Tunnel.pull(right, 30, -5, 30, -5) ~= nil, true, "beside its start")
	Check.eq(Tunnel.pull(right, 30, 160, 30, 0), nil, "on the circle but outside the turn")
end)

Check.test("in a spiral the pull is out from the loop the car is in", function()
	-- Two loops left around (-80, 0), climbing 200: a quarter of the way
	-- round the second loop is 5/8 of the climb along.
	local spiral = Tunnel.path(0, 0, 0, -1, { { Turn = 720, Radius = 80, Rise = 200 } }, 30)
	local high = 30 + 200 * Tunnel.ease(5 / 8)
	local x, y, z = Tunnel.pull(spiral, 30, -80, high + 10, -80)
	-- Heading -X there and climbing, so square up from it leans toward +X.
	local slope = 200 * 6 * (5 / 8) * (3 / 8) / (2 * math.pi * 80 * 2)
	local n = math.sqrt(1 + slope * slope)
	Check.near(x :: number, slope / n, "above the second loop x", 0.01)
	Check.near(y :: number, 1 / n, "y", 0.01)
	Check.near(z :: number, 0, "z", 0.01)
	local low = 30 + 200 * Tunnel.ease(1 / 8)
	x, y, z = Tunnel.pull(spiral, 30, -80, low - 10, -80)
	local lowSlope = 200 * 6 * (1 / 8) * (7 / 8) / (2 * math.pi * 80 * 2)
	local m = math.sqrt(1 + lowSlope * lowSlope)
	Check.near(x :: number, -lowSlope / m, "below the first loop x", 0.01)
	Check.near(y :: number, -1 / m, "y", 0.01)
	Check.eq(Tunnel.pull(spiral, 30, -80, (low + high) / 2, -80), nil, "between the loops")
end)

Check.test("in a right-hand spiral the pull is out from the loop the car is in", function()
	-- Two loops right around (80, 0): a quarter of the way round the second
	-- loop is 5/8 of the climb along.
	local spiral = Tunnel.path(0, 0, 0, -1, { { Turn = -720, Radius = 80, Rise = 200 } }, 30)
	local high = 30 + 200 * Tunnel.ease(5 / 8)
	local x, y, z = Tunnel.pull(spiral, 30, 80, high + 10, -80)
	local slope = 200 * 6 * (5 / 8) * (3 / 8) / (2 * math.pi * 80 * 2)
	local n = math.sqrt(1 + slope * slope)
	Check.near(x :: number, -slope / n, "above the second loop x", 0.01)
	Check.near(y :: number, 1 / n, "y", 0.01)
end)

local SPIRALS: Tunnel.Spirals = {
	Radius = 105,
	Pitch = 72,
	Loops = 2,
	Inset = 225,
	LevelRun = 80,
	Outside = 33,
	RoofThickness = 2,
	Columns = 2,
	Rows = 2,
	Places = {},
}

local function spiralsAt(place: Tunnel.SpiralPlace): { Tunnel.Spiral }
	local layout = table.clone(SPIRALS)
	layout.Places = { place }
	return Tunnel.spirals(city({}), layout)
end

-- Points every few studs along a spiral's middle line.
local function samples(spiral: Tunnel.Spiral): { { x: number, y: number, z: number, s: number } }
	local points = {}
	local travelled = 0
	for _, piece in spiral.pieces do
		local length = Tunnel.length(piece)
		local steps = math.ceil(length / 4)
		for i = 0, steps - 1 do
			local x, y, z = Tunnel.pointAt(piece, i / steps)
			table.insert(points, { x = x, y = y, z = z, s = travelled + length * i / steps })
		end
		travelled += length
	end
	return points
end

Check.test("a spiral tower stands on two by two lots at its column, against its street", function()
	local spiral = spiralsAt({ Side = 1, Block = 1, Column = 1, Street = "Bottom" })[1]
	Check.near(spiral.rect.x1, 100, "from the avenue's setback")
	Check.near(spiral.rect.x2, 470, "two lots and an alley wide")
	Check.near(spiral.rect.z1, 1110, "against the block's lowest lots")
	Check.near(spiral.rect.z2, 1480, "two lots and an alley deep")
	local third = spiralsAt({ Side = -1, Block = 1, Column = 3, Street = "Bottom" })[1]
	Check.near(third.rect.x1, -890, "two columns further out, the other side")
	Check.near(third.rect.x2, -520)
end)

Check.test("a spiral comes in on the ground from its street and ends level on the roof heading back out", function()
	local spiral = spiralsAt({ Side = 1, Block = 1, Column = 1, Street = "Bottom" })[1]
	local ground = Tunnel.groundHeight(city({}).Tunnels)
	Check.eq(spiral.warning, nil)
	Check.near(spiral.entry.x, 285 + 105, "a helix radius out from the middle")
	Check.near(spiral.entry.z, 1110, "on the street side")
	Check.near(spiral.pieces[1].fromY, ground, "on the ground")
	local last = spiral.pieces[#spiral.pieces]
	Check.near(last.fromY, spiral.roof + ground, "level on the roof")
	Check.near(last.toY, spiral.roof + ground)
	Check.near(spiral.mouth.x, 285 - 105, "back down the other side")
	Check.near(spiral.mouth.z, 1110 + 225 - 80, "LevelRun on from where the helix comes out")
	Check.near(spiral.runway, 225 - 80, "the rest of the roof to its street edge")
	Check.near(spiral.outX, 0)
	Check.near(spiral.outZ, -1, "heading out toward the street")
	Check.near(spiral.roof, ground + 2 * 72 + 33 + 2, "the roof just over the last whole loop")
end)

Check.test("a spiral against the top street on the other side is the mirror image", function()
	local spiral = spiralsAt({ Side = -1, Block = 1, Column = 1, Street = "Top" })[1]
	Check.eq(spiral.warning, nil)
	Check.near(spiral.entry.x, -285 - 105)
	Check.near(spiral.entry.z, 1480)
	Check.near(spiral.mouth.x, -285 + 105)
	Check.near(spiral.mouth.z, 1480 - (225 - 80))
	Check.near(spiral.outZ, 1)
end)

Check.test("a spiral's tube never meets itself", function()
	local points = samples(spiralsAt({ Side = 1, Block = 1, Column = 1, Street = "Bottom" })[1])
	for i, a in points do
		for j = i + 1, #points do
			local b = points[j]
			if b.s - a.s > 3 * SPIRALS.Outside then
				local apart = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
				if apart < 2 * SPIRALS.Outside then
					error(`tube at {a.s} and {b.s} overlap: middles {apart} apart`)
				end
			end
		end
	end
end)

Check.test("a spiral never climbs steeper than 20 degrees, even up through the roof", function()
	local spiral = spiralsAt({ Side = 1, Block = 1, Column = 1, Street = "Bottom" })[1]
	for index, piece in spiral.pieces do
		local length = Tunnel.length(piece)
		for i = 0, 99 do
			local _, y0 = Tunnel.pointAt(piece, i / 100)
			local _, y1 = Tunnel.pointAt(piece, (i + 1) / 100)
			local slope = math.abs(y1 - y0) / (length / 100)
			Check.eq(slope <= math.tan(math.rad(20)), true, `piece {index} climbs {math.deg(math.atan(slope))} degrees`)
		end
	end
end)

Check.test("a spiral's tube stays inside its building", function()
	local spiral = spiralsAt({ Side = 1, Block = 1, Column = 1, Street = "Bottom" })[1]
	local rect = spiral.rect
	for _, p in samples(spiral) do
		if p.s > SPIRALS.Outside then
			local inside = math.min(p.x - rect.x1, rect.x2 - p.x, p.z - rect.z1, rect.z2 - p.z)
			Check.eq(inside >= SPIRALS.Outside, true, `{inside} inside at {p.s}`)
		end
	end
end)

Check.test("the roof covers the tube but at the hatch, where it comes up through", function()
	local spiral = spiralsAt({ Side = 1, Block = 1, Column = 1, Street = "Bottom" })[1]
	local bottom = spiral.roof - SPIRALS.RoofThickness
	local onRoof = spiral.roof + Tunnel.groundHeight(city({}).Tunnels) - 0.01
	local hatch = spiral.hatch
	local crossings = 0
	for _, p in samples(spiral) do
		-- Until it lies on the roof, any of it at the roof's height.
		if p.y < onRoof and p.y + SPIRALS.Outside > bottom then
			crossings += 1
			local inHatch = p.x >= hatch.x1 and p.x <= hatch.x2 and p.z >= hatch.z1 and p.z <= hatch.z2
			Check.eq(inHatch, true, `through the roof outside the hatch at {p.x}, {p.z}`)
		end
	end
	Check.eq(crossings > 0, true, "it does come up through the roof")
	Check.near(spiral.exit.x, spiral.mouth.x, "it leaves the hatch on its line")
	Check.near(spiral.exit.z, hatch.z1, "at the hatch's street side")
end)

Check.test("a spiral in a block that does not exist is skipped", function()
	Check.eq(#spiralsAt({ Side = 1, Block = 9, Column = 1, Street = "Bottom" }), 0)
end)

local CLIMB: Tunnel.VolcanoClimb = {
	Radius = 100,
	Pitch = 72,
	Loops = 2,
	Inset = 340,
	LevelRun = 80,
	Outside = 33,
	FloorThickness = 2,
}

local function volcanoPoints(tube: Tunnel.VolcanoTube): { { x: number, y: number, z: number, s: number } }
	return samples({ pieces = tube.pieces } :: any)
end

Check.test("the volcano's tube comes in on the ground in front, right of the middle, heading in", function()
	local tube = Tunnel.volcano(CLIMB, city({}).Tunnels)
	local ground = Tunnel.groundHeight(city({}).Tunnels)
	Check.eq(tube.warning, nil)
	local first = tube.pieces[1]
	Check.near(first.fromX, 100, "the helix radius to the right")
	Check.near(first.fromZ, -340, "Inset in front of the middle")
	Check.near(first.fromY, ground, "on the ground")
	Check.near(first.toX, 100)
	Check.near(first.toZ, 0, "straight in to where the helix starts")
end)

Check.test("the volcano's tube ends level on the crater floor, left of the middle, heading for the front", function()
	local tube = Tunnel.volcano(CLIMB, city({}).Tunnels)
	local ground = Tunnel.groundHeight(city({}).Tunnels)
	Check.near(tube.floor, ground + 2 * 72 + 33 + 2, "the floor just over the last whole loop")
	local last = tube.pieces[#tube.pieces]
	Check.near(last.fromY, tube.floor + ground, "level on the floor")
	Check.near(last.toY, tube.floor + ground)
	Check.near(last.fromX, -100, "out on the other side of the middle")
	Check.near(last.fromZ, 0)
	Check.near(last.toX, -100)
	Check.near(last.toZ, -80, "LevelRun on toward the front")
	Check.near(tube.exit.x, -100)
	Check.near(tube.exit.z, 0)
	Check.near(tube.mouth.x, -100)
	Check.near(tube.mouth.z, -80)
end)

Check.test("the volcano's helix circles the middle at its radius", function()
	local tube = Tunnel.volcano(CLIMB, city({}).Tunnels)
	for i = 2, #tube.pieces - 1 do
		local piece = tube.pieces[i]
		Check.eq(piece.kind, "arc", `piece {i}`)
		Check.near(piece.centerX, 0, `piece {i} center x`)
		Check.near(piece.centerZ, 0, `piece {i} center z`)
		Check.near(piece.radius, 100, `piece {i} radius`)
	end
end)

Check.test("the volcano's tube never meets itself", function()
	local points = volcanoPoints(Tunnel.volcano(CLIMB, city({}).Tunnels))
	for i, a in points do
		for j = i + 1, #points do
			local b = points[j]
			if b.s - a.s > 3 * CLIMB.Outside then
				local apart = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
				if apart < 2 * CLIMB.Outside then
					error(`tube at {a.s} and {b.s} overlap: middles {apart} apart`)
				end
			end
		end
	end
end)

Check.test("the volcano's tube never climbs steeper than 20 degrees", function()
	local tube = Tunnel.volcano(CLIMB, city({}).Tunnels)
	for index, piece in tube.pieces do
		local length = Tunnel.length(piece)
		for i = 0, 99 do
			local _, y0 = Tunnel.pointAt(piece, i / 100)
			local _, y1 = Tunnel.pointAt(piece, (i + 1) / 100)
			local slope = math.abs(y1 - y0) / (length / 100)
			Check.eq(slope <= math.tan(math.rad(20)), true, `piece {index} climbs {math.deg(math.atan(slope))} degrees`)
		end
	end
end)

Check.test("the crater floor clears the tube but at the hatch on the back half", function()
	local tube = Tunnel.volcano(CLIMB, city({}).Tunnels)
	Check.near(tube.hatch.x1, -133)
	Check.near(tube.hatch.x2, 133)
	Check.near(tube.hatch.z1, 0)
	Check.near(tube.hatch.z2, 133)
	local bottom = tube.floor - CLIMB.FloorThickness
	for _, p in volcanoPoints(tube) do
		local inHatch = p.x >= tube.hatch.x1 and p.x <= tube.hatch.x2 and p.z >= tube.hatch.z1 and p.z <= tube.hatch.z2
		local onFloor = p.z <= 0 and math.abs(p.x + 100) < 1e-6 and p.y > bottom
		if not inHatch and not onFloor then
			Check.eq(
				p.y + CLIMB.Outside <= bottom + 1e-6,
				true,
				`tube top {p.y + CLIMB.Outside} at {p.x}, {p.z} through the floor`
			)
		end
	end
end)

local SHAPE: Tunnel.Shape = { Radius = 30, Sides = 24, MouthFloor = 68, MouthCurve = 18, FlareLength = 80 }

local function outsideOf(radius: number): number
	local c = math.cos(math.pi / 24)
	return (radius * c + 2) / c
end

Check.test("a tube's section at its mouth is the mouth's flat floor and small curves", function()
	local section = Tunnel.section(SHAPE, 0)
	Check.near(section.flat, 34)
	Check.near(section.outside, outsideOf(18))
	Check.near(section.middle, 18 * math.cos(math.pi / 24) + Tunnel.LIFT)
end)

Check.test("past the flare a tube's section is round, its middle a ground height up", function()
	for _, t in { 80, 200 } do
		local section = Tunnel.section(SHAPE, t)
		Check.near(section.flat, 0, `flat at {t}`)
		Check.near(section.outside, outsideOf(30), `outside at {t}`)
		Check.near(section.middle, Tunnel.groundHeight(city({}).Tunnels), `middle at {t}`)
	end
end)

Check.test("half way through the flare the section is half way, eased", function()
	local section = Tunnel.section(SHAPE, 40)
	Check.near(section.flat, 17)
	Check.near(section.outside, outsideOf(24))
end)

Check.test("a section is widest at its middle and nothing above or below its outline", function()
	local section = Tunnel.section(SHAPE, 0)
	Check.near(Tunnel.halfWidth(section, section.middle) :: number, section.flat + section.outside)
	Check.near(
		Tunnel.halfWidth(section, section.middle + 5) :: number,
		Tunnel.halfWidth(section, section.middle - 5) :: number
	)
	Check.eq(Tunnel.halfWidth(section, section.middle + section.outside + 0.1), nil, "above")
	Check.eq(Tunnel.halfWidth(section, section.middle - section.outside - 0.1), nil, "below")
end)

Check.test("the volcano's last half loop covers less of the crater the higher it is", function()
	local tube = Tunnel.volcano(CLIMB, city({}).Tunnels)
	local climb = tube.pieces[#tube.pieces - 1]
	local low = Tunnel.above(climb, CLIMB.Outside, tube.floor - 1) :: Tunnel.Rect
	local high = Tunnel.above(climb, CLIMB.Outside, tube.floor + 40) :: Tunnel.Rect
	Check.eq(low ~= nil and high ~= nil, true, "both found")
	Check.near(low.x1, -133, "low: the whole half loop", 1)
	Check.eq(low.x2 > 125, true, `low reaches {low.x2}, nearly the whole way, as its start is still under the floor`)
	Check.near(low.z2, 133, nil, 1)
	Check.eq(high.x2 < low.x2 - 50, true, `high reaches only {high.x2}`)
	Check.eq(high.x1 <= -100 - CLIMB.Outside + 1, true, "high still holds the end by the exit")
	Check.eq(Tunnel.above(climb, CLIMB.Outside, tube.floor + 100), nil, "nothing that high")
end)

Check.test("a volcano tube whose loops would meet warns", function()
	local climb = table.clone(CLIMB)
	climb.Pitch = 60
	Check.eq(Tunnel.volcano(climb, city({}).Tunnels).warning ~= nil, true)
end)

Check.test("easeEnds climbs evenly in the middle and eases in and out over its share", function()
	Check.near(Tunnel.easeEnds(0, 0.1), 0)
	Check.near(Tunnel.easeEnds(1, 0.1), 1)
	Check.near(Tunnel.easeEnds(0.5, 0.1), 0.5)
	local step = 1e-4
	local function slope(t: number): number
		return (Tunnel.easeEnds(t + step, 0.1) - Tunnel.easeEnds(t - step, 0.1)) / (2 * step)
	end
	Check.near(slope(0.3), 1 / 0.9, "even in the middle", 1e-6)
	Check.near(slope(0.7), 1 / 0.9, nil, 1e-6)
	Check.near(slope(step), 0, "level at the start", 0.01)
	Check.near(slope(1 - step), 0, "and at the end", 0.01)
	Check.near(Tunnel.easeEnds(0.3, 0), 0.3, "no share climbs evenly all the way")
end)

Check.test("a segment with an Ease climbs evenly", function()
	local pieces = Tunnel.path(0, 0, 0, -1, { { Straight = 100, Rise = 50, Ease = 0.2 } })
	local _, y = Tunnel.pointAt(pieces[1], 0.5)
	Check.near(y, 25)
	local _, a = Tunnel.pointAt(pieces[1], 0.3)
	Check.near(a, 50 * Tunnel.easeEnds(0.3, 0.2))
end)

local GRAVITRON_SHAPE: Gravitron.Shape = {
	FloorRadius = 200,
	CurveRadius = 40,
	Lean = 15,
	Height = 300,
	Tilt = 20,
	Thickness = 2,
	Clearance = 1,
}

local BOWL: Tunnel.GravitronBowl = {
	Tilt = 20,
	CenterHeight = Gravitron.centerHeight(GRAVITRON_SHAPE),
	FloorThickness = 2,
}

local TUBES: Tunnel.GravitronTubes = {
	TwistRadius = 80,
	Pitch = 180,
	Loops = 2,
	TwistEase = 0.1,
	TopGap = 6,
	ExitAngle = 45,
	DiveSlope = 40,
	Level = 120,
	Dip = 30,
	DipLength = 120,
	Outside = 33,
}

local FACE = 30 * math.cos(math.pi / 24)

-- Every few studs along both of a strand's tubes, in the bowl's space, up
-- to where the twist comes up through the floor, with how far along.
local function strandPoints(strand: Tunnel.GravitronStrand): { { x: number, y: number, z: number, s: number } }
	local points = {}
	local travelled = 0
	local function add(pieces: { Tunnel.Piece }, ground: boolean)
		for _, piece in pieces do
			local length = Tunnel.length(piece)
			local steps = math.ceil(length / 4)
			for i = 0, steps - 1 do
				local x, y, z = Tunnel.pointAt(piece, i / steps)
				if ground then
					x, y, z = Gravitron.toLocal(GRAVITRON_SHAPE, x, y, z)
				end
				if y < 0 then
					table.insert(points, { x = x, y = y, z = z, s = travelled + length * i / steps })
				end
			end
			travelled += length
		end
	end
	add(strand.approach, true)
	add(strand.twist, false)
	return points
end

Check.test("two strands start opposite each other under the bowl, heading along X", function()
	local strands, warning = Tunnel.gravitron(TUBES, BOWL, city({}).Tunnels)
	Check.eq(warning, nil)
	Check.eq(#strands, 2)
	local top = -(2 + 6 + 33)
	for _, strand in strands do
		local first = strand.twist[1]
		Check.near(first.fromX, 0, "on the Z axis")
		Check.near(first.fromZ, strand.side * 80, "TwistRadius out")
		Check.near(first.fromY, top - 2 * 180, "Loops of Pitch under the top")
		Check.eq(strand.heading, strand.side)
		Check.near(strand.top, top, "the top loop's outside TopGap under the floor")
	end
	Check.eq(strands[1].side, -strands[2].side)
end)

Check.test("each twists Loops times round the bowl's axis to the left, climbing evenly", function()
	for _, strand in Tunnel.gravitron(TUBES, BOWL, city({}).Tunnels) do
		Check.eq(#strand.twist, 2, "the twist, then the exit")
		local piece = strand.twist[1]
		Check.eq(piece.kind, "arc")
		Check.eq(piece.left, true, "counterclockwise from above")
		Check.near(piece.centerX, 0)
		Check.near(piece.centerZ, 0)
		Check.near(piece.radius, 80)
		Check.near(math.deg(piece.sweep), 720)
		Check.near(piece.toY - piece.fromY, 360)
		Check.eq(piece.ease, 0.1)
	end
end)

Check.test("each comes up through the floor at ExitAngle, its bottom on the floor at its steepest", function()
	for _, strand in Tunnel.gravitron(TUBES, BOWL, city({}).Tunnels) do
		local exit = strand.twist[#strand.twist]
		Check.eq(exit.kind, "straight")
		Check.near(exit.fromY, strand.top)
		local _, y = Tunnel.pointAt(exit, 0.5)
		Check.near(y, FACE / math.cos(math.rad(45)), "the bottom plank meets the floor", 1e-6)
		local _, y0 = Tunnel.pointAt(exit, 0.499)
		local _, y1 = Tunnel.pointAt(exit, 0.501)
		local slope = (y1 - y0) / (Tunnel.length(exit) * 0.002)
		Check.near(math.deg(math.atan(slope)), 45, "at ExitAngle", 0.01)
		Check.near(exit.toZ, strand.side * 80, "straight on from the twist")
		Check.eq((exit.toX - exit.fromX) * strand.side > 0, true)
	end
end)

Check.test("each comes in level on the ground from its mouth, dives under its twist, and climbs to meet it", function()
	local ground = Tunnel.groundHeight(city({}).Tunnels)
	for _, strand in Tunnel.gravitron(TUBES, BOWL, city({}).Tunnels) do
		local level, dive, dip = strand.approach[1], strand.approach[2], strand.approach[3]
		Check.near(level.fromX, strand.mouth.x)
		Check.near(level.fromZ, strand.mouth.z)
		Check.near(level.fromY, ground, "on the ground")
		Check.near(level.toY, ground, "level")
		Check.near(Tunnel.length(level), 120, "for Level")
		Check.eq((level.toX - level.fromX) * strand.heading > 0, true, "heading in")
		local first = strand.twist[1]
		local x, y, z = Gravitron.fromLocal(GRAVITRON_SHAPE, first.fromX, first.fromY, first.fromZ)
		Check.near(dive.toY, y - 30, "Dip under the twist's start", 1e-6)
		Check.near(Tunnel.length(dip), 120, "climbing back over DipLength")
		Check.near(dip.toX, x, "to meet the twist", 1e-6)
		Check.near(dip.toY, y, nil, 1e-6)
		Check.near(dip.toZ, z, nil, 1e-6)
		for i = 0, 99 do
			local _, a = Tunnel.pointAt(dive, i / 100)
			local _, b = Tunnel.pointAt(dive, (i + 1) / 100)
			local slope = math.abs(b - a) / (Tunnel.length(dive) / 100)
			Check.eq(slope <= math.tan(math.rad(40)) + 1e-6, true, `dives {math.deg(math.atan(slope))} degrees`)
		end
	end
end)

Check.test("the twist's rings roll by the tilt to meet the approach's", function()
	for _, strand in Tunnel.gravitron(TUBES, BOWL, city({}).Tunnels) do
		Check.near(strand.roll, strand.side * math.rad(20))
	end
end)

Check.test("no tube meets another, or itself", function()
	local strands = Tunnel.gravitron(TUBES, BOWL, city({}).Tunnels)
	local a, b = strandPoints(strands[1]), strandPoints(strands[2])
	local closest = math.huge
	for _, p in a do
		for _, q in b do
			closest = math.min(closest, math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 + (p.z - q.z) ^ 2))
		end
	end
	Check.eq(closest >= 2 * 33, true, `the two strands come {closest} apart`)
	for _, points in { a, b } do
		for i, p in points do
			for j = i + 1, #points do
				local q = points[j]
				if q.s - p.s > 3 * 33 then
					local apart = math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 + (p.z - q.z) ^ 2)
					Check.eq(apart >= 2 * 33, true, `a strand at {p.s} and {q.s} comes {apart} apart`)
				end
			end
		end
	end
end)

Check.test("a Pitch that lets the strands meet warns", function()
	local tubes = table.clone(TUBES)
	tubes.Pitch = 120
	local _, warning = Tunnel.gravitron(tubes, BOWL, city({}).Tunnels)
	Check.eq(warning ~= nil, true)
end)

Check.finish("Tunnel")
