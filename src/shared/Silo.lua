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
	BaseRadius: number, -- the curve from the bottom up to the straight wall
	Wall: { Reach: number }, -- how far off the surface it still holds a car
	Ramp: {
		Pitch: number, -- studs down per turn
		InnerRadius: number,
		OuterRadius: number,
		LipWidth: number,
		LipHeight: number,
		LipGrow: number, -- studs along the outer edge to reach full height
	},
	Buttons: {
		Ramp: { number }, -- turns down the ramp
		Wall: { { Angle: number, Y: number } }, -- degrees round from +X toward +Z
		Launch: { X: number, Z: number },
	},
}

export type Button = {
	Id: string,
	X: number,
	Y: number,
	Z: number,
	NormalX: number, -- which way it faces
	NormalY: number,
	NormalZ: number,
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

-- A point on the base's curve, `angle` radians from the bottom (0) round to
-- the foot of the straight wall (pi / 2), as its distance from the middle and
-- its height.
function Silo.basePoint(shape: Shape, angle: number): (number, number)
	local B = shape.BaseRadius
	return shape.Radius - B + B * math.sin(angle), -shape.Depth + B - B * math.cos(angle)
end

-- Which way the shaft's surface holds a car at (x, y, z), toward the surface,
-- as a unit vector: nil further than Reach off it, on the flat bottom, or
-- outside the hole.
function Silo.wallPull(shape: Shape, x: number, y: number, z: number): (number?, number?, number?)
	local r = math.sqrt(x * x + z * z)
	if y >= 0 or r > Silo.rimRadius(shape) or r < 1e-6 then
		return nil, nil, nil
	end
	local R, L, B = shape.Radius, shape.LipRadius, shape.BaseRadius
	local gap, out, up
	if y > -L then
		-- Over the lip, toward the middle of its curve.
		local dr, dy = R + L - r, -L - y
		local d = math.sqrt(dr * dr + dy * dy)
		gap, out, up = d - L, dr / d, dy / d
	elseif y > -shape.Depth + B then
		gap, out, up = R - r, 1, 0
	else
		-- In the base, away from the middle of its curve.
		local dr, dy = r - (R - B), y - (-shape.Depth + B)
		if dr <= 0 then
			return nil, nil, nil
		end
		local d = math.sqrt(dr * dr + dy * dy)
		gap, out, up = B - d, dr / d, dy / d
	end
	if gap > shape.Wall.Reach then
		return nil, nil, nil
	end
	return out * x / r, up, out * z / r
end

-- Whether a car has peeled off the wall: once it is slower than `minSpeed`
-- along the surface, until it is away from the wall (`atWall` false).
function Silo.stepPeel(peeled: boolean, atWall: boolean, speed: number, minSpeed: number): boolean
	if not atWall then
		return false
	end
	return peeled or speed < minSpeed
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

-- How high the ramp's outer lip stands `along` radians from its start. It
-- grows in from nothing at each end, so a car driving on or off never meets
-- a step.
function Silo.rampLipHeight(shape: Shape, along: number): number
	local R = shape.Ramp
	local fromEnd = math.min(along, Silo.rampSweep(shape) - along)
	return R.LipHeight * math.clamp(fromEnd * R.OuterRadius / R.LipGrow, 0, 1)
end

-- Where a ray from the middle of a square `half` studs from middle to side
-- meets its edge, `angle` radians round from +X toward +Z.
function Silo.squareEdge(half: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	local scale = half / math.max(math.abs(c), math.abs(s))
	return c * scale, s * scale
end

-- Every button that has to be pressed before the launch, in the order: ramp,
-- then wall.
function Silo.buttons(shape: Shape): { Button }
	local R = shape.Ramp
	local lane = (R.InnerRadius + R.OuterRadius - R.LipWidth) / 2
	local buttons: { Button } = {}
	for i, turns in shape.Buttons.Ramp do
		local along = turns * 2 * math.pi
		local x, y, z = Silo.rampPoint(shape, lane, along)
		-- Square to the ramp: across it, crossed with along it.
		local c, s = math.cos(along), math.sin(along)
		local drop = R.Pitch / (2 * math.pi)
		local length = math.sqrt(lane * lane + drop * drop)
		table.insert(buttons, {
			Id = `Ramp{i}`,
			X = x,
			Y = y,
			Z = z,
			NormalX = -drop * c / length,
			NormalY = lane / length,
			NormalZ = drop * s / length,
		})
	end
	for i, place in shape.Buttons.Wall do
		local angle = math.rad(place.Angle)
		local c, s = math.cos(angle), math.sin(angle)
		table.insert(buttons, {
			Id = `Wall{i}`,
			X = shape.Radius * c,
			Y = place.Y,
			Z = shape.Radius * s,
			NormalX = -c,
			NormalY = 0,
			NormalZ = -s,
		})
	end
	return buttons
end

-- Where the launch button sits, on the bottom.
function Silo.launchPoint(shape: Shape): (number, number, number)
	local L = shape.Buttons.Launch
	return L.X, -shape.Depth, L.Z
end

-- The Id of the button within `reach` of the point, if any.
function Silo.touching(buttons: { Button }, reach: number, x: number, y: number, z: number): string?
	for _, button in buttons do
		local dx, dy, dz = x - button.X, y - button.Y, z - button.Z
		if dx * dx + dy * dy + dz * dz <= reach * reach then
			return button.Id
		end
	end
	return nil
end

-- Whether every button is in `pressed`, a set of Ids.
function Silo.armed(buttons: { Button }, pressed: { [string]: boolean }): boolean
	for _, button in buttons do
		if not pressed[button.Id] then
			return false
		end
	end
	return true
end

-- A set of pressed Ids as text for a player attribute, and back.
function Silo.encodePressed(pressed: { [string]: boolean }): string
	local ids = {}
	for id in pressed do
		table.insert(ids, id)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

function Silo.decodePressed(text: string): { [string]: boolean }
	local pressed: { [string]: boolean } = {}
	for id in string.gmatch(text, "[^,]+") do
		pressed[id] = true
	end
	return pressed
end

-- Whether the point is in the hole: under the ground, within the rim, and no
-- more than Margin below the bottom.
function Silo.inside(shape: Shape, x: number, y: number, z: number): boolean
	local rim = Silo.rimRadius(shape)
	return y < 0 and y > -shape.Depth - shape.Margin and x * x + z * z <= rim * rim
end

return Silo
