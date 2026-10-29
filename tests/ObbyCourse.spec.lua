--!strict
local Check = require("./Check")
local ObbyCourse = require("../src/shared/ObbyCourse")

local T: ObbyCourse.Tuning = {
	X = 0,
	Y = 100,
	Z = 0,
	Heading = 0,
	Thickness = 2,
	PadLength = 20,
	RingBorder = 50,
	Stages = {},
}

local function course(stages: { ObbyCourse.Stage }): { ObbyCourse.Piece }
	local t = table.clone(T)
	t.Stages = stages
	return ObbyCourse.layout(t)
end

local function stage(segments: { ObbyCourse.Segment }): ObbyCourse.Stage
	return { Name = "Test", Width = 30, Segments = segments }
end

local function pads(pieces: { ObbyCourse.Piece }): { ObbyCourse.Piece }
	local found = {}
	for _, piece in pieces do
		if piece.Kind == "Pad" then
			table.insert(found, piece)
		end
	end
	return found
end

Check.test("the start pad is checkpoint 0, its top at the start height, running forward from the start", function()
	local start = course({})[1]
	Check.eq(start.Kind, "Pad")
	Check.eq(start.Checkpoint, 0)
	Check.eq(start.Stage, 0)
	Check.near(start.Y + start.Height / 2, 100)
	Check.near(start.X, 0)
	Check.near(start.Z, -10)
	Check.eq(start.Length, 20)
end)

Check.test("each stage ends with a pad numbered by the stage", function()
	local found = pads(course({ stage({ { Kind = "Road", Length = 50 } }), stage({ { Kind = "Road", Length = 50 } }) }))
	Check.eq(#found, 3)
	Check.eq(found[2].Checkpoint, 1)
	Check.eq(found[2].Stage, 1)
	Check.eq(found[3].Checkpoint, 2)
end)

Check.test("a road's top is level with the course and it runs on from the last piece", function()
	local pieces = course({ stage({ { Kind = "Road", Length = 50 } }) })
	local road = pieces[2]
	Check.eq(road.Kind, "Slab")
	Check.eq(road.Stage, 1)
	Check.near(road.Y + road.Height / 2, 100)
	Check.near(road.Z, -20 - 25)
	Check.eq(road.Width, 30)
	Check.near(pieces[3].Z, -70 - 10)
end)

Check.test("a segment can set its own width", function()
	local road = course({ stage({ { Kind = "Road", Length = 50, Width = 12 } }) })[2]
	Check.eq(road.Width, 12)
end)

Check.test("a ramp is a wedge rising forward on a slab, and lifts what follows", function()
	local pieces = course({ stage({ { Kind = "Ramp", Length = 40, Rise = 8 } }) })
	local base, wedge, pad = pieces[2], pieces[3], pieces[4]
	Check.eq(base.Kind, "Slab")
	Check.near(base.Y + base.Height / 2, 100)
	Check.eq(wedge.Kind, "Wedge")
	Check.near(wedge.Y - wedge.Height / 2, 100)
	Check.near(wedge.Height, 8)
	Check.eq(wedge.Length, 40)
	Check.near(wedge.Z, -40)
	Check.eq(wedge.Rising, true)
	Check.near(pad.Y + pad.Height / 2, 108)
end)

Check.test("a ramp down sits on the lower level and rises back toward the start", function()
	local pieces = course({ stage({ { Kind = "Ramp", Length = 40, Rise = -8 } }) })
	local base, wedge, pad = pieces[2], pieces[3], pieces[4]
	Check.near(base.Y + base.Height / 2, 92)
	Check.near(wedge.Y - wedge.Height / 2, 92)
	Check.eq(wedge.Rising, false)
	Check.near(pad.Y + pad.Height / 2, 92)
end)

Check.test("a gap leaves empty space and can land lower", function()
	local pieces = course({ stage({ { Kind = "Gap", Length = 15, Rise = -5 } }) })
	Check.eq(#pieces, 2)
	local pad = pieces[2]
	Check.near(pad.Z, -20 - 15 - 10)
	Check.near(pad.Y + pad.Height / 2, 95)
end)

Check.test("a gap can land off to the right", function()
	local pad = course({ stage({ { Kind = "Gap", Length = 15, Offset = 6 } }) })[2]
	Check.near(pad.X, 6)
end)

Check.test("a left turn is a square corner, and the course carries on to the left", function()
	local pieces = course({ stage({ { Kind = "Turn", Angle = 90 } }) })
	local corner, pad = pieces[2], pieces[3]
	Check.eq(corner.Kind, "Slab")
	Check.eq(corner.Width, 30)
	Check.eq(corner.Length, 30)
	Check.near(corner.Z, -20 - 15)
	Check.near(corner.Heading, 0)
	Check.near(pad.Heading, 90)
	Check.near(pad.Z, -35)
	Check.near(pad.X, -15 - 10)
end)

Check.test("a corner says so, and a road doesn't", function()
	local pieces = course({ stage({ { Kind = "Road", Length = 50 }, { Kind = "Turn", Angle = 90 } }) })
	Check.eq(pieces[2].Corner, nil)
	Check.eq(pieces[3].Corner, true)
end)

Check.test("a right turn carries the course to the right", function()
	local pad = course({ stage({ { Kind = "Turn", Angle = -90 } }) })[3]
	Check.near(pad.Heading, -90)
	Check.near(pad.X, 25)
end)

Check.test("a road can be a booster, and a plain road isn't", function()
	local pieces = course({ stage({ { Kind = "Road", Length = 50 }, { Kind = "Road", Length = 20, Boost = 150 } }) })
	Check.eq(pieces[2].Boost, nil)
	Check.eq(pieces[3].Boost, 150)
end)

Check.test("a booster ramp boosts on its wedge, not the slab under it", function()
	local pieces = course({ stage({ { Kind = "Ramp", Length = 40, Rise = 8, Boost = 140 } }) })
	Check.eq(pieces[2].Boost, nil)
	Check.eq(pieces[3].Kind, "Wedge")
	Check.eq(pieces[3].Boost, 140)
end)

Check.test("a mover is a slab where a road would be, carrying how it moves", function()
	local pieces = course({
		stage({ { Kind = "Mover", Length = 40, Width = 20, Axis = "Up", Travel = -24, Move = 1, Hold = 2, Phase = 0.25 } }),
	})
	local slab, pad = pieces[2], pieces[3]
	Check.eq(slab.Kind, "Slab")
	Check.near(slab.Y + slab.Height / 2, 100)
	Check.near(slab.Z, -20 - 20)
	Check.eq(slab.Width, 20)
	Check.eq(slab.Length, 40)
	local mover = slab.Mover :: ObbyCourse.Mover
	Check.eq(mover.Axis, "Up")
	Check.eq(mover.Travel, -24)
	Check.eq(mover.Move, 1)
	Check.eq(mover.Hold, 2)
	Check.eq(mover.Phase, 0.25)
	Check.near(pad.Z, -60 - 10)
end)

Check.test("a road doesn't move", function()
	local road = course({ stage({ { Kind = "Road", Length = 50 } }) })[2]
	Check.eq(road.Mover, nil)
end)

Check.test("a ring is a wall of four pieces around a hole, as thick as its length", function()
	local pieces = course({
		stage({ { Kind = "Ring", Length = 4, Width = 20, Height = 12, Lift = 3, Offset = 5 } }),
	})
	Check.eq(#pieces, 6)
	local left, right, top, bottom = pieces[2], pieces[3], pieces[4], pieces[5]
	for _, wall in { left, right, top, bottom } do
		Check.eq(wall.Kind, "Slab")
		Check.eq(wall.Ring, true)
		Check.eq(wall.Length, 4)
		Check.near(wall.Z, -20 - 2)
	end
	-- The hole runs 5 - 10 to 5 + 10 across and 103 to 115 up.
	Check.near(left.X + left.Width / 2, -5)
	Check.near(left.X - left.Width / 2, -55)
	Check.near(right.X - right.Width / 2, 15)
	Check.near(right.X + right.Width / 2, 65)
	Check.near(left.Y - left.Height / 2, 53)
	Check.near(left.Y + left.Height / 2, 165)
	Check.near(top.Y - top.Height / 2, 115)
	Check.near(top.Y + top.Height / 2, 165)
	Check.near(bottom.Y + bottom.Height / 2, 103)
	Check.near(bottom.Y - bottom.Height / 2, 53)
	for _, bar in { top, bottom } do
		Check.near(bar.X, 5)
		Check.eq(bar.Width, 20)
	end
end)

Check.test("a ring leaves the course where it was, just past the wall", function()
	local pad = course({ stage({ { Kind = "Ring", Length = 4, Width = 20, Height = 12, Lift = 3, Offset = 5 } }) })[6]
	Check.near(pad.X, 0)
	Check.near(pad.Y + pad.Height / 2, 100)
	Check.near(pad.Z, -24 - 10)
end)

Check.test("a road isn't a ring", function()
	local road = course({ stage({ { Kind = "Road", Length = 50 } }) })[2]
	Check.eq(road.Ring, nil)
end)

Check.test("pieces carry the heading of the way the course runs", function()
	local t = table.clone(T)
	t.Heading = 90
	t.Stages = { stage({ { Kind = "Road", Length = 50 } }) }
	local road = ObbyCourse.layout(t)[2]
	Check.near(road.Heading, 90)
	Check.near(road.X, -45)
	Check.near(road.Z, 0)
end)

Check.finish("ObbyCourse")
