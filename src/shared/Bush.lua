--!strict
-- Bush (ModuleScript) -> ReplicatedStorage.Bush
-- How a bush in Dino Valley rustles: a car moving through it shakes it up to
-- full, and it settles once the car is gone. A car stopped in it, or one
-- only crawling, leaves it still. Pure, see InputAxes.

local Bush = {}

export type Tuning = {
	MinSpeed: number, -- studs a second a car must move to rustle it
	Rise: number, -- of full rustle gained a second
	Fade: number, -- of full rustle lost a second
	Tilt: number, -- degrees it leans at full rustle
	Rate: number, -- swings a second
}

-- The rustle, 0 still to 1 full, after `dt` seconds with a car `inside`
-- moving at `speed`.
function Bush.rustle(level: number, inside: boolean, speed: number, dt: number, tuning: Tuning): number
	if inside and speed >= tuning.MinSpeed then
		return math.min(1, level + tuning.Rise * dt)
	end
	return math.max(0, level - tuning.Fade * dt)
end

-- How far it leans (radians) at time `t`; `phase` keeps bushes and their
-- parts from swinging together.
function Bush.sway(level: number, t: number, phase: number, tuning: Tuning): number
	return level * math.rad(tuning.Tilt) * math.sin(2 * math.pi * tuning.Rate * t + phase)
end

return Bush
