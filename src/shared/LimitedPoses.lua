--!strict
-- LimitedPoses (ModuleScript) -> ReplicatedStorage.LimitedPoses
-- The moving and round bits of the worn limited looks (LimitedLooks). Pure,
-- see InputAxes. Times are server time, so every screen shows the same.

local LimitedPoses = {}

-- How the crown floats (Tuning.LimitedLooks.Crown).
export type Float = {
	Bob: number, -- studs up and down
	BobTime: number, -- seconds per float up and down
	SpinTime: number, -- seconds per turn
}

-- One block of a ring: where it sits round the middle, and how long it is.
export type Piece = {
	angle: number, -- radians round from the start
	length: number, -- studs along the ring
}

-- The underglow's hue, 0 to 1, at time `t`, fading through every color
-- once per `cycleTime`.
function LimitedPoses.hue(t: number, cycleTime: number): number
	return (t / cycleTime) % 1
end

-- How far the crown is above its rest height, and how far it has turned
-- (radians), at time `t`.
function LimitedPoses.crownFloat(t: number, float: Float): (number, number)
	local lift = float.Bob * math.sin(2 * math.pi * t / float.BobTime)
	local turn = 2 * math.pi * ((t / float.SpinTime) % 1)
	return lift, turn
end

-- `count` blocks that make a ring of `radius`, each a little longer than
-- its share so the joins don't show gaps.
function LimitedPoses.ring(radius: number, count: number): { Piece }
	local pieces = {}
	local share = 2 * math.pi * radius / count
	for i = 0, count - 1 do
		table.insert(pieces, { angle = 2 * math.pi * i / count, length = share * 1.1 })
	end
	return pieces
end

return LimitedPoses
