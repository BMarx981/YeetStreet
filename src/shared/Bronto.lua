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
