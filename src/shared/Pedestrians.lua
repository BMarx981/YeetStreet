--!strict
-- Pedestrians (ModuleScript) -> ReplicatedStorage.Pedestrians
-- Downtown's walkers: where they walk. Pure, see InputAxes. Every walker
-- goes round a loop at its speed from the server's clock, so every machine
-- has it in the same place without sending anything.
--
-- Downtown has no raised sidewalk: the Setback strip in front of each
-- building is the curve at its foot. Walkers keep to the bottom of it, a
-- Lane in from the road's edge, and only step into the road to cross at a
-- corner, CornerIn along from the very corner, clear of the pillars
-- standing in the middle of some roads there. The loops stay off the
-- park's outer edge, where the railway runs.
--
--   street loop  round a cross street on one side of the avenue: along its
--                north curb from the avenue corner out to the FarAlley-th
--                alley from the avenue, across, back along the south curb,
--                and across at the avenue corner
--   avenue loop  round the avenue beside one of AvenueBlocks: down one
--                side, across at the block's bottom corner, up the other
--                side, and across at its top corner
--
-- Each loop is walked in every one of Lanes, a lane each way round, so
-- walkers going opposite ways pass beside each other. Every walker on a
-- loop's lane walks at the same speed, so none walks through another.
--
-- Points are in park coordinates: X across the avenue, Z along it, the way
-- the arrival faces is -Z.

local Pedestrians = {}

-- The parts of Tuning.City the loops are laid out from.
export type Layout = {
	AvenueWidth: number,
	StreetWidth: number,
	StreetZ: { number }, -- each cross street's middle
	TopZ: number, -- the first block's top edge
	Setback: number,
	Lot: number,
	Alley: number,
}

export type Tuning = {
	Lanes: { number }, -- in from the road's edge, one per way round
	FarAlley: number, -- street loops cross back at this alley out from the avenue
	CornerIn: number, -- crossings at the avenue's corners are this far along from them
	AvenueBlocks: { number }, -- blocks, counted from the arrival, with an avenue loop
	Count: number, -- walkers in all
	Seed: number,
	MinSpeed: number, -- studs per second
	MaxSpeed: number,
}

-- A straight stretch of a loop. A crossing is on the road from `curb`
-- along it to `curb` before its end.
export type Leg = {
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	length: number,
	start: number, -- along the loop
	curb: number?, -- set on a crossing
}

export type Route = {
	legs: { Leg },
	length: number,
}

export type Walker = {
	route: number,
	offset: number, -- along its loop at time 0
	speed: number,
}

export type Pose = {
	x: number,
	z: number,
	headingX: number, -- a unit, level
	headingZ: number,
	road: boolean, -- out in the road, crossing
	toCurb: number, -- crossing, 1 if the nearer curb is ahead, -1 if behind; 0 off the road
}

-- Same as Rng.Rng, declared here so this module needs no require.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

type Corner = { x: number, z: number, crossing: boolean }

-- A closed loop through the corners in order, or the other way round. A
-- corner's `crossing` says the leg from it to the next corner crosses a
-- road.
local function loop(corners: { Corner }, curb: number, reverse: boolean): Route
	local order: { Corner } = {}
	for i = 1, #corners do
		if reverse then
			-- Walking back, each leg runs from the next corner to this one.
			local j = #corners - i + 1
			local from, to = corners[j % #corners + 1], corners[j]
			table.insert(order, { x = from.x, z = from.z, crossing = to.crossing })
		else
			table.insert(order, corners[i])
		end
	end
	local legs: { Leg } = {}
	local start = 0
	for i, from in order do
		local to = order[i % #order + 1]
		local length = math.sqrt((to.x - from.x) ^ 2 + (to.z - from.z) ^ 2)
		table.insert(legs, {
			fromX = from.x,
			fromZ = from.z,
			toX = to.x,
			toZ = to.z,
			length = length,
			start = start,
			curb = if from.crossing then curb else nil,
		})
		start += length
	end
	return { legs = legs, length = start }
end

-- Each block's top and bottom edge, from TopZ down, as Tunnel.blocks.
local function blocks(layout: Layout): { { top: number, bottom: number } }
	local list = {}
	local half = layout.StreetWidth / 2
	local top = layout.TopZ
	for _, z in layout.StreetZ do
		if top > z + half then
			table.insert(list, { top = top, bottom = z + half })
		end
		top = z - half
	end
	return list
end

-- Every loop in every lane: street loops street by street, west side then
-- east, then avenue loops; each loop's lanes one after another.
function Pedestrians.routes(layout: Layout, tuning: Tuning): { Route }
	local routes: { Route } = {}
	local avenue, street = layout.AvenueWidth / 2, layout.StreetWidth / 2
	local n = tuning.FarAlley
	local alley = avenue + layout.Setback + n * layout.Lot + (n - 0.5) * layout.Alley
	local first = tuning.Lanes[1]
	for _, middle in layout.StreetZ do
		for _, side in { -1, 1 } do
			for i, lane in tuning.Lanes do
				local near, far = side * (avenue + tuning.CornerIn + lane), side * (alley + lane - first)
				local north, south = middle + street + lane, middle - street - lane
				local corners: { Corner } = {
					{ x = near, z = north, crossing = false },
					{ x = far, z = north, crossing = true },
					{ x = far, z = south, crossing = false },
					{ x = near, z = south, crossing = true },
				}
				table.insert(routes, loop(corners, lane, i % 2 == 0))
			end
		end
	end
	local list = blocks(layout)
	for _, index in tuning.AvenueBlocks do
		local b = list[index]
		if b then
			for i, lane in tuning.Lanes do
				local x = avenue + lane
				local inset = tuning.CornerIn + lane
				local top, bottom = b.top - inset, b.bottom + inset
				local corners: { Corner } = {
					{ x = x, z = top, crossing = false },
					{ x = x, z = bottom, crossing = true },
					{ x = -x, z = bottom, crossing = false },
					{ x = -x, z = top, crossing = true },
				}
				table.insert(routes, loop(corners, lane, i % 2 == 0))
			end
		end
	end
	return routes
end

-- Count walkers spread evenly along all the loops end to end, each nudged
-- on a little, so longer loops get more. Every walker on a loop shares the
-- loop's speed.
function Pedestrians.walkers(routes: { Route }, tuning: Tuning, rng: Rng): { Walker }
	local speeds: { number } = {}
	local total = 0
	for i, route in routes do
		speeds[i] = rng.range(tuning.MinSpeed, tuning.MaxSpeed)
		total += route.length
	end
	local spacing = total / tuning.Count
	local walkers: { Walker } = {}
	local index, before = 1, 0 -- the loop at `along`, and the length of the loops ahead of it
	for i = 0, tuning.Count - 1 do
		local along = (i + rng.range(0, 0.5)) * spacing
		while along >= before + routes[index].length and index < #routes do
			before += routes[index].length
			index += 1
		end
		local offset = math.min(along - before, routes[index].length - 1e-6)
		table.insert(walkers, { route = index, offset = offset, speed = speeds[index] })
	end
	return walkers
end

-- Where a walker is at `distance` along its loop, any number of laps on.
function Pedestrians.pose(route: Route, distance: number): Pose
	local d = distance % route.length
	local leg = route.legs[#route.legs]
	for _, candidate in route.legs do
		if d < candidate.start + candidate.length then
			leg = candidate
			break
		end
	end
	local along = d - leg.start
	local headingX, headingZ = (leg.toX - leg.fromX) / leg.length, (leg.toZ - leg.fromZ) / leg.length
	local curb = leg.curb
	local road = curb ~= nil and along > curb and along < leg.length - curb
	return {
		x = leg.fromX + headingX * along,
		z = leg.fromZ + headingZ * along,
		headingX = headingX,
		headingZ = headingZ,
		road = road,
		toCurb = if not road then 0 elseif along * 2 > leg.length then 1 else -1,
	}
end

-- How far round its loop a walker is at `time` on the server's clock.
function Pedestrians.distance(walker: Walker, route: Route, time: number): number
	return (walker.offset + walker.speed * time) % route.length
end

function Pedestrians.at(walker: Walker, route: Route, time: number): Pose
	return Pedestrians.pose(route, Pedestrians.distance(walker, route, time))
end

return Pedestrians
