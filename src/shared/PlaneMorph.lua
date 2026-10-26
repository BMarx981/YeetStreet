--!strict
-- PlaneMorph (ModuleScript) -> ReplicatedStorage.PlaneMorph
-- When the PlaneCar turns from a plane into a car and back. Pure, see
-- InputAxes.
--
-- Progress runs from 0, a plane, to 1, a car. Each stage of the transform
-- has its own window of progress and eases from 0 to 1 inside it: the wings
-- fold down, the plane tips up onto them, the guns swing forward, and the
-- wheels pop out. Going back to a plane runs the same stages in reverse.

local PlaneMorph = {}

export type Stages = {
	fold: number, -- wings folded down
	tip: number, -- plane tipped nose-up onto its wings, nose folded over
	guns: number, -- guns swung to point forward
	wheels: number, -- wheels out
}

PlaneMorph.Duration = 1.2 -- seconds for a whole transform

-- Each stage's start and end, in progress.
PlaneMorph.Stages = {
	fold = { 0, 0.4 },
	tip = { 0.3, 0.75 },
	guns = { 0.6, 0.85 },
	wheels = { 0.8, 1 },
}

local function ease(progress: number, window: { number }): number
	local a = math.clamp((progress - window[1]) / (window[2] - window[1]), 0, 1)
	return a * a * (3 - 2 * a)
end

function PlaneMorph.stages(progress: number): Stages
	local w = PlaneMorph.Stages
	return {
		fold = ease(progress, w.fold),
		tip = ease(progress, w.tip),
		guns = ease(progress, w.guns),
		wheels = ease(progress, w.wheels),
	}
end

-- Progress after dt seconds heading for target, 0 or 1.
function PlaneMorph.approach(progress: number, target: number, dt: number): number
	local step = dt / PlaneMorph.Duration
	if progress < target then
		return math.min(progress + step, target)
	end
	return math.max(progress - step, target)
end

return PlaneMorph
