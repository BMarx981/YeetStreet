--!strict
local Check = require("./Check")
local Bronto = require("../src/shared/Bronto")

local START: Bronto.Start = { Width = 30, Depth = 2 }

-- Shaped like the park's: up the tail, easing off over the hips, along the
-- back, curving up the neck, then straight over the head.
local SEGMENTS: { Bronto.Segment } = {
	{ Length = 150, Angle = 15, Width = 40, Depth = 14 },
	{ Length = 150, Angle = 15, Width = 50, Depth = 30 },
	{ Length = 150, Angle = 4, Width = 60, Depth = 50 },
	{ Length = 250, Angle = 4, Width = 60, Depth = 55 },
	{ Length = 300, Angle = 40, Width = 32, Depth = 22 },
	{ Length = 36, Angle = 40, Width = 36, Depth = 20 },
}

local function startOf(plank: Bronto.Plank): (number, number)
	return plank.out - plank.length / 2 * math.cos(plank.tilt), plank.up - plank.length / 2 * math.sin(plank.tilt)
end

local function endOf(plank: Bronto.Plank): (number, number)
	return plank.out + plank.length / 2 * math.cos(plank.tilt), plank.up + plank.length / 2 * math.sin(plank.tilt)
end

Check.test("one plank per step of each segment, a part step rounding up", function()
	Check.eq(#Bronto.planks(START, { { Length = 100, Angle = 10, Width = 30, Depth = 2 } }, 5), 20)
	Check.eq(
		#Bronto.planks(START, { { Length = 36, Angle = 10, Width = 30, Depth = 2 } }, 5),
		8,
		"36 is 8 planks of 4.5"
	)
	Check.eq(#Bronto.planks(START, SEGMENTS, 5), 30 + 30 + 30 + 50 + 60 + 8)
end)

Check.test("the path starts flat on the ground at the tail tip", function()
	local planks = Bronto.planks(START, SEGMENTS, 5)
	local out, up = startOf(planks[1])
	Check.near(out, 0, "out")
	Check.near(up, 0, "up")
	Check.eq(planks[1].tilt < math.rad(1), true, "nearly flat")
	Check.near(planks[1].width, 30 + 10 / 60, "width eases from the start", 1e-6)
end)

Check.test("each plank ends where the next starts", function()
	local planks = Bronto.planks(START, SEGMENTS, 5)
	for i = 1, #planks - 1 do
		local endOut, endUp = endOf(planks[i])
		local startOut, startUp = startOf(planks[i + 1])
		Check.near(endOut, startOut, `out after plank {i}`)
		Check.near(endUp, startUp, `up after plank {i}`)
		Check.near(
			planks[i].along + planks[i].length / 2,
			planks[i + 1].along - planks[i + 1].length / 2,
			`along after plank {i}`
		)
	end
end)

Check.test("the path is as long as its segments and ends at the last angle and size", function()
	local planks = Bronto.planks(START, SEGMENTS, 5)
	local last = planks[#planks]
	Check.near(last.along + last.length / 2, 1036, "length")
	Check.near(math.deg(last.tilt), 40, "angle")
	Check.near(last.width, 36 - 4 / 16, "width", 1e-6)
	Check.near(last.depth, 20 + 2 / 16, "depth", 1e-6)
end)

Check.test("neighbouring planks never fold more than the sharpest segment's turn per plank", function()
	-- The neck turns 36 degrees over 60 planks.
	local planks = Bronto.planks(START, SEGMENTS, 5)
	for i = 1, #planks - 1 do
		local fold = math.abs(math.deg(planks[i + 1].tilt - planks[i].tilt))
		Check.eq(fold <= 0.6 + 1e-9, true, `fold of {fold} degrees after plank {i}`)
	end
end)

Check.test("the path only ever climbs", function()
	local planks = Bronto.planks(START, SEGMENTS, 5)
	for i = 1, #planks - 1 do
		Check.eq(planks[i + 1].up > planks[i].up, true, `plank {i + 1} is higher`)
		Check.eq(planks[i + 1].out > planks[i].out, true, `plank {i + 1} is farther out`)
	end
end)

Check.test("where the climb eases off, it bends no tighter than the segment allows", function()
	-- Over the hips, 11 degrees over 150 studs: a crest radius of about 781.
	local planks = Bronto.planks(START, SEGMENTS, 5)
	for i = 1, #planks - 1 do
		local turn = planks[i].tilt - planks[i + 1].tilt
		if turn > 0 then
			local radius = planks[i].length / turn
			Check.eq(radius >= 150 / math.rad(11) - 1e-6, true, `crest radius {radius} after plank {i}`)
		end
	end
end)

Check.test("plankAt finds the plank a point lies on, and the end ones past either end", function()
	local planks = Bronto.planks(START, SEGMENTS, 5)
	Check.eq(Bronto.plankAt(planks, 0), planks[1], "tip")
	Check.eq(Bronto.plankAt(planks, 7), planks[2], "inside the second")
	Check.eq(Bronto.plankAt(planks, 400), planks[80], "end of a plank")
	Check.eq(Bronto.plankAt(planks, -10), planks[1], "before the tip")
	Check.eq(Bronto.plankAt(planks, 2000), planks[#planks], "past the head")
end)

Check.test("pointAt follows the planks", function()
	local planks = Bronto.planks(START, SEGMENTS, 5)
	local out, up = Bronto.pointAt(planks, 0)
	Check.near(out, 0, "tip out")
	Check.near(up, 0, "tip up")
	local p = planks[100]
	local midOut, midUp, tilt = Bronto.pointAt(planks, p.along)
	Check.near(midOut, p.out, "mid out")
	Check.near(midUp, p.up, "mid up")
	Check.near(tilt, p.tilt, "mid tilt")
	local last = planks[#planks]
	local endOut, endUp = Bronto.pointAt(planks, 1036)
	local lastOut, lastUp = endOf(last)
	Check.near(endOut, lastOut, "end out")
	Check.near(endUp, lastUp, "end up")
end)

Check.finish("Bronto")
