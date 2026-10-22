--!strict
-- Tube (ModuleScript) -> ServerScriptService.Pieces.Tube
-- A round tube along a middle line from Tunnel.path: a ring of Sides planks
-- all the way round every `sliceAngle` degrees of its turns and StepLength
-- of its climbs, so a car can drive up its walls and along its roof, and
-- climb (CarController pulls a car toward the wall inside one). Over
-- FlareLength at each end the tube opens out into a mouth with a wide flat
-- floor and curves up each side, like the corkscrew's middle ramp, so a car
-- can drive in off center or at an angle; each end's floor is a ground
-- height below its middle line. Dim lights hang along the roof. Used by
-- Downtown's tunnel chains and spiral towers, and Dino Valley's volcano.
--
-- The middle line's points are in the space of `base`, which may only turn
-- about Y, so up stays up: a park's floor at its middle, say.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Triangle = require(ServerScriptService.Pieces.Triangle)

local Tube = {}

-- The tube's shape, as in Tuning.City.Tunnels.
export type Options = {
	Radius: number, -- from the middle line to the planks
	Sides: number, -- planks around the ring
	MouthFloor: number,
	MouthCurve: number,
	FlareLength: number,
	FlareRows: number,
	StepLength: number,
	LightEvery: number,
	LightBrightness: number,
	LightRange: number,
}

local THICKNESS = 2
local LIGHT_COLOR = Color3.fromRGB(255, 214, 160)
local TUBE_COLOR = Color3.fromRGB(150, 156, 166)
-- Planks are this much wider than their chord so the seams stay closed.
local OVERLAP = 0.4

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- One ring of Sides planks around a middle line at `middle`, its cross
-- section square to the line: `side` level across it and `up` square to
-- both. The curves are `radius` around, pulled `flat` apart either side into
-- a flat floor and roof. Each plank is `lengthAt` long, given how far out
-- along `side` its middle is.
local function ring(
	parent: Instance,
	options: Options,
	middle: Vector3,
	side: Vector3,
	up: Vector3,
	flat: number,
	radius: number,
	lengthAt: (number) -> number
)
	local halfStep = math.pi / options.Sides
	local face = radius * math.cos(halfStep)
	local chord = 2 * radius * math.sin(halfStep)
	for k = 0, options.Sides - 1 do
		local angle = 2 * halfStep * k -- from the bottom, round toward `side`
		local s = math.sin(angle)
		local out = -up * math.cos(angle) + side * s
		local around = side * math.cos(angle) + up * s
		-- The floor and roof planks span the flat; the rest move out to it.
		local level = math.abs(s) < 1e-6
		local width = chord + OVERLAP + (if level then 2 * flat else 0)
		local shift = if level then 0 else flat * math.sign(s)
		block(
			parent,
			"Plank",
			Vector3.new(width, THICKNESS, lengthAt(face * s + shift)),
			CFrame.fromMatrix(middle + side * shift + out * (face + THICKNESS / 2), around, -out),
			TUBE_COLOR
		)
	end
end

-- A dim light on a tunnel's roof.
local function light(parent: Instance, options: Options, cframe: CFrame)
	local fixture = block(parent, "Light", Vector3.new(6, 0.3, 2), cframe, LIGHT_COLOR)
	fixture.Material = Enum.Material.SmoothPlastic
	fixture.CanCollide = false
	fixture.CanQuery = false
	fixture.CanTouch = false
	local glow = Instance.new("PointLight")
	glow.Brightness = options.LightBrightness
	glow.Range = options.LightRange
	glow.Color = LIGHT_COLOR
	glow.Parent = fixture
end

-- Builds the tube along `pieces` into `model`.
function Tube.build(model: Instance, base: CFrame, pieces: { Tunnel.Piece }, sliceAngle: number, options: Options)
	local T = options
	local halfStep = math.pi / T.Sides
	local face = T.Radius * math.cos(halfStep) -- from the middle line to each plank's inside face
	local ground = T.Radius * math.cos(halfStep) + Tunnel.LIFT
	local mouthFlat = T.MouthFloor / 2

	local function floorAt(x: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, 0, z))
	end
	local function pointAt(piece: Tunnel.Piece, t: number): Vector3
		local x, y, z = Tunnel.pointAt(piece, math.clamp(t, 0, 1))
		return base:PointToWorldSpace(Vector3.new(x, y, z))
	end
	-- The way the middle line runs at `t` along a piece.
	local function tangentAt(piece: Tunnel.Piece, t: number): Vector3
		return (pointAt(piece, t + 0.001) - pointAt(piece, t - 0.001)).Unit
	end

	-- The opening from a mouth on the floor at `mouth` in along `inward` to
	-- where it meets the tube, in FlareRows rows of triangles between rings
	-- of the planks' inside corners. Each ring is the tube's, pulled apart
	-- across the middle into a flat floor and roof, its curves eased from
	-- MouthCurve around to Radius and its floor from MouthFloor wide to
	-- nothing, so it meets the tube without a fold.
	local function flare(mouth: Vector3, inward: Vector3)
		local side = Vector3.new(-inward.Z, 0, inward.X)
		local function corners(row: number): ({ Vector3 }, Vector3)
			local ease = Tunnel.ease(1 - row / T.FlareRows)
			local radius = T.Radius + (T.MouthCurve - T.Radius) * ease
			local flat = mouthFlat * ease
			local middle = mouth
				+ inward * (T.FlareLength * row / T.FlareRows)
				+ Vector3.new(0, radius * math.cos(halfStep) + Tunnel.LIFT, 0)
			local points: { Vector3 } = {}
			for k = 0, T.Sides - 1 do
				local angle = 2 * halfStep * k + halfStep
				local across = radius * math.sin(angle) + flat * math.sign(math.sin(angle))
				table.insert(points, middle + side * across - Vector3.yAxis * radius * math.cos(angle))
			end
			return points, middle
		end
		local back, backMiddle = corners(0)
		for row = 1, T.FlareRows do
			local front, frontMiddle = corners(row)
			local middle = (backMiddle + frontMiddle) / 2
			for k = 1, T.Sides do
				local n = k % T.Sides + 1
				local inside = middle - (back[k] + front[n]) / 2
				for _, wedge in Triangle.make(model, back[k], back[n], front[n], inside, THICKNESS, TUBE_COLOR) do
					wedge.Name = "Plank"
				end
				for _, wedge in Triangle.make(model, back[k], front[n], front[k], inside, THICKNESS, TUBE_COLOR) do
					wedge.Name = "Plank"
				end
			end
			back, backMiddle = front, frontMiddle
		end
	end

	local total = 0
	for _, piece in pieces do
		total += Tunnel.length(piece)
	end
	if Tunnel.length(pieces[1]) < T.FlareLength or Tunnel.length(pieces[#pieces]) < T.FlareLength then
		warn("Tube: a tube needs a level straight at least FlareLength long at each end")
	end
	-- Lights every LightEvery of the middle line, but not in the mouths.
	local travelled = 0

	for index, piece in pieces do
		local length = Tunnel.length(piece)
		local climbs = math.abs(piece.toY - piece.fromY) > 0.01
		-- The part of this piece the rings cover: all of it, but the mouths'
		-- openings at either end of the chain.
		local start = if index == 1 then T.FlareLength / length else 0
		local finish = if index == #pieces then 1 - T.FlareLength / length else 1
		local steps = if piece.kind == "arc"
			then math.ceil(math.deg(piece.sweep) / sliceAngle)
			elseif climbs then math.ceil(length / T.StepLength)
			else 1
		local slice = math.deg(piece.sweep) / steps
		local center = floorAt(piece.centerX, piece.centerZ)
		for i = 1, steps do
			local t0 = start + (finish - start) * (i - 1) / steps
			local t1 = start + (finish - start) * i / steps
			local middle = pointAt(piece, (t0 + t1) / 2)
			local along = tangentAt(piece, (t0 + t1) / 2)
			local side = Vector3.new(-along.Z, 0, along.X).Unit
			local up = side:Cross(along)
			-- Planks are this much longer where the line bends up or down
			-- between rings, so the seams stay closed.
			local bend = face * math.abs(math.asin(tangentAt(piece, t1).Y) - math.asin(tangentAt(piece, t0).Y))
			local lengthAt: (number) -> number
			if piece.kind == "arc" then
				local outward = Vector3.new(middle.X - center.X, 0, middle.Z - center.Z).Unit
				local level = math.sqrt(1 - along.Y * along.Y)
				lengthAt = function(out: number): number
					return CurveProfile.sliceLength(piece.radius + out * side:Dot(outward), slice) / level + bend
				end
			else
				local stretch = (pointAt(piece, t1) - pointAt(piece, t0)).Magnitude + bend
				lengthAt = function(_: number): number
					return stretch
				end
			end
			ring(model, T, middle, side, up, 0, T.Radius, lengthAt)
		end
		if index == 1 then
			flare(pointAt(piece, 0) - Vector3.new(0, ground, 0), tangentAt(piece, 0))
		end
		if index == #pieces then
			flare(pointAt(piece, 1) - Vector3.new(0, ground, 0), -tangentAt(piece, 1))
		end

		local d = (T.LightEvery / 2 - travelled) % T.LightEvery
		while d <= length do
			local reached = travelled + d
			if reached > T.FlareLength and reached < total - T.FlareLength then
				local t = d / length
				local along = tangentAt(piece, t)
				local up = Vector3.new(-along.Z, 0, along.X).Unit:Cross(along)
				local spot = pointAt(piece, t) + up * (face - 0.1)
				light(model, T, CFrame.lookAt(spot, spot + along, up))
			end
			d += T.LightEvery
		end
		travelled += length
	end
end

return Tube
