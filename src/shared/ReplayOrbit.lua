--!strict
-- ReplayOrbit (ModuleScript) -> ReplicatedStorage.ReplayOrbit
-- Where the replay camera sits around the ghost car. Pure, see InputAxes.
--
-- The camera is `distance` studs from the ghost, turned `yaw` round the
-- vertical and tipped up `pitch` above level, both in radians. At yaw 0 it
-- sits toward +z; a bigger yaw turns it toward +x. Pitch stays between
-- MinPitch and MaxPitch (degrees), so the camera never goes over the top or
-- far under the ground, and distance between MinDistance and MaxDistance.
--
-- An orbit is never changed in place; each function returns a new one.

local ReplayOrbit = {}

-- Same fields as Tuning.Replay, declared here so this module needs no require.
export type Tuning = {
	MinPitch: number, -- degrees
	MaxPitch: number, -- degrees
	MinDistance: number,
	MaxDistance: number,
}

export type Orbit = {
	yaw: number,
	pitch: number,
	distance: number,
}

function ReplayOrbit.new(yaw: number, pitch: number, distance: number, tuning: Tuning): Orbit
	return {
		yaw = yaw,
		pitch = math.clamp(pitch, math.rad(tuning.MinPitch), math.rad(tuning.MaxPitch)),
		distance = math.clamp(distance, tuning.MinDistance, tuning.MaxDistance),
	}
end

-- The orbit turned `yaw` and `pitch` radians more.
function ReplayOrbit.turn(orbit: Orbit, yaw: number, pitch: number, tuning: Tuning): Orbit
	return ReplayOrbit.new(orbit.yaw + yaw, orbit.pitch + pitch, orbit.distance, tuning)
end

-- The orbit `factor` times as far away; under 1 is closer.
function ReplayOrbit.zoom(orbit: Orbit, factor: number, tuning: Tuning): Orbit
	return ReplayOrbit.new(orbit.yaw, orbit.pitch, orbit.distance * factor, tuning)
end

-- Where the camera sits from the ghost.
function ReplayOrbit.offset(orbit: Orbit): (number, number, number)
	local flat = orbit.distance * math.cos(orbit.pitch)
	return flat * math.sin(orbit.yaw), orbit.distance * math.sin(orbit.pitch), flat * math.cos(orbit.yaw)
end

-- The yaw that puts the camera along the flat direction (x, z) from the ghost.
function ReplayOrbit.facing(x: number, z: number): number
	return math.atan2(x, z)
end

return ReplayOrbit
