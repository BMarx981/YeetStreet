--!strict
-- Roofs (ModuleScript) -> ReplicatedStorage.Roofs
-- What goes on Downtown's roofs. Pure, see InputAxes.
--
-- Every roof gets a lip along each edge: a low ramp rising LipHeight over
-- LipLength to the edge, so a car driven off the roof hops up and out. A lip
-- breaks around anything already standing within its strip, and a scrap
-- shorter than LipLength left by a break is dropped.
--
-- Each roof also gets one kind (a pool, a garden, a water tower and so on),
-- picked by Weight from the kinds whose footprint fits on it. A footprint
-- is Width along x and Depth along z, or turned the other way, and goes as
-- near the roof's middle as it fits inside the lips' strips, Clearance clear
-- of them and of anything busy on the roof. A kind with no Width needs no
-- room and gets no spot. If nothing fits, the roof is Plain.
--
-- Coordinates are the park's: x and z on the ground.

local Roofs = {}

export type Rect = {
	x1: number,
	x2: number, -- more than x1
	z1: number,
	z2: number, -- more than z1
}

export type Roof = {
	x1: number,
	x2: number,
	z1: number,
	z2: number,
	height: number,
	busy: { Rect }, -- what already stands on the roof, such as a crane's mast
}

export type Kind = {
	Name: string,
	Weight: number,
	Width: number,
	Depth: number,
}

export type Tuning = {
	LipHeight: number,
	LipLength: number,
	Clearance: number, -- between a footprint and the lips or anything busy, and round a lip's break
	Step: number, -- between the spots tried for a footprint
	Kinds: { Kind },
}

-- A lip along a roof's edge from (x1, z1) to (x2, z2), rising toward the
-- edge, which faces out along (outX, outZ).
export type Lip = {
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	outX: number,
	outZ: number,
}

export type Plan = {
	roof: Roof,
	lips: { Lip },
	kind: string,
	spot: Rect?, -- the kind's footprint, if it has one
}

-- An Rng from the shared Rng module (Rng.new).
export type Rng = {
	next: () -> number,
}

local PLAIN = "Plain"

local function overlaps(a: Rect, b: Rect): boolean
	return a.x1 < b.x2 and b.x1 < a.x2 and a.z1 < b.z2 and b.z1 < a.z2
end

local function grown(rect: Rect, by: number): Rect
	return { x1 = rect.x1 - by, x2 = rect.x2 + by, z1 = rect.z1 - by, z2 = rect.z2 + by }
end

-- The lips along a roof's four edges, each broken where something busy
-- stands within its strip.
local function lips(roof: Roof, tuning: Tuning): { Lip }
	local reach = tuning.LipLength + tuning.Clearance
	-- Each edge: where it runs (fixed is x or z), the strip it covers, and
	-- the way it faces out.
	local edges = {
		{ alongX = true, fixed = roof.z1, strip = { roof.z1, roof.z1 + reach }, outX = 0, outZ = -1 },
		{ alongX = false, fixed = roof.x2, strip = { roof.x2 - reach, roof.x2 }, outX = 1, outZ = 0 },
		{ alongX = true, fixed = roof.z2, strip = { roof.z2 - reach, roof.z2 }, outX = 0, outZ = 1 },
		{ alongX = false, fixed = roof.x1, strip = { roof.x1, roof.x1 + reach }, outX = -1, outZ = 0 },
	}
	local result: { Lip } = {}
	for _, edge in edges do
		local from = if edge.alongX then roof.x1 else roof.z1
		local to = if edge.alongX then roof.x2 else roof.z2
		local stretches = { { from, to } }
		for _, busy in roof.busy do
			local across1 = if edge.alongX then busy.z1 else busy.x1
			local across2 = if edge.alongX then busy.z2 else busy.x2
			if across1 < edge.strip[2] and across2 > edge.strip[1] then
				local a = (if edge.alongX then busy.x1 else busy.z1) - tuning.Clearance
				local b = (if edge.alongX then busy.x2 else busy.z2) + tuning.Clearance
				local kept = {}
				for _, stretch in stretches do
					if a > stretch[1] then
						table.insert(kept, { stretch[1], math.min(a, stretch[2]) })
					end
					if b < stretch[2] then
						table.insert(kept, { math.max(b, stretch[1]), stretch[2] })
					end
				end
				stretches = kept
			end
		end
		for _, stretch in stretches do
			if stretch[2] - stretch[1] >= tuning.LipLength then
				if edge.alongX then
					table.insert(result, {
						x1 = stretch[1],
						z1 = edge.fixed,
						x2 = stretch[2],
						z2 = edge.fixed,
						outX = edge.outX,
						outZ = edge.outZ,
					})
				else
					table.insert(result, {
						x1 = edge.fixed,
						z1 = stretch[1],
						x2 = edge.fixed,
						z2 = stretch[2],
						outX = edge.outX,
						outZ = edge.outZ,
					})
				end
			end
		end
	end
	return result
end

-- The spots tried for a footprint's middle along one axis, from `low` to
-- `high`: out from `middle` a Step at a time, and both ends.
local function candidates(low: number, high: number, middle: number, step: number): { number }
	if high < low then
		return {}
	end
	local result = { math.clamp(middle, low, high) }
	local offset = step
	while middle - offset >= low or middle + offset <= high do
		if middle - offset >= low then
			table.insert(result, middle - offset)
		end
		if middle + offset <= high then
			table.insert(result, middle + offset)
		end
		offset += step
	end
	table.insert(result, low)
	table.insert(result, high)
	return result
end

-- Where a footprint Width by Depth goes on the roof, or nil if it fits
-- nowhere: the spot nearest the middle, either way round, preferring it
-- unturned.
local function place(roof: Roof, kind: Kind, tuning: Tuning): Rect?
	local inset = tuning.LipLength + tuning.Clearance
	local middleX, middleZ = (roof.x1 + roof.x2) / 2, (roof.z1 + roof.z2) / 2
	local blocked = {}
	for _, busy in roof.busy do
		table.insert(blocked, grown(busy, tuning.Clearance))
	end
	local best: Rect? = nil
	local bestDistance = math.huge
	for _, size in { { kind.Width, kind.Depth }, { kind.Depth, kind.Width } } do
		local halfX, halfZ = size[1] / 2, size[2] / 2
		local xs = candidates(roof.x1 + inset + halfX, roof.x2 - inset - halfX, middleX, tuning.Step)
		local zs = candidates(roof.z1 + inset + halfZ, roof.z2 - inset - halfZ, middleZ, tuning.Step)
		for _, x in xs do
			for _, z in zs do
				local distance = (x - middleX) ^ 2 + (z - middleZ) ^ 2
				if distance < bestDistance then
					local spot = { x1 = x - halfX, x2 = x + halfX, z1 = z - halfZ, z2 = z + halfZ }
					local clear = true
					for _, rect in blocked do
						if overlaps(spot, rect) then
							clear = false
							break
						end
					end
					if clear then
						best, bestDistance = spot, distance
					end
				end
			end
		end
	end
	return best
end

-- The plan for each roof, in the order given. The Rng picks the kinds, one
-- number a roof, so the same roofs, tuning and seed give the same plans.
function Roofs.plan(roofs: { Roof }, tuning: Tuning, rng: Rng): { Plan }
	local plans: { Plan } = {}
	for _, roof in roofs do
		local fits: { { kind: Kind, spot: Rect? } } = {}
		local total = 0
		for _, kind in tuning.Kinds do
			if kind.Weight > 0 then
				local spot = if kind.Width > 0 then place(roof, kind, tuning) else nil
				if kind.Width <= 0 or spot then
					table.insert(fits, { kind = kind, spot = spot })
					total += kind.Weight
				end
			end
		end
		local pick = rng.next() * total
		local chosen: { kind: Kind, spot: Rect? }? = nil
		for _, fit in fits do
			pick -= fit.kind.Weight
			if pick < 0 then
				chosen = fit
				break
			end
		end
		chosen = chosen or fits[#fits]
		table.insert(plans, {
			roof = roof,
			lips = lips(roof, tuning),
			kind = if chosen then chosen.kind.Name else PLAIN,
			spot = if chosen then chosen.spot else nil,
		})
	end
	return plans
end

return Roofs
