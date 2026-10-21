--!strict
local Check = require("./Check")
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

Check.test("in a climbing tube the pull is out from the middle line where it has climbed to", function()
	local climbing = Tunnel.path(0, 0, 0, -1, { { Straight = 100, Rise = 20 } }, 30)
	local x, y, z = Tunnel.pull(climbing, 30, 0, 40 + 10, -50)
	vec("above the middle halfway up", x, y, z, 0, 1, 0)
	x, y, z = Tunnel.pull(climbing, 30, 0, 40 - 10, -50)
	vec("below it", x, y, z, 0, -1, 0)
	Check.eq(Tunnel.pull(climbing, 30, 0, 5, -100), nil, "under the floor at the top")
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
	vec("above the second loop", x, y, z, 0, 1, 0)
	local low = 30 + 200 * Tunnel.ease(1 / 8)
	x, y, z = Tunnel.pull(spiral, 30, -80, low - 10, -80)
	vec("below the first loop", x, y, z, 0, -1, 0)
	Check.eq(Tunnel.pull(spiral, 30, -80, (low + high) / 2, -80), nil, "between the loops")
end)

Check.test("in a right-hand spiral the pull is out from the loop the car is in", function()
	-- Two loops right around (80, 0): a quarter of the way round the second
	-- loop is 5/8 of the climb along.
	local spiral = Tunnel.path(0, 0, 0, -1, { { Turn = -720, Radius = 80, Rise = 200 } }, 30)
	local high = 30 + 200 * Tunnel.ease(5 / 8)
	local x, y, z = Tunnel.pull(spiral, 30, 80, high + 10, -80)
	vec("above the second loop", x, y, z, 0, 1, 0)
end)

local SPIRALS: Tunnel.Spirals = {
	Radius = 105,
	Pitch = 72,
	Loops = 2,
	Inset = 225,
	KickRoom = 40,
	LevelRun = 85,
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
	Check.near(spiral.mouth.z, 1110 + 40, "KickRoom in from the roof's street edge")
	Check.near(spiral.outX, 0)
	Check.near(spiral.outZ, -1, "heading out toward the street")
	Check.near(spiral.roof, ground + 2.5 * 72 + 33 + 2, "the roof just over the top loop")
end)

Check.test("a spiral against the top street on the other side is the mirror image", function()
	local spiral = spiralsAt({ Side = -1, Block = 1, Column = 1, Street = "Top" })[1]
	Check.eq(spiral.warning, nil)
	Check.near(spiral.entry.x, -285 - 105)
	Check.near(spiral.entry.z, 1480)
	Check.near(spiral.mouth.x, -285 + 105)
	Check.near(spiral.mouth.z, 1480 - 40)
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

Check.finish("Tunnel")
