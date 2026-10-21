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

Check.finish("Tunnel")
