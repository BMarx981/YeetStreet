--!strict
-- RotorMorph (ModuleScript) -> ReplicatedStorage.RotorMorph
-- When the HeliCar's rotor opens and closes. Pure, see InputAxes.
--
-- Progress runs from 0, folded, to 1, open. Each stage has its own window of
-- progress and eases from 0 to 1 inside it: the mast rises, the blades swing
-- out, and they spin up. Closing runs the same stages in reverse, so they stop
-- spinning before they fold.

local RotorMorph = {}

export type Stages = {
	rise: number, -- mast up
	unfold: number, -- blades out
	spin: number, -- share of full spin speed
}

RotorMorph.Duration = 1.6 -- seconds for a whole open or close
RotorMorph.Blades = 4
RotorMorph.FoldAngle = math.rad(15) -- folded, each pair's angle off the tail
RotorMorph.SpinSpeed = 30 -- radians per second at full spin

-- Each stage's start and end, in progress.
RotorMorph.Stages = {
	rise = { 0, 0.45 },
	unfold = { 0.35, 0.7 },
	spin = { 0.7, 1 },
}

local OPEN_ANGLES = { 0, math.pi / 2, -math.pi, -math.pi / 2 }

local function ease(progress: number, window: { number }): number
	local a = math.clamp((progress - window[1]) / (window[2] - window[1]), 0, 1)
	return a * a * (3 - 2 * a)
end

function RotorMorph.stages(progress: number): Stages
	local w = RotorMorph.Stages
	return {
		rise = ease(progress, w.rise),
		unfold = ease(progress, w.unfold),
		spin = ease(progress, w.spin),
	}
end

-- Progress after dt seconds heading for target, 0 or 1.
function RotorMorph.approach(progress: number, target: number, dt: number): number
	local step = dt / RotorMorph.Duration
	if progress < target then
		return math.min(progress + step, target)
	end
	return math.max(progress - step, target)
end

-- An angle as the same direction between -pi and pi.
function RotorMorph.wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- Blade i's angle around the mast, from pointing out the back of the car.
-- `spin` is wrapped first, so the blades fold back the short way.
function RotorMorph.bladeAngle(i: number, unfold: number, spin: number): number
	local folded = if i <= 2 then RotorMorph.FoldAngle else -RotorMorph.FoldAngle
	return folded + (OPEN_ANGLES[i] - folded + RotorMorph.wrap(spin)) * unfold
end

return RotorMorph
