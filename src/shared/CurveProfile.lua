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
