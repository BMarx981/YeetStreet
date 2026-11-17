--!strict
-- FootCurve (ModuleScript) -> ReplicatedStorage.FootCurve
-- A curve along the foot of a ramp's side, like the one round a downtown
-- building's foot, so a car driving into the side rides up it instead of
-- hitting a sharp wall. A ramp's side is not level, so the curve is laid in
-- pieces, each cut off no higher than the side above it. Pure, see
-- InputAxes.
--
-- Distances run along the side; heights are above the ground.

local FootCurve = {}

-- A stretch of the side's top edge, straight from one height to the other.
export type Segment = {
	from: number,
	to: number,
	fromHeight: number,
	toHeight: number,
}

-- A straight run of curve as high as `height`.
export type Piece = {
	from: number,
	to: number,
	height: number,
}

-- The top edge of a curved wall's side, the wall's base line `base` along
-- and rising toward greater distances (`direction` 1) or smaller (-1): a
-- segment per plank, sorted by distance. Past vertical the wall leans back
-- over itself, so only the curve up to vertical counts. Its corners are
-- CurveProfile's.
function FootCurve.curve(base: number, direction: number, radius: number, endAngle: number, steps: number): { Segment }
	local finish = math.rad(math.min(endAngle, 90))
	local segments: { Segment } = {}
	for i = 1, steps do
		local a, b = finish * (i - 1) / steps, finish * i / steps
		table.insert(segments, {
			from = base + direction * radius * math.sin(a),
			to = base + direction * radius * math.sin(b),
			fromHeight = radius * (1 - math.cos(a)),
			toHeight = radius * (1 - math.cos(b)),
		})
	end
	if direction < 0 then
		local sorted: { Segment } = {}
		for i = #segments, 1, -1 do
			local s = segments[i]
			table.insert(sorted, { from = s.to, to = s.from, fromHeight = s.toHeight, toHeight = s.fromHeight })
		end
		return sorted
	end
	return segments
end

-- The pieces of curve along a side whose top edge is `segments`, sorted by
-- distance. Each piece is as high as the lowest the side gets above it, so
-- it never stands up past the side's top, but no higher than `top`, the
-- whole curve's height. A sloping segment is cut into pieces each rising at
-- most `maxRise` past the last; neighbors of the same height join into one;
-- pieces lower than `minHeight` are left out.
function FootCurve.pieces(segments: { Segment }, top: number, maxRise: number, minHeight: number): { Piece }
	local pieces: { Piece } = {}
	local function add(from: number, to: number, height: number)
		height = math.min(height, top)
		if height < minHeight then
			return
		end
		local last = pieces[#pieces]
		if last and math.abs(last.to - from) < 1e-6 and math.abs(last.height - height) < 1e-6 then
			last.to = to
		else
			table.insert(pieces, { from = from, to = to, height = height })
		end
	end
	for _, s in segments do
		local rise = math.abs(math.min(s.toHeight, top) - math.min(s.fromHeight, top))
		local count = math.max(1, math.ceil(rise / maxRise - 1e-9))
		for i = 1, count do
			local a, b = (i - 1) / count, i / count
			local low =
				math.min(s.fromHeight + (s.toHeight - s.fromHeight) * a, s.fromHeight + (s.toHeight - s.fromHeight) * b)
			add(s.from + (s.to - s.from) * a, s.from + (s.to - s.from) * b, low)
		end
	end
	return pieces
end

return FootCurve
