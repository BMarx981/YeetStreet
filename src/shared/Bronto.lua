--!strict
-- Bronto (ModuleScript) -> ReplicatedStorage.Bronto
-- The ride up a brontosaurus: one path from the tip of its tail on the
-- ground, over its back and up its neck to the top of its head, built from
-- straight planks. The path is a list of segments. Over each one the climb
-- angle eases evenly from where the last segment left it to the segment's
-- Angle, and the width and the depth of the body under the path ease the
-- same way, so neighbouring planks only ever fold a little. Pure, see
-- InputAxes.
--
-- Path coordinates: `along` is studs along the path from the tail tip, `out`
-- is studs along the ground from the tail tip, `up` is studs above the ground.

local Bronto = {}

export type Start = {
	Width: number,
	Depth: number,
}

export type Segment = {
	Length: number, -- along the path
	Angle: number, -- degrees above flat at the segment's end
	Width: number, -- at the segment's end
	Depth: number, -- of the body under the path, at the segment's end
}

export type Plank = {
	along: number, -- midpoint
	out: number, -- midpoint
	up: number, -- midpoint
	length: number,
	tilt: number, -- radians above flat
	width: number,
	depth: number,
}

-- Each segment in planks of at most `step` studs, all the same length.
function Bronto.planks(start: Start, segments: { Segment }, step: number): { Plank }
	local planks: { Plank } = {}
	local along, out, up = 0, 0, 0
	local angle, width, depth = 0, start.Width, start.Depth
	for _, segment in segments do
		local count = math.ceil(segment.Length / step)
		local length = segment.Length / count
		local endAngle = math.rad(segment.Angle)
		for i = 1, count do
			local t = (i - 0.5) / count
			local tilt = angle + (endAngle - angle) * t
			local dOut, dUp = length * math.cos(tilt), length * math.sin(tilt)
			table.insert(planks, {
				along = along + length / 2,
				out = out + dOut / 2,
				up = up + dUp / 2,
				length = length,
				tilt = tilt,
				width = width + (segment.Width - width) * t,
				depth = depth + (segment.Depth - depth) * t,
			})
			along += length
			out += dOut
			up += dUp
		end
		angle, width, depth = endAngle, segment.Width, segment.Depth
	end
	return planks
end

export type Section = {
	along: number,
	out: number,
	up: number,
	tilt: number, -- radians above flat, halfway between the planks either side
	width: number,
}

-- Where each plank ends and the next starts, from the tail tip to the head:
-- the lines a rounded back's sides are built between.
function Bronto.sections(planks: { Plank }): { Section }
	local first = planks[1]
	local sections: { Section } = {
		{
			along = 0,
			out = first.out - first.length / 2 * math.cos(first.tilt),
			up = first.up - first.length / 2 * math.sin(first.tilt),
			tilt = first.tilt,
			width = first.width,
		},
	}
	for i, p in planks do
		local nextPlank = planks[i + 1] or p
		table.insert(sections, {
			along = p.along + p.length / 2,
			out = p.out + p.length / 2 * math.cos(p.tilt),
			up = p.up + p.length / 2 * math.sin(p.tilt),
			tilt = (p.tilt + nextPlank.tilt) / 2,
			width = (p.width + nextPlank.width) / 2,
		})
	end
	return sections
end

export type CrownPoint = {
	x: number, -- studs out from the middle of the path
	y: number, -- studs above the flat middle
}

-- One side of a rounded back's cross section, `width` across: flat over the
-- middle `flat` of it, then rolling down over `strips` strips to `drop` times
-- the width below at the outer edge. Its slope starts flat and grows evenly,
-- so the roll has no fold at the middle's edge. The other side mirrors it.
-- A negative drop curls the edge up instead, into a lip.
function Bronto.crown(width: number, flat: number, drop: number, strips: number): { CrownPoint }
	local inner = width * flat / 2
	local shoulder = width / 2 - inner
	local points: { CrownPoint } = {}
	for i = 0, strips do
		local u = i / strips
		table.insert(points, { x = inner + shoulder * u, y = -drop * width * u * u })
	end
	return points
end

-- How wide the rounded back of `Bronto.crown` is down to `below` studs under
-- its flat middle.
function Bronto.crownWidth(width: number, flat: number, drop: number, below: number): number
	local u = math.min(math.sqrt(below / (drop * width)), 1)
	return width * flat + width * (1 - flat) * u
end

-- How far along the path it first reaches `up` studs above the ground, or
-- its end if it never does.
function Bronto.alongAt(planks: { Plank }, up: number): number
	for _, p in planks do
		local startUp = p.up - p.length / 2 * math.sin(p.tilt)
		local endUp = p.up + p.length / 2 * math.sin(p.tilt)
		if up <= startUp then
			return p.along - p.length / 2
		elseif up <= endUp then
			return p.along - p.length / 2 + (up - startUp) / math.sin(p.tilt)
		end
	end
	local last = planks[#planks]
	return last.along + last.length / 2
end

-- How much of something there is `along` studs from the tail tip, from 0 to
-- 1: none up to `from`, then growing evenly to all of it `length` past that.
function Bronto.growIn(along: number, from: number, length: number): number
	return math.clamp((along - from) / length, 0, 1)
end

-- The plank under the point `along` studs from the tail tip: the first or
-- last plank for a point past either end.
function Bronto.plankAt(planks: { Plank }, along: number): Plank
	for _, p in planks do
		if along <= p.along + p.length / 2 then
			return p
		end
	end
	return planks[#planks]
end

-- The point on the path `along` studs from the tail tip, as (out, up), and
-- the tilt of the plank it lies on.
function Bronto.pointAt(planks: { Plank }, along: number): (number, number, number)
	local plank = Bronto.plankAt(planks, along)
	local d = along - plank.along
	return plank.out + d * math.cos(plank.tilt), plank.up + d * math.sin(plank.tilt), plank.tilt
end

return Bronto
