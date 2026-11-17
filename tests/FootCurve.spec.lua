--!strict
local Check = require("./Check")
local CurveProfile = require("../src/shared/CurveProfile")
local FootCurve = require("../src/shared/FootCurve")

Check.test("a curved wall's side rises plank by plank from its base line", function()
	local top = FootCurve.curve(100, 1, 60, 35, 10)
	local corners = CurveProfile.arc(60, 0, 35, 10)
	Check.eq(#top, 10)
	for i, segment in top do
		Check.near(segment.from, 100 + corners[i].out, `segment {i} from`)
		Check.near(segment.to, 100 + corners[i + 1].out, `segment {i} to`)
		Check.near(segment.fromHeight, corners[i].up, `segment {i} from height`)
		Check.near(segment.toHeight, corners[i + 1].up, `segment {i} to height`)
	end
end)

Check.test("a wall rising toward the start is sorted from its top down to its base line", function()
	local top = FootCurve.curve(100, -1, 60, 35, 10)
	Check.near(top[1].from, 100 - 60 * math.sin(math.rad(35)), "starts at the top")
	Check.near(top[1].fromHeight, 60 * (1 - math.cos(math.rad(35))), "as high as the wall")
	Check.near(top[10].to, 100, "ends at the base line")
	Check.near(top[10].toHeight, 0, "on the ground")
	for i = 2, 10 do
		Check.near(top[i].from, top[i - 1].to, `segment {i} follows the last`)
		Check.eq(top[i].fromHeight < top[i - 1].fromHeight, true, `segment {i} lower`)
	end
end)

Check.test("past vertical, only the wall up to vertical counts", function()
	local top = FootCurve.curve(0, 1, 70, 110, 14)
	local last = top[#top]
	Check.near(last.to, 70, "out a radius")
	Check.near(last.toHeight, 70, "a radius up")
	for i, segment in top do
		Check.eq(segment.to > segment.from, true, `segment {i} runs forward`)
	end
end)

Check.test("a level side is one piece, no higher than the full curve", function()
	local pieces = FootCurve.pieces({ { from = 0, to = 40, fromHeight = 30, toHeight = 30 } }, 20, 1, 0.5)
	Check.eq(#pieces, 1)
	Check.near(pieces[1].from, 0)
	Check.near(pieces[1].to, 40)
	Check.near(pieces[1].height, 20, "capped at the curve's top")
end)

Check.test("a slope is cut into pieces each as high as the low end of the side above it", function()
	local pieces = FootCurve.pieces({ { from = 0, to = 10, fromHeight = 0, toHeight = 4 } }, 20, 1, 0.5)
	Check.eq(#pieces, 3, "four rises of 1, the first under the minimum height")
	for i, piece in pieces do
		Check.near(piece.from, 2.5 * i, `piece {i} from`)
		Check.near(piece.to, 2.5 * (i + 1), `piece {i} to`)
		Check.near(piece.height, i, `piece {i} height`)
	end
end)

Check.test("a slope falling away is cut the same way, each piece at its low end", function()
	local pieces = FootCurve.pieces({ { from = 0, to = 10, fromHeight = 4, toHeight = 0 } }, 20, 1, 0.5)
	Check.eq(#pieces, 3)
	Check.near(pieces[1].height, 3)
	Check.near(pieces[3].height, 1)
	Check.near(pieces[3].to, 7.5)
end)

Check.test("neighbors of the same height join, including where a slope tops out", function()
	local pieces = FootCurve.pieces({
		{ from = 0, to = 10, fromHeight = 30, toHeight = 30 },
		{ from = 10, to = 20, fromHeight = 30, toHeight = 25 },
		{ from = 20, to = 26, fromHeight = 25, toHeight = 25 },
		{ from = 26, to = 32, fromHeight = 10, toHeight = 10 },
	}, 20, 1, 0.5)
	Check.eq(#pieces, 2)
	Check.near(pieces[1].to, 26, "every part at or over the top is one")
	Check.near(pieces[1].height, 20)
	Check.near(pieces[2].from, 26, "a stair step down is its own")
	Check.near(pieces[2].height, 10)
end)

Check.test("pieces never join across a stretch with nothing above", function()
	local pieces = FootCurve.pieces({
		{ from = 0, to = 10, fromHeight = 30, toHeight = 30 },
		{ from = 50, to = 60, fromHeight = 30, toHeight = 30 },
	}, 20, 1, 0.5)
	Check.eq(#pieces, 2)
end)

Check.finish("FootCurve")
