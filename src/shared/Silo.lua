--!strict
-- Silo (ModuleScript) -> ReplicatedStorage.Silo
-- The shape of the missile silo (Tuning.Silo): a round shaft under the
-- ground, a curved lip from the ground over into the shaft, and a spiral ramp
-- down a column in the middle. Coordinates are studs from the shaft's middle
-- with Y = 0 on the floor's top, so the shaft is all below 0. Pure, see
-- InputAxes.

local Silo = {}

export type Shape = {
	Radius: number, -- the shaft's straight wall
	LipRadius: number,
	Depth: number,
	Margin: number,
	Ramp: { Pitch: number }, -- studs down per turn
}

function Silo.rimRadius(shape: Shape): number
	return shape.Radius + shape.LipRadius
end

-- A point on the lip's curve, `angle` radians from the top of the straight
-- wall (0) round to the ground (pi / 2), as its distance from the middle and
-- its height.
function Silo.lipPoint(shape: Shape, angle: number): (number, number)
	local L = shape.LipRadius
	return shape.Radius + L * (1 - math.cos(angle)), L * (math.sin(angle) - 1)
end

-- Radians the ramp turns from the ground to the bottom.
function Silo.rampSweep(shape: Shape): number
	return 2 * math.pi * shape.Depth / shape.Ramp.Pitch
end

-- A point on the ramp, `radius` from the middle and `along` radians from its
-- start. It starts on +X heading -Z, the way the bridge runs.
function Silo.rampPoint(shape: Shape, radius: number, along: number): (number, number, number)
	return radius * math.cos(along), -shape.Ramp.Pitch * along / (2 * math.pi), -radius * math.sin(along)
end

-- Where a ray from the middle of a square `half` studs from middle to side
-- meets its edge, `angle` radians round from +X toward +Z.
function Silo.squareEdge(half: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	local scale = half / math.max(math.abs(c), math.abs(s))
	return c * scale, s * scale
end

-- Whether the point is in the hole: under the ground, within the rim, and no
-- more than Margin below the bottom.
function Silo.inside(shape: Shape, x: number, y: number, z: number): boolean
	local rim = Silo.rimRadius(shape)
	return y < 0 and y > -shape.Depth - shape.Margin and x * x + z * z <= rim * rim
end

return Silo
