--!strict
local Check = require("./Check")
local Junk = require("../src/shared/Junk")
local Rng = require("../src/shared/Rng")

local MOUND: Junk.Mound = {
	RadiusAcross = 40,
	RadiusAlong = 60,
	Height = 18,
	Pieces = 200,
	Sectors = 6,
	Kinds = { "Car", "Tire", "Drum" },
}

Check.test("a mound has its pieces, the same for the same seed", function()
	local a, b = Junk.mound(MOUND, Rng.new(3)), Junk.mound(MOUND, Rng.new(3))
	Check.eq(#a, 200)
	for i, piece in a do
		Check.eq(piece.x, b[i].x)
		Check.eq(piece.kind, b[i].kind)
	end
end)

Check.test("every piece lies inside the mound, lower toward its edge", function()
	for i, piece in Junk.mound(MOUND, Rng.new(3)) do
		local r2 = (piece.x / 40) ^ 2 + (piece.z / 60) ^ 2
		Check.eq(r2 <= 1 + 1e-9, true, `piece {i} inside the footprint`)
		Check.eq(piece.y >= 0 and piece.y <= 18 * (1 - r2) + 1e-9, true, `piece {i} under the mound's surface`)
	end
end)

Check.test("the pieces fall into every sector, by their angle round the middle", function()
	local seen = {}
	for _, piece in Junk.mound(MOUND, Rng.new(3)) do
		Check.eq(piece.sector >= 1 and piece.sector <= 6, true)
		seen[piece.sector] = true
	end
	for sector = 1, 6 do
		Check.eq(seen[sector], true, `sector {sector}`)
	end
end)

Check.test("every kind is used", function()
	local seen = {}
	for _, piece in Junk.mound(MOUND, Rng.new(3)) do
		seen[piece.kind] = true
	end
	Check.eq(seen.Car and seen.Tire and seen.Drum, true)
end)

Check.test("a flank slopes from the ramp's edge down to the ground", function()
	-- A ramp 400 long rising 100, with flanks 60 wide at the top.
	Check.near(Junk.flankHeight(200, 0, 400, 60, 100) :: number, 50, "at the ramp's edge, halfway up")
	Check.near(Junk.flankHeight(200, 30, 400, 60, 100) :: number, 0, "at its foot, halfway up")
	Check.near(Junk.flankHeight(400, 30, 400, 60, 100) :: number, 50, "halfway out at the top")
	Check.eq(Junk.flankHeight(200, 31, 400, 60, 100), nil, "past its foot")
	Check.eq(Junk.flankHeight(401, 0, 400, 60, 100), nil, "past the top")
end)

Check.test("pieces on a flank lie on its surface", function()
	for _, piece in Junk.onFlank(MOUND.Kinds, Rng.new(5), 50, 400, 60, 100) do
		Check.near(piece.y, Junk.flankHeight(piece.z, piece.x, 400, 60, 100) :: number)
	end
end)

Check.test("junk on a slope lies on it, clear of its top", function()
	local pieces = Junk.onSlope({ "Car", "Tire" }, Rng.new(5), 30, 40, 120, 90, 30)
	Check.eq(#pieces, 30)
	for i, piece in pieces do
		Check.eq(math.abs(piece.x) <= 20, true, `piece {i} across`)
		Check.eq(piece.z >= 30 and piece.z <= 120, true, `piece {i} along`)
		Check.near(piece.y, 90 * (1 - piece.z / 120), `piece {i} on the surface`)
	end
end)

local STACK: Junk.Stack = { MinCars = 3, MaxCars = 6, CarHeight = 2.5, Wobble = 1, Turn = 15 }

Check.test("a stack is a few crushed cars, one on another", function()
	local counts = {}
	for seed = 1, 40 do
		local cars = Junk.stack(STACK, Rng.new(seed))
		Check.eq(#cars >= 3 and #cars <= 6, true, `seed {seed} car count`)
		counts[#cars] = true
		for i, car in cars do
			Check.eq(car.kind, "Car")
			Check.near(car.y, (i - 1) * 2.5, `seed {seed} car {i} height`)
			Check.eq(car.tilt, 0, "lying flat")
		end
	end
	Check.eq(counts[3] and counts[6], true, "both the fewest and the most turn up")
end)

Check.test("each car sits a little off the one below, turned a little from the stack", function()
	for seed = 1, 40 do
		local cars = Junk.stack(STACK, Rng.new(seed))
		local base = cars[1].yaw
		for i, car in cars do
			Check.eq(math.abs(car.x) <= 1 and math.abs(car.z) <= 1, true, `seed {seed} car {i} wobble`)
			Check.eq(math.abs(car.yaw - base) <= 15 + 1e-9, true, `seed {seed} car {i} turn`)
		end
	end
end)

Check.finish("Junk")
