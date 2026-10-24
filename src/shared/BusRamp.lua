--!strict
-- BusRamp (ModuleScript) -> ReplicatedStorage.BusRamp
-- An old safari bus in Dino Valley tipped onto its side and nose down into
-- the grass, its upturned side a ramp. Seen side on, it is tipped `angle`
-- (radians) so the lower corner of its tail rests on the ground: its side
-- rises out of the grass for `run` studs to `top` high, and the rest of it,
-- `buried`, is under the grass. Pure, see InputAxes.

local BusRamp = {}

export type Shape = {
	run: number, -- studs of its side above the grass, up the slope
	buried: number, -- studs of it under the grass
	top: number, -- how high its side's top edge is
}

-- A bus `length` long and `thickness` thick (its width, lying on its side).
-- One too short to reach the ground from its tail is all ramp, its nose
-- just touching the grass.
function BusRamp.shape(length: number, thickness: number, angle: number): Shape
	local run = math.min(length, thickness / math.tan(angle))
	return {
		run = run,
		buried = length - run,
		top = run * math.sin(angle),
	}
end

-- How far its run reaches seen from above.
function BusRamp.across(shape: Shape, angle: number): number
	return shape.run * math.cos(angle)
end

return BusRamp
