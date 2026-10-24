--!strict
local Check = require("./Check")
local Pedestrians = require("../src/shared/Pedestrians")
local Rng = require("../src/shared/Rng")

local LAYOUT: Pedestrians.Layout = {
	AvenueWidth = 160,
	StreetWidth = 100,
	StreetZ = { 1000, 200, -600, -1400 },
	TopZ = 1500,
	Setback = 20,
	Lot = 160,
	Alley = 50,
}

local TUNING: Pedestrians.Tuning = {
	Lanes = { 2, 6 },
	FarAlley = 3,
	CornerIn = 10,
	AvenueBlocks = { 2, 3, 4 },
	Count = 80,
	Seed = 11,
	MinSpeed = 5,
	MaxSpeed = 7,
}

local routes = Pedestrians.routes(LAYOUT, TUNING)

-- Every point along a route, Step apart.
local STEP = 5
local function samples(route: Pedestrians.Route): { Pedestrians.Pose }
	local poses = {}
	local d = 0
	while d < route.length do
		table.insert(poses, Pedestrians.pose(route, d))
		d += STEP
	end
	return poses
end

local function onRoad(x: number, z: number): boolean
	if math.abs(x) < LAYOUT.AvenueWidth / 2 then
		return true
	end
	for _, middle in LAYOUT.StreetZ do
		if math.abs(z - middle) < LAYOUT.StreetWidth / 2 then
			return true
		end
	end
	return false
end

-- How far from the nearest road, 0 on it. Buildings stand Setback back.
local function fromRoad(x: number, z: number): number
	local gap = math.max(0, math.abs(x) - LAYOUT.AvenueWidth / 2)
	for _, middle in LAYOUT.StreetZ do
		gap = math.min(gap, math.max(0, math.abs(z - middle) - LAYOUT.StreetWidth / 2))
	end
	return gap
end

Check.test("a street loop each side of every street and an avenue loop per block, in every lane", function()
	Check.eq(#routes, (#LAYOUT.StreetZ * 2 + #TUNING.AvenueBlocks) * #TUNING.Lanes, "routes")
end)

Check.test("every route is a closed loop", function()
	for i, route in routes do
		local first, last = route.legs[1], route.legs[#route.legs]
		Check.near(last.toX, first.fromX, `route {i} closes in x`)
		Check.near(last.toZ, first.fromZ, `route {i} closes in z`)
		local total = 0
		for j, leg in route.legs do
			Check.near(leg.start, total, `route {i} leg {j} starts where the last ended`)
			Check.near(leg.length, math.sqrt((leg.toX - leg.fromX) ^ 2 + (leg.toZ - leg.fromZ) ^ 2), "leg length")
			total += leg.length
			if j > 1 then
				Check.near(leg.fromX, route.legs[j - 1].toX, "legs join")
				Check.near(leg.fromZ, route.legs[j - 1].toZ, "legs join")
			end
		end
		Check.near(route.length, total, `route {i} length`)
	end
end)

Check.test("a street loop runs a lane in from both curbs and crosses at the avenue corner and the far alley", function()
	local route = routes[1]
	local lane = TUNING.Lanes[1]
	local half = LAYOUT.StreetWidth / 2
	local nearX = LAYOUT.AvenueWidth / 2 + TUNING.CornerIn + lane
	local farX = LAYOUT.AvenueWidth / 2 + LAYOUT.Setback + 3 * LAYOUT.Lot + 2.5 * LAYOUT.Alley
	local xs, zs = {}, {}
	for _, leg in route.legs do
		xs[math.abs(leg.fromX)] = true
		zs[leg.fromZ] = true
	end
	Check.eq(xs[nearX], true, "turns at the avenue corner")
	Check.eq(xs[farX], true, "turns at the far alley")
	Check.eq(zs[1000 + half + lane], true, "the north curb")
	Check.eq(zs[1000 - half - lane], true, "the south curb")
end)

Check.test("an avenue loop crosses CornerIn and a lane in from its block's corners", function()
	local route = routes[#LAYOUT.StreetZ * 2 * #TUNING.Lanes + 1] -- block 2's, the first lane
	local lane = TUNING.Lanes[1]
	local inset = TUNING.CornerIn + lane
	local top, bottom = 1000 - LAYOUT.StreetWidth / 2, 200 + LAYOUT.StreetWidth / 2
	local zs = {}
	for _, leg in route.legs do
		if leg.curb then
			Check.near(leg.fromZ, leg.toZ, "a crossing goes straight across")
			zs[leg.fromZ] = true
		else
			Check.near(math.abs(leg.fromX), LAYOUT.AvenueWidth / 2 + lane, "along the avenue a lane in")
		end
	end
	Check.eq(zs[top - inset], true, "crosses at the top corner")
	Check.eq(zs[bottom + inset], true, "crosses at the bottom corner")
end)

Check.test("walkers are only ever on the road while crossing, and otherwise at the curb", function()
	for i, route in routes do
		local crossed = false
		for _, pose in samples(route) do
			Check.eq(pose.road, onRoad(pose.x, pose.z), `route {i} road flag at ({pose.x}, {pose.z})`)
			assert(fromRoad(pose.x, pose.z) <= TUNING.Lanes[2] + 1e-6, `route {i} off the curb at ({pose.x}, {pose.z})`)
			crossed = crossed or pose.road
		end
		Check.eq(crossed, true, `route {i} crosses a road`)
	end
end)

Check.test("crossing, toCurb says whether the nearer curb is ahead or behind", function()
	for i, route in routes do
		for _, pose in samples(route) do
			if not pose.road then
				Check.eq(pose.toCurb, 0, `route {i} off the road`)
			else
				-- Step toward the curb it names until off the road; the other
				-- way must be at least as far.
				local function stepsOff(sign: number): number
					local x, z, n = pose.x, pose.z, 0
					while onRoad(x, z) do
						x += sign * pose.headingX
						z += sign * pose.headingZ
						n += 1
					end
					return n
				end
				assert(pose.toCurb == 1 or pose.toCurb == -1, `route {i} toCurb on the road`)
				assert(stepsOff(pose.toCurb) <= stepsOff(-pose.toCurb), `route {i} nearer curb at ({pose.x}, {pose.z})`)
			end
		end
	end
end)

Check.test("the two lanes of a loop go opposite ways", function()
	local outer, inner = routes[1], routes[2]
	local a = Pedestrians.pose(outer, 10)
	-- The same stretch of curb, the other lane.
	local best, bestGap = nil, math.huge
	for _, pose in samples(inner) do
		local gap = (pose.x - a.x) ^ 2 + (pose.z - a.z) ^ 2
		if gap < bestGap then
			best, bestGap = pose, gap
		end
	end
	assert(best)
	Check.near(math.sqrt(bestGap), TUNING.Lanes[2] - TUNING.Lanes[1], "a lane apart", STEP)
	Check.near(a.headingX * best.headingX + a.headingZ * best.headingZ, -1, "heading the other way", 1e-6)
end)

Check.test("a pose wraps round the loop and heads along its leg", function()
	local route = routes[1]
	local a = Pedestrians.pose(route, 37)
	local b = Pedestrians.pose(route, 37 + route.length * 3)
	Check.near(b.x, a.x, "x after three laps", 1e-6)
	Check.near(b.z, a.z, "z after three laps", 1e-6)
	local c = Pedestrians.pose(route, 37 - route.length)
	Check.near(c.x, a.x, "x a lap back", 1e-6)
	Check.near(a.headingX ^ 2 + a.headingZ ^ 2, 1, "heading is a unit", 1e-9)
	local leg = route.legs[1]
	local p = Pedestrians.pose(route, 1)
	Check.near(p.headingX, (leg.toX - leg.fromX) / leg.length, "heading along the first leg")
	Check.near(p.headingZ, (leg.toZ - leg.fromZ) / leg.length, "heading along the first leg")
end)

Check.test("walkers: Count of them, the same every time from the seed", function()
	local one = Pedestrians.walkers(routes, TUNING, Rng.new(TUNING.Seed))
	local two = Pedestrians.walkers(routes, TUNING, Rng.new(TUNING.Seed))
	Check.eq(#one, TUNING.Count, "walkers")
	for i, walker in one do
		Check.eq(walker.route, two[i].route, "same route")
		Check.eq(walker.offset, two[i].offset, "same offset")
		Check.eq(walker.speed, two[i].speed, "same speed")
	end
end)

Check.test("every route has walkers, all at one speed in range, spread round it", function()
	local walkers = Pedestrians.walkers(routes, TUNING, Rng.new(TUNING.Seed))
	local byRoute: { [number]: { Pedestrians.Walker } } = {}
	for _, walker in walkers do
		byRoute[walker.route] = byRoute[walker.route] or {}
		table.insert(byRoute[walker.route], walker)
	end
	for i, route in routes do
		local list = byRoute[i]
		assert(list and #list > 0, `route {i} has no walkers`)
		local offsets = {}
		for _, walker in list do
			Check.eq(walker.speed, list[1].speed, `route {i} walkers share a speed`)
			assert(walker.speed >= TUNING.MinSpeed and walker.speed <= TUNING.MaxSpeed, "speed in range")
			assert(walker.offset >= 0 and walker.offset < route.length, "offset on the loop")
			table.insert(offsets, walker.offset)
		end
		table.sort(offsets)
		local spacing = route.length / #offsets
		for j = 2, #offsets do
			assert(offsets[j] - offsets[j - 1] > spacing / 3, `route {i} walkers bunched`)
		end
	end
end)

Check.test("a walker moves along its loop at its speed from the server clock", function()
	local walkers = Pedestrians.walkers(routes, TUNING, Rng.new(TUNING.Seed))
	local walker = walkers[1]
	local route = routes[walker.route]
	local now = 1.7e9 + 0.25
	local d = Pedestrians.distance(walker, route, now)
	assert(d >= 0 and d < route.length, "distance wraps")
	local moved = (Pedestrians.distance(walker, route, now + 0.5) - d) % route.length
	Check.near(moved, walker.speed * 0.5, "distance in half a second", 1e-3)
	local pose, at = Pedestrians.pose(route, d), Pedestrians.at(walker, route, now)
	Check.eq(at.x, pose.x, "at is the pose at that distance")
	Check.eq(at.z, pose.z, "at is the pose at that distance")
end)

Check.test("the layout comes from the city's own numbers", function()
	local layout = Pedestrians.layout({
		Avenue = { Width = 160 },
		Streets = { Width = 100, Z = LAYOUT.StreetZ },
		Buildings = { TopZ = 1500, Setback = 20, Lot = 160, Alley = 50 },
	})
	for key, value in LAYOUT do
		Check.eq((layout :: any)[key], value, key)
	end
end)

Check.finish("Pedestrians")
