--!strict
local Check = require("./Check")
local Dressing = require("../src/shared/Dressing")
local Rng = require("../src/shared/Rng")

local CONFIG: Dressing.Config = {
	HalfX = 500,
	HalfZ = 600,
	SpanX = 400,
	SpanZ = 500,
	Every = 50,
	Jitter = 8,
	LightEvery = 300,
	LightClear = 20,
	KeepOut = { { AX = -600, AZ = 0, BX = -400, BZ = 0, Radius = 100 } },
	Kinds = { { Kind = "Tires", Weight = 2 }, { Kind = "Drums", Weight = 2 }, { Kind = "Container", Weight = 1 } },
}

local function sideOf(spot: Dressing.Spot): string
	if math.abs(spot.z - 600) < 1e-6 then
		return "north"
	elseif math.abs(spot.z + 600) < 1e-6 then
		return "south"
	elseif math.abs(spot.x - 500) < 1e-6 then
		return "east"
	elseif math.abs(spot.x + 500) < 1e-6 then
		return "west"
	end
	return "none"
end

Check.test("every spot is on the band along one side, within its straight run", function()
	for i, spot in Dressing.spots(CONFIG, Rng.new(4)) do
		local side = sideOf(spot)
		Check.eq(side ~= "none", true, `spot {i} on a side`)
		if side == "north" or side == "south" then
			Check.eq(math.abs(spot.x) <= 400, true, `spot {i} within the run`)
		else
			Check.eq(math.abs(spot.z) <= 500, true, `spot {i} within the run`)
		end
	end
end)

Check.test("each spot faces into the yard", function()
	local facing = { north = 0, south = 180, east = 90, west = 270 }
	for i, spot in Dressing.spots(CONFIG, Rng.new(4)) do
		Check.near(spot.facing, facing[sideOf(spot)], `spot {i}`)
	end
end)

Check.test("lights stand at even steps along each side, and nothing else crowds them", function()
	local spots = Dressing.spots(CONFIG, Rng.new(4))
	local lights = {}
	for _, spot in spots do
		if spot.kind == "Light" then
			table.insert(lights, spot)
			local along = if math.abs(spot.z) > 590 then spot.x else spot.z
			Check.near(along % 300, 0, "on a step")
		end
	end
	Check.eq(#lights, 11, "-300, 0 and 300 on each side, but 0 on the west side is in the gate")
	for _, spot in spots do
		if spot.kind ~= "Light" then
			for _, light in lights do
				local d = math.sqrt((spot.x - light.x) ^ 2 + (spot.z - light.z) ^ 2)
				Check.eq(d >= 20, true, `a {spot.kind} {math.floor(d)} from a light`)
			end
		end
	end
end)

Check.test("nothing stands in a keep-out", function()
	for _, spot in Dressing.spots(CONFIG, Rng.new(4)) do
		local inGate = spot.x < -400 + 1e-6 and math.abs(spot.z) < 100
		Check.eq(inGate, false, `{spot.kind} at {spot.x}, {spot.z}`)
	end
end)

Check.test("the kinds are picked by weight, the same for the same seed", function()
	local a, b = Dressing.spots(CONFIG, Rng.new(4)), Dressing.spots(CONFIG, Rng.new(4))
	Check.eq(#a, #b)
	local counts: { [string]: number } = {}
	for i, spot in a do
		Check.eq(spot.kind, b[i].kind)
		counts[spot.kind] = (counts[spot.kind] or 0) + 1
	end
	Check.eq((counts.Tires or 0) > (counts.Container or 0), true, "twice the weight, more of them")
	Check.eq((counts.Container or 0) > 0, true, "every kind turns up")
end)

Check.finish("Dressing")
