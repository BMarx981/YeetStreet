--!strict
-- CurveProfile (ModuleScript) -> ReplicatedStorage.CurveProfile
-- The cross section of a curved wall: a circular arc of `radius` from flat
-- ground up to `endAngle` degrees, built from straight planks. 90 is a quarter
-- pipe; past 90 the top leans back over the ground. Pure, see InputAxes.
--
-- Profile coordinates: `out` is studs from the base line (where the curve
-- starts on the ground) toward the wall, `up` is studs above the ground.

local CurveProfile = {}

export type Plank = {
	out: number, -- midpoint
	up: number, -- midpoint
	length: number, -- chord length, before any overlap
	tilt: number, -- radians from flat; past pi/2 it leans back
}

local function point(radius: number, angle: number): (number, number)
	return radius * math.sin(angle), radius * (1 - math.cos(angle))
end

function CurveProfile.planks(radius: number, endAngle: number, steps: number): { Plank }
	local finish = math.rad(endAngle)
	local planks: { Plank } = {}
	for i = 1, steps do
		local a = finish * (i - 1) / steps
		local b = finish * i / steps
		local aOut, aUp = point(radius, a)
		local bOut, bUp = point(radius, b)
		table.insert(planks, {
			out = (aOut + bOut) / 2,
			up = (aUp + bUp) / 2,
			length = 2 * radius * math.sin((b - a) / 2),
			tilt = (a + b) / 2,
		})
	end
	return planks
end

export type Point = {
	out: number,
	up: number,
}

-- The curve partway curled up from lying flat, for blending a wall in from
-- flat ground: the corners of its `steps` planks, from the base line out.
-- `curl` 1 is the curve itself; 0 lies flat on the ground, as wide as the
-- curve is long; in between it bends `curl` times as far on a wider circle,
-- so every curl is the same length.
function CurveProfile.curl(radius: number, endAngle: number, steps: number, curl: number): { Point }
	local length = radius * math.rad(endAngle)
	local points: { Point } = {}
	for i = 0, steps do
		local along = length * i / steps
		if curl <= 0 then
			table.insert(points, { out = along, up = 0 })
		else
			local wider = radius / curl
			local out, up = point(wider, along / wider)
			table.insert(points, { out = out, up = up })
		end
	end
	return points
end

-- The curve cut off where it reaches `height`, then running flat at that
-- height out to `reach`, for a curve that must not stick up past the
-- ground around a hole: its `steps` planks' corners, spread over what is
-- left of the curve, and the flat's far end. Above the curve's top it is
-- the whole curve; at 0 the curve shrinks to its base line.
function CurveProfile.clip(radius: number, endAngle: number, steps: number, height: number, reach: number): { Point }
	local finish = math.rad(endAngle)
	if height < radius * (1 - math.cos(finish)) then
		finish = math.acos(1 - math.max(height, 0) / radius)
	end
	local points: { Point } = {}
	for i = 0, steps do
		local out, up = point(radius, finish * i / steps)
		table.insert(points, { out = out, up = up })
	end
	table.insert(points, { out = reach, up = points[#points].up })
	return points
end

-- How far the curve reaches from the base line, and how tall it is.
function CurveProfile.extent(radius: number, endAngle: number): (number, number)
	local finish = math.rad(endAngle)
	local depth = if finish >= math.pi / 2 then radius else radius * math.sin(finish)
	return depth, radius * (1 - math.cos(finish))
end

-- Length of a plank in one slice of a corner swept by `sliceAngle` degrees,
-- `distance` studs from the pivot, so neighboring slices meet.
function CurveProfile.sliceLength(distance: number, sliceAngle: number): number
	return 2 * distance * math.tan(math.rad(sliceAngle) / 2)
end

return CurveProfile
