--!strict
-- PadPush (ModuleScript) -> ReplicatedStorage.PadPush
-- How a launch pad (see Pieces.LaunchPad) pushes a car: how much speed it
-- adds along its way, and which way an any-way pad (one with a LaunchPitch
-- attribute) throws: the way the car is going across the ground, tipped up
-- `pitch` radians. Pure, see InputAxes.

local PadPush = {}

-- The speed to add along the pad's way to a car going `along` that way, or
-- nil to leave it alone. A pad pushes a car up to its `speed`; an exact pad
-- (LaunchExact) also slows a faster car down to it.
function PadPush.change(along: number, speed: number, exact: boolean): number?
	if along < speed or exact then
		return speed - along
	end
	return nil
end

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
