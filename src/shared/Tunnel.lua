--!strict
-- Tunnel (ModuleScript) -> ReplicatedStorage.Tunnel
-- The middle line of a tunnel seen from above, from straights and turns.
-- A path starts at a point heading one way, and each segment carries on from
-- where the last one ended. Pure, see InputAxes.
--
-- Headings are unit vectors on the ground (x, z). A turn's angle is in
-- degrees, positive to the left, which is counterclockwise seen from above
-- the way CFrame.Angles(0, angle, 0) turns: facing -Z, left is -X.

local Tunnel = {}

-- A segment in a tunnel's layout: either Straight, studs long, or Turn,
-- degrees, around a circle of Radius studs.
export type Segment = {
	Straight: number?,
	Turn: number?,
	Radius: number?,
}

-- A straight or a turn of the middle line, from where the car enters it to
-- where it leaves. A turn is also given as a sweep counterclockwise from
-- above, around its center, starting at `start`: where the car enters a
-- left turn, and where it leaves a right one.
export type Piece = {
	kind: "straight" | "arc",
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	centerX: number,
	centerZ: number,
	radius: number,
	startX: number,
	startZ: number,
	sweep: number, -- radians
}

export type Pose = {
	x: number,
	z: number,
	headingX: number,
	headingZ: number,
}

-- (x, z) turned `angle` radians to the left.
local function turned(x: number, z: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return x * c + z * s, -x * s + z * c
end

function Tunnel.path(x: number, z: number, headingX: number, headingZ: number, segments: { Segment }): ({ Piece }, Pose)
	local pieces: { Piece } = {}
	for _, segment in segments do
		if segment.Straight then
			local length = segment.Straight
			local toX, toZ = x + headingX * length, z + headingZ * length
			table.insert(pieces, {
				kind = "straight",
				fromX = x,
				fromZ = z,
				toX = toX,
				toZ = toZ,
				centerX = 0,
				centerZ = 0,
				radius = 0,
				startX = x,
				startZ = z,
				sweep = 0,
			})
			x, z = toX, toZ
		else
			local angle = math.rad(segment.Turn or 0)
			local radius = segment.Radius or 0
			local side = if angle > 0 then 1 else -1
			-- To the left is the heading turned a quarter left.
			local leftX, leftZ = headingZ, -headingX
			local centerX, centerZ = x + leftX * side * radius, z + leftZ * side * radius
			local outX, outZ = turned(x - centerX, z - centerZ, angle)
			local toX, toZ = centerX + outX, centerZ + outZ
			table.insert(pieces, {
				kind = "arc",
				fromX = x,
				fromZ = z,
				toX = toX,
				toZ = toZ,
				centerX = centerX,
				centerZ = centerZ,
				radius = radius,
				startX = if angle > 0 then x else toX,
				startZ = if angle > 0 then z else toZ,
				sweep = math.abs(angle),
			})
			x, z = toX, toZ
			headingX, headingZ = turned(headingX, headingZ, angle)
		end
	end
	return pieces, { x = x, z = z, headingX = headingX, headingZ = headingZ }
end

return Tunnel
