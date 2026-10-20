--!strict
-- Corkscrew (ModuleScript) -> ReplicatedStorage.Corkscrew
-- The track of a corkscrew: a helix of `radius` around a straight axis,
-- moving `pitch` studs along the axis for each loop, built from straight
-- planks. The car rides on the inside, with the axis overhead at the bottom
-- of each loop and underfoot at the top. Each plank lies square to the axis,
-- its width along the axis, and the next one sits a little farther along, so
-- neighbors share one straight seam the way a curved ramp's planks do. Pure,
-- see InputAxes.
--
-- Helix coordinates: `along` is studs along the axis from where the track
-- starts, `angle` is radians around the axis from the bottom of the first
-- loop, growing the way the car travels.

local Corkscrew = {}

export type Plank = {
	along: number, -- midpoint
	angle: number, -- midpoint
	step: number, -- radians around the axis from the plank's start to its end
	length: number, -- chord length around the axis, before any overlap
	shift: number, -- studs along the axis from this plank to the next
	-- Radians the track turns from straight around the axis toward straight
	-- along it, which is the way a booster on the plank pushes.
	slope: number,
	inset: number, -- how much nearer the axis than `radius` its middle sits
}

-- `loops` full loops of `stepsPerLoop` planks each, then on around the
-- axis by `exitAngle` degrees, so the track ends partway up a wall and
-- throws the car up and out.
function Corkscrew.planks(radius: number, pitch: number, loops: number, stepsPerLoop: number, exitAngle: number): { Plank }
	local step = 2 * math.pi / stepsPerLoop
	local count = loops * stepsPerLoop + math.ceil(math.rad(exitAngle) / step - 1e-9)
	local sweep = 2 * math.pi * loops + math.rad(exitAngle)
	step = sweep / count
	local around = 2 * radius * math.sin(step / 2)
	local alongStep = pitch * step / (2 * math.pi)
	local planks: { Plank } = {}
	for i = 1, count do
		local angle = step * (i - 0.5)
		table.insert(planks, {
			along = pitch * angle / (2 * math.pi),
			angle = angle,
			step = step,
			length = around,
			shift = alongStep,
			slope = math.atan2(alongStep, around),
			inset = radius * (1 - math.cos(step / 2)),
		})
	end
	return planks
end

-- How far along an axis climbing `rise` over `run` from the ground a track
-- `width` wide can start, so the low side of its first loop's bottom just
-- touches the ground.
function Corkscrew.entry(radius: number, rise: number, run: number, width: number): number
	return radius * run / rise + width / 2
end

return Corkscrew
