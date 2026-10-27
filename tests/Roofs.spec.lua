--!strict
local Check = require("./Check")
local Rng = require("../src/shared/Rng")
local Roofs = require("../src/shared/Roofs")

local TUNING: Roofs.Tuning = {
	LipHeight = 3,
	LipLength = 12,
	Clearance = 4,
	Step = 2,
	Kinds = {
		{ Name = "Plain", Weight = 1, Width = 0, Depth = 0 },
		{ Name = "Pool", Weight = 1, Width = 56, Depth = 32 },
		{ Name = "Helipad", Weight = 1, Width = 70, Depth = 70 },
	},
}

local function roof(busy: { Roofs.Rect }?): Roofs.Roof
	return { x1 = 0, x2 = 160, z1 = 0, z2 = 160, height = 100, busy = busy or {} }
end

local function only(name: string): Roofs.Tuning
	local kinds = {}
	for _, kind in TUNING.Kinds do
		table.insert(
			kinds,
			{ Name = kind.Name, Weight = if kind.Name == name then 1 else 0, Width = kind.Width, Depth = kind.Depth }
		)
	end
	local tuning = table.clone(TUNING)
	tuning.Kinds = kinds
	return tuning
end

local function overlaps(a: Roofs.Rect, b: Roofs.Rect): boolean
	return a.x1 < b.x2 and b.x1 < a.x2 and a.z1 < b.z2 and b.z1 < a.z2
end

Check.test("an empty roof gets a lip the whole length of each side, facing out", function()
	local plan = Roofs.plan({ roof() }, TUNING, Rng.new(1))[1]
	Check.eq(#plan.lips, 4)
	local outs = {}
	for _, lip in plan.lips do
		Check.near(math.abs(lip.x2 - lip.x1) + math.abs(lip.z2 - lip.z1), 160, "full side")
		outs[`{lip.outX},{lip.outZ}`] = true
		-- The lip sits on the edge it faces out of.
		if lip.outX ~= 0 then
			Check.eq(lip.x1, if lip.outX > 0 then 160 else 0)
			Check.eq(lip.x2, lip.x1)
		else
			Check.eq(lip.z1, if lip.outZ > 0 then 160 else 0)
			Check.eq(lip.z2, lip.z1)
		end
	end
	for _, out in { "0,-1", "1,0", "0,1", "-1,0" } do
		Check.eq(outs[out], true, out)
	end
end)

Check.test("something standing on the lip's strip cuts that side's lip around it", function()
	-- A mast 8 in from the low-x edge, from z 70 to 80.
	local plan = Roofs.plan({ roof({ { x1 = 8, x2 = 14, z1 = 70, z2 = 80 } }) }, TUNING, Rng.new(1))[1]
	local west = {}
	for _, lip in plan.lips do
		if lip.outX == -1 then
			table.insert(west, lip)
		else
			Check.near(math.abs(lip.x2 - lip.x1) + math.abs(lip.z2 - lip.z1), 160, "other sides whole")
		end
	end
	Check.eq(#west, 2)
	table.sort(west, function(a, b)
		return a.z1 < b.z1
	end)
	Check.near(west[1].z1, 0)
	Check.near(west[1].z2, 66, "stops Clearance short")
	Check.near(west[2].z1, 84, "starts Clearance past")
	Check.near(west[2].z2, 160)
end)

Check.test("something in the middle of the roof leaves the lips whole", function()
	local plan = Roofs.plan({ roof({ { x1 = 70, x2 = 90, z1 = 70, z2 = 90 } }) }, only("Plain"), Rng.new(1))[1]
	Check.eq(#plan.lips, 4)
end)

Check.test("a short scrap of lip left by a cut is dropped", function()
	-- Cuts the low-x side from 0 to 159, leaving a 1 stud scrap.
	local plan = Roofs.plan({ roof({ { x1 = 2, x2 = 8, z1 = 4, z2 = 155 } }) }, only("Plain"), Rng.new(1))[1]
	for _, lip in plan.lips do
		Check.eq(math.abs(lip.x2 - lip.x1) + math.abs(lip.z2 - lip.z1) >= TUNING.LipLength, true, "no scraps")
	end
	Check.eq(#plan.lips, 3)
end)

Check.test("a kind's footprint goes in the middle of an empty roof", function()
	local plan = Roofs.plan({ roof() }, only("Pool"), Rng.new(1))[1]
	Check.eq(plan.kind, "Pool")
	local spot = assert(plan.spot, "a spot")
	Check.near((spot.x1 + spot.x2) / 2, 80)
	Check.near((spot.z1 + spot.z2) / 2, 80)
	Check.near(spot.x2 - spot.x1, 56)
	Check.near(spot.z2 - spot.z1, 32)
end)

Check.test("a footprint moves aside, clear of what stands on the roof and inside the lips", function()
	local mast = { x1 = 100, x2 = 110, z1 = 70, z2 = 90 }
	local plan = Roofs.plan({ roof({ mast }) }, only("Helipad"), Rng.new(1))[1]
	Check.eq(plan.kind, "Helipad")
	local spot = assert(plan.spot, "a spot")
	local grown = { x1 = mast.x1 - 4, x2 = mast.x2 + 4, z1 = mast.z1 - 4, z2 = mast.z2 + 4 }
	Check.eq(overlaps(spot, grown), false, "clear of the mast")
	local inset = TUNING.LipLength + TUNING.Clearance
	Check.eq(spot.x1 >= inset and spot.x2 <= 160 - inset, true, "inside the lips across")
	Check.eq(spot.z1 >= inset and spot.z2 <= 160 - inset, true, "inside the lips along")
end)

Check.test("a footprint turns sideways when only that fits", function()
	-- A strip along z leaves room 40 wide across x, but long along z.
	local busy = { { x1 = 16, x2 = 100, z1 = 0, z2 = 160 } }
	local plan = Roofs.plan({ roof(busy) }, only("Pool"), Rng.new(1))[1]
	Check.eq(plan.kind, "Pool")
	local spot = assert(plan.spot, "a spot")
	Check.near(spot.x2 - spot.x1, 32, "turned")
	Check.near(spot.z2 - spot.z1, 56, "turned")
end)

Check.test("a kind that fits nowhere on a roof is never picked for it", function()
	local small: Roofs.Roof = { x1 = 0, x2 = 80, z1 = 0, z2 = 80, height = 60, busy = {} }
	local roofs = {}
	for _ = 1, 50 do
		table.insert(roofs, table.clone(small))
	end
	for _, plan in Roofs.plan(roofs, TUNING, Rng.new(1)) do
		Check.eq(plan.kind ~= "Helipad", true, "a helipad needs 70 inside the lips")
	end
end)

Check.test("plain roofs have no footprint", function()
	local plan = Roofs.plan({ roof() }, only("Plain"), Rng.new(1))[1]
	Check.eq(plan.kind, "Plain")
	Check.eq(plan.spot, nil)
end)

Check.test("the same seed gives the same kinds, another seed different ones", function()
	local roofs = {}
	for _ = 1, 40 do
		table.insert(roofs, roof())
	end
	local function kinds(seed: number): string
		local names = {}
		for _, plan in Roofs.plan(roofs, TUNING, Rng.new(seed)) do
			table.insert(names, plan.kind)
		end
		return table.concat(names, ",")
	end
	Check.eq(kinds(1), kinds(1))
	Check.eq(kinds(1) ~= kinds(2), true, "another seed")
end)

Check.test("kinds come up about as often as their weights say", function()
	local tuning = table.clone(TUNING)
	tuning.Kinds = {
		{ Name = "Plain", Weight = 7, Width = 0, Depth = 0 },
		{ Name = "Pool", Weight = 1, Width = 56, Depth = 32 },
	}
	local roofs = {}
	for _ = 1, 2000 do
		table.insert(roofs, roof())
	end
	local pools = 0
	for _, plan in Roofs.plan(roofs, tuning, Rng.new(1)) do
		if plan.kind == "Pool" then
			pools += 1
		end
	end
	Check.near(pools / 2000, 1 / 8, "one in eight", 0.03)
end)

local SOLAR: Roofs.Solar = { Height = 3, Run = 9, Back = 5, Gap = 10 }

Check.test("solar rows run along the spot's long side, centered across it", function()
	local rows = Roofs.solarRows({ x1 = 0, x2 = 100, z1 = 0, z2 = 80 }, SOLAR)
	-- Rows 14 deep with 10 between: three take 62 of the 80.
	Check.eq(#rows, 3)
	for i, row in rows do
		Check.near(row.x1, 0, "whole length")
		Check.near(row.x2, 100, "whole length")
		Check.near(row.z1, 9 + (i - 1) * 24, `row {i} starts`)
		Check.near(row.z2 - row.z1, 14, "Run and Back deep")
		Check.eq(row.riseX, 0)
		Check.eq(row.riseZ, -1)
	end
end)

Check.test("a spot longer along z gets rows along z, rising toward -x", function()
	local rows = Roofs.solarRows({ x1 = 10, x2 = 90, z1 = 0, z2 = 100 }, SOLAR)
	Check.eq(#rows, 3)
	for _, row in rows do
		Check.near(row.z1, 0)
		Check.near(row.z2, 100)
		Check.near(row.x2 - row.x1, 14)
		Check.eq(row.riseX, -1)
		Check.eq(row.riseZ, 0)
	end
	Check.near(rows[1].x1, 19, "centered across")
end)

Check.test("a spot too narrow for a row gets none", function()
	Check.eq(#Roofs.solarRows({ x1 = 0, x2 = 100, z1 = 0, z2 = 12 }, SOLAR), 0)
end)

local POOL: Roofs.Pool = { Height = 4, Ramp = 8, Rim = 4, Shallow = 12, Side = 8 }

local function area(rect: Roofs.Rect): number
	return (rect.x2 - rect.x1) * (rect.z2 - rect.z1)
end

Check.test("a pool's deck sits inside its ramps, with the basin inside the deck's rim", function()
	local pool = Roofs.poolLayout({ x1 = 0, x2 = 80, z1 = 0, z2 = 50 }, POOL)
	Check.near(pool.deck.x1, 8)
	Check.near(pool.deck.x2, 72)
	Check.near(pool.deck.z1, 8)
	Check.near(pool.deck.z2, 42)
	Check.near(pool.basin.x1, 12)
	Check.near(pool.basin.x2, 68)
	Check.near(pool.basin.z1, 12)
	Check.near(pool.basin.z2, 38)
	-- The rim's slabs cover the deck but for the basin, without overlapping.
	local covered = 0
	for _, slab in pool.rim do
		covered += area(slab)
		Check.eq(
			slab.x1 < pool.basin.x2 and pool.basin.x1 < slab.x2 and slab.z1 < pool.basin.z2 and pool.basin.z1 < slab.z2,
			false,
			"not over the basin"
		)
	end
	Check.near(covered, area(pool.deck) - area(pool.basin), "the whole rim")
end)

Check.test("every wall of the basin slopes up to the deck: Shallow at the ends, Side along the sides", function()
	for _, spot in { { x1 = 0, x2 = 80, z1 = 0, z2 = 50 }, { x1 = 0, x2 = 50, z1 = 0, z2 = 80 } } do
		local pool = Roofs.poolLayout(spot, POOL)
		local basin = pool.basin
		local alongX = spot.x2 - spot.x1 > spot.z2 - spot.z1
		Check.eq(#pool.slopes, 4)
		local outs = {}
		for _, slope in pool.slopes do
			local rect = slope.rect
			outs[`{slope.riseX},{slope.riseZ}`] = true
			Check.eq(
				rect.x1 >= basin.x1 and rect.x2 <= basin.x2 and rect.z1 >= basin.z1 and rect.z2 <= basin.z2,
				true,
				"inside the basin"
			)
			-- Against the wall it rises toward, the whole length of that wall.
			if slope.riseX ~= 0 then
				Check.near(
					if slope.riseX < 0 then rect.x1 else rect.x2,
					if slope.riseX < 0 then basin.x1 else basin.x2,
					"at its wall"
				)
				Check.near(rect.z2 - rect.z1, basin.z2 - basin.z1, "the wall's length")
				Check.near(rect.x2 - rect.x1, if alongX then POOL.Shallow else POOL.Side, "run")
			else
				Check.near(
					if slope.riseZ < 0 then rect.z1 else rect.z2,
					if slope.riseZ < 0 then basin.z1 else basin.z2,
					"at its wall"
				)
				Check.near(rect.x2 - rect.x1, basin.x2 - basin.x1, "the wall's length")
				Check.near(rect.z2 - rect.z1, if alongX then POOL.Side else POOL.Shallow, "run")
			end
		end
		for _, out in { "-1,0", "1,0", "0,-1", "0,1" } do
			Check.eq(outs[out], true, out)
		end
	end
end)

Check.finish("Roofs")
