--!strict
local Check = require("./Check")
local Corkscrew = require("../src/shared/Corkscrew")

-- Where a plank starts and ends, as (along, angle), from its middle.
local function startOf(plank: Corkscrew.Plank, pitch: number): (number, number)
	return plank.along - plank.step * pitch / (4 * math.pi), plank.angle - plank.step / 2
end

local function endOf(plank: Corkscrew.Plank, pitch: number): (number, number)
	return plank.along + plank.step * pitch / (4 * math.pi), plank.angle + plank.step / 2
end

Check.test("stepsPerLoop planks for each loop, and enough more for the exit", function()
	Check.eq(#Corkscrew.planks(50, 130, 2, 32, 0), 64)
	Check.eq(#Corkscrew.planks(50, 130, 2, 32, 45), 68, "45 degrees is 4 more of 11.25")
	Check.eq(#Corkscrew.planks(50, 130, 2, 32, 40), 68, "a part step rounds up")
end)

Check.test("the track starts at the bottom and ends exitAngle past the last loop", function()
	local pitch = 130
	local planks = Corkscrew.planks(50, pitch, 3, 24, 45)
	local along, angle = startOf(planks[1], pitch)
	Check.near(along, 0, "starts at the axis start")
	Check.near(angle, 0, "starts at the bottom")
	along, angle = endOf(planks[#planks], pitch)
	Check.near(angle, 3 * 2 * math.pi + math.rad(45), "ends past the last loop")
	Check.near(along, pitch * (3 + 45 / 360), "one pitch along per loop")
end)

Check.test("each plank ends where the next starts", function()
	local pitch = 130
	local planks = Corkscrew.planks(50, pitch, 2, 16, 30)
	for i = 1, #planks - 1 do
		local endAlong, endAngle = endOf(planks[i], pitch)
		local startAlong, startAngle = startOf(planks[i + 1], pitch)
		Check.near(endAlong, startAlong, `along after plank {i}`)
		Check.near(endAngle, startAngle, `angle after plank {i}`)
	end
end)

Check.test("a plank is the chord of its slice of the helix", function()
	local radius, pitch = 50, 130
	local plank = Corkscrew.planks(radius, pitch, 1, 32, 0)[1]
	local step = 2 * math.pi / 32
	local around = 2 * radius * math.sin(step / 2)
	local along = pitch / 32
	Check.near(plank.step, step, "step")
	Check.near(plank.length, math.sqrt(around ^ 2 + along ^ 2), "length")
	Check.near(plank.slope, math.atan2(along, around), "slope")
	Check.near(plank.inset, radius * (1 - math.cos(step / 2)), "the chord's middle sits inside the circle")
end)

Check.test("with no pitch it is a flat ring", function()
	local planks = Corkscrew.planks(40, 0, 1, 12, 0)
	Check.near(planks[1].slope, 0, "no slope")
	Check.near(planks[12].along, 0, "never moves along")
end)

Check.test("the track starts where the bottom of a loop just touches the ground", function()
	-- A rise of 3 over a run of 4 climbs 3 for every 5 along, and a loop
	-- square to that axis reaches 4/5 of its radius below it.
	local along = Corkscrew.entry(30, 300, 400)
	Check.near(along * 3 / 5, 30 * 4 / 5)
end)

Check.finish("Corkscrew")
