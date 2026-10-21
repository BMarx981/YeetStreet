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
	Check.near(arc.centerX, 0, "center x")
	Check.near(arc.centerZ, 80, "center z")
	Check.near(finish.x, 80, "end x")
	Check.near(finish.z, 80, "end z")
	Check.near(finish.headingZ, 1, "heading z")
	Check.near(arc.startX, 80, "starts at the exit")
	Check.near(arc.startZ, 80, "starts at the exit")
end)

Check.test("an S of straights and turns ends where its pieces add up", function()
	local segments = {
		{ Straight = 60 },
		{ Turn = -90, Radius = 80 },
		{ Straight = 100 },
		{ Turn = 90, Radius = 80 },
		{ Turn = -90, Radius = 80 },
		{ Straight = 140 },
	}
	local pieces, finish = Tunnel.path(100, 450, 1, 0, segments)
	Check.eq(#pieces, 6)
	Check.near(finish.x, 400, "end x")
	Check.near(finish.z, 930, "end z")
	Check.near(finish.headingZ, 1, "heading z")
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

local function city(places: { Tunnel.Place }): Tunnel.City
	return {
		Avenue = { Width = 160 },
		Streets = { Width = 100, Z = { 1000, 200 } },
		Buildings = { TopZ = 1500, Setback = 20, Lot = 160, Alley = 50 },
		Tunnels = {
			Radius = 30,
			Sides = 24,
			Columns = 2,
			Rows = 3,
			Shapes = {
				Corner = {
					Start = "Avenue",
					Offset = 460,
					Segments = { { Straight = 40 }, { Turn = -90, Radius = 250 } },
				},
				Long = {
					Start = "Street",
					Offset = 140,
					Segments = {
						{ Straight = 100 },
						{ Turn = -25, Radius = 300 },
						{ Straight = 80 },
						{ Turn = 25, Radius = 300 },
					},
				},
			},
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

Check.test("a corner tunnel runs from the avenue side round onto the street side", function()
	local tubes = Tunnel.layout(city({ { Side = 1, Block = 2, Column = 1, Shape = "Corner" } }))
	Check.eq(#tubes, 1)
	local tube = tubes[1]
	Check.near(tube.rect.x1, 100, "avenue side")
	Check.near(tube.rect.x2, 470, "far side")
	Check.near(tube.rect.z1, 350, "back")
	Check.near(tube.rect.z2, 930, "street side")
	Check.near(tube.entry.x, 100, "enters on the avenue side")
	Check.near(tube.entry.z, 470, "Offset back from the street side")
	Check.near(tube.finish.x, 390, "out after the sweep")
	Check.near(tube.finish.z, 930, "leaves on the street side")
	Check.near(tube.finish.headingZ, 1, "heading for the street")
	Check.eq(tube.warning, nil)
end)

Check.test("the other side of the avenue is the mirror image", function()
	local tube = Tunnel.layout(city({ { Side = -1, Block = 2, Column = 1, Shape = "Corner" } }))[1]
	Check.near(tube.rect.x1, -470)
	Check.near(tube.rect.x2, -100)
	Check.near(tube.entry.x, -100)
	Check.near(tube.finish.x, -390)
	Check.near(tube.finish.z, 930)
end)

Check.test("a long tunnel runs from street to street, out past the far column", function()
	local tube = Tunnel.layout(city({ { Side = 1, Block = 2, Column = 3, Shape = "Long" } }))[1]
	Check.near(tube.rect.x1, 520, "starts two lots and two alleys out")
	Check.near(tube.entry.x, 660)
	Check.near(tube.entry.z, 930)
	Check.near(tube.finish.z, 350, "leaves on the back")
	Check.near(tube.finish.headingZ, -1)
	local jog = 2 * 300 * (1 - math.cos(math.rad(25))) + 80 * math.sin(math.rad(25))
	Check.near(tube.finish.x, 660 + jog, "jogged away from the avenue", 1e-6)
end)

Check.test("a place in a block that does not exist is skipped", function()
	Check.eq(#Tunnel.layout(city({ { Side = 1, Block = 5, Column = 1, Shape = "Corner" } })), 0)
end)

Check.test("the tube's middle sits so its bottom plank lies on the floor", function()
	local tunnels = city({}).Tunnels
	Check.near(Tunnel.centerHeight(tunnels, 0.1), 0.1 + 30 * math.cos(math.pi / 24) + Tunnel.LIFT)
end)

local function vec(label: string, x: number?, y: number?, z: number?, ex: number, ey: number, ez: number)
	Check.eq(x ~= nil, true, `{label}: inside`)
	Check.near(x :: number, ex, `{label} x`, 1e-6)
	Check.near(y :: number, ey, `{label} y`, 1e-6)
	Check.near(z :: number, ez, `{label} z`, 1e-6)
end

local straight = Tunnel.path(0, 0, 0, -1, { { Straight = 100 } })

Check.test("in a straight tube the pull is out from its middle line", function()
	local x, y, z = Tunnel.pull(straight, 30, 30, 0, 50, -50)
	vec("above", x, y, z, 0, 1, 0)
	x, y, z = Tunnel.pull(straight, 30, 30, 20, 30, -50)
	vec("beside", x, y, z, 1, 0, 0)
	x, y, z = Tunnel.pull(straight, 30, 30, 0, 10, -50)
	vec("below", x, y, z, 0, -1, 0)
end)

Check.test("on the middle line the pull is straight down", function()
	local x, y, z = Tunnel.pull(straight, 30, 30, 0, 30, -50)
	vec("middle", x, y, z, 0, -1, 0)
end)

Check.test("outside the tube there is no pull", function()
	Check.eq(Tunnel.pull(straight, 30, 30, 0, 10, 5), nil, "before the start")
	Check.eq(Tunnel.pull(straight, 30, 30, 0, 10, -105), nil, "past the end")
	Check.eq(Tunnel.pull(straight, 30, 30, 31, 30, -50), nil, "beyond the wall")
end)

-- Facing -Z, a quarter turn left around (-80, 0).
local left = Tunnel.path(0, 0, 0, -1, { { Turn = 90, Radius = 80 } })

Check.test("in a turn the pull is out from the middle line around the turn", function()
	local a = math.rad(45)
	-- 45 degrees around from the start, 20 out from the middle line, level with it.
	local ox, oz = math.cos(a), -math.sin(a)
	local x, y, z = Tunnel.pull(left, 30, 30, -80 + 100 * ox, 30, 100 * oz)
	vec("outer side", x, y, z, ox, 0, oz)
	x, y, z = Tunnel.pull(left, 30, 30, -80 + 80 * ox, 50, 80 * oz)
	vec("roof", x, y, z, 0, 1, 0)
end)

Check.test("past either end of a turn there is no pull", function()
	Check.eq(Tunnel.pull(left, 30, 30, 0, 30, 10), nil, "before it")
	Check.eq(Tunnel.pull(left, 30, 30, -90, 30, 80), nil, "around the far side")
end)

Check.test("a right turn's tube is found from either end", function()
	local right = Tunnel.path(0, 0, 0, -1, { { Turn = -90, Radius = 80 } })
	Check.eq(Tunnel.pull(right, 30, 30, 1, 30, -5) ~= nil, true, "near its start")
	Check.eq(Tunnel.pull(right, 30, 30, 75, 30, -80) ~= nil, true, "near its end")
	Check.eq(Tunnel.pull(right, 30, 30, -5, 30, -5) ~= nil, true, "beside its start")
	Check.eq(Tunnel.pull(right, 30, 30, 160, 30, 0), nil, "on the circle but outside the turn")
end)

Check.finish("Tunnel")
