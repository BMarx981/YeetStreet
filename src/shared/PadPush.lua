--!strict
-- PadPush (ModuleScript) -> ReplicatedStorage.PadPush
-- Which way an any-way launch pad (one with a LaunchPitch attribute, see
-- Pieces.LaunchPad) throws a car: the way the car is going across the
-- ground, tipped up `pitch` radians. Pure, see InputAxes.

local PadPush = {}

-- The unit direction to throw a car moving vx, vz across the ground, or nil
-- if it is moving slower than `least`.
function PadPush.anyWay(vx: number, vz: number, pitch: number, least: number): (number?, number, number)
	local flat = math.sqrt(vx * vx + vz * vz)
	if flat < least then
		return nil, 0, 0
	end
	local across = math.cos(pitch) / flat
	return vx * across, math.sin(pitch), vz * across
end

return PadPush
