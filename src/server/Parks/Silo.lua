--!strict
-- Silo (ModuleScript) -> ServerScriptService.Parks.Silo
-- The missile silo, built by ParkService into workspace.Parks.Silo: from up
-- top, just a huge round hole in the floor. A curved lip runs over into a
-- straight shaft, and a spiral ramp winds down a column in the middle, reached
-- by a bridge from the rim. The ramp's edge is open, so a car that drifts off
-- falls to the bottom. Numbers are in Tuning.Silo, the shape in Silo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Railway = require(ReplicatedStorage.Railway)
local Silo = require(ReplicatedStorage.Silo)
local Tuning = require(ReplicatedStorage.Tuning)
local Triangle = require(ServerScriptService.Pieces.Triangle)

local S = Tuning.Silo
local SHAPE: Silo.Shape = S :: any
local FLOOR = Tuning.Map.FloorTop
local GROUND_BOTTOM = -4 -- under TestPark's ground slab

local FLOOR_COLOR = Color3.fromRGB(170, 170, 165) -- as ParkBuilder's floor
local WALL_COLOR = Color3.fromRGB(92, 96, 102)
local RAMP_COLOR = Color3.fromRGB(130, 134, 140)
local COLUMN_COLOR = Color3.fromRGB(74, 78, 84)
local HAZARD_YELLOW = Color3.fromRGB(240, 190, 30)
local HAZARD_BLACK = Color3.fromRGB(30, 30, 34)
local LAMP_COLOR = Color3.fromRGB(255, 240, 210)

local SiloPark = {}

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

-- Which way is out from the middle at `angle`.
local function outward(angle: number): Vector3
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

-- A plank of the shaft's surface around `angle`, across the slice and from
-- (r0, y0) to (r1, y1), its top facing the hole.
local function surfacePlank(
	parent: Instance,
	center: CFrame,
	angle: number,
	width: number,
	r0: number,
	y0: number,
	r1: number,
	y1: number,
	color: Color3
)
	local out = outward(angle)
	local p0 = out * r0 + Vector3.yAxis * y0
	local p1 = out * r1 + Vector3.yAxis * y1
	local chord = p1 - p0
	local along = chord.Unit
	local normal = Vector3.new(-out.Z, 0, out.X):Cross(along)
	if normal:Dot(Vector3.yAxis - out) < 0 then
		normal = -normal
	end
	local across = along:Cross(normal)
	local middle = (p0 + p1) / 2 - normal * S.Thickness / 2
	block(
		parent,
		"Wall",
		Vector3.new(width, S.Thickness, chord.Magnitude + 0.4),
		center * CFrame.fromMatrix(middle, across, normal, across:Cross(normal)),
		color
	)
end

local function buildShaft(parent: Instance, center: CFrame)
	local model = Instance.new("Model")
	model.Name = "Shaft"
	model.Parent = parent
	local rim = Silo.rimRadius(SHAPE)
	local step = 2 * math.pi / S.Slices
	local half = math.sin(step / 2)
	local apothem = math.cos(step / 2)
	for i = 1, S.Slices do
		local angle = (i - 0.5) * step
		surfacePlank(
			model,
			center,
			angle,
			2 * S.Radius * half + 0.4,
			S.Radius * apothem,
			-S.Depth + S.BaseRadius,
			S.Radius * apothem,
			-S.LipRadius,
			WALL_COLOR
		)
		for row = 1, S.BaseRows do
			local r0, y0 = Silo.basePoint(SHAPE, (row - 1) / S.BaseRows * math.pi / 2)
			local r1, y1 = Silo.basePoint(SHAPE, row / S.BaseRows * math.pi / 2)
			surfacePlank(model, center, angle, 2 * r1 * half + 0.4, r0 * apothem, y0, r1 * apothem, y1, WALL_COLOR)
		end
		for row = 1, S.LipRows do
			local r0, y0 = Silo.lipPoint(SHAPE, (row - 1) / S.LipRows * math.pi / 2)
			local r1, y1 = Silo.lipPoint(SHAPE, row / S.LipRows * math.pi / 2)
			local color = WALL_COLOR
			if row == S.LipRows then
				color = if (i - 1) // S.HazardSlices % 2 == 0 then HAZARD_YELLOW else HAZARD_BLACK
			end
			surfacePlank(model, center, angle, 2 * r1 * half + 0.4, r0 * apothem, y0, r1 * apothem, y1, color)
		end
	end
	block(
		model,
		"Bottom",
		Vector3.new(2 * rim + 20, S.Thickness, 2 * rim + 20),
		center * CFrame.new(0, -S.Depth - S.Thickness / 2, 0),
		WALL_COLOR
	)
end

-- A ring of `count` lamps, `radius` from the middle and `y` high.
local function lampRing(parent: Instance, center: CFrame, radius: number, y: number, count: number)
	local L = S.Lamps
	for i = 1, count do
		local out = outward((i - 0.5) / count * 2 * math.pi)
		local at = out * radius + Vector3.new(0, y, 0)
		local lamp =
			block(parent, "Lamp", Vector3.new(L.Size, L.Size / 2, 1), center * CFrame.lookAt(at, at + out), LAMP_COLOR)
		lamp.Material = Enum.Material.Neon
		lamp.CanCollide = false
		local light = Instance.new("PointLight")
		light.Range = L.Range
		light.Brightness = L.Brightness
		light.Color = LAMP_COLOR
		light.Parent = lamp
	end
end

-- Lamps round the wall and the column, every Every on the way down.
local function buildLamps(parent: Instance, center: CFrame)
	local L = S.Lamps
	local y = -L.Every
	while y > -S.Depth do
		lampRing(parent, center, S.Radius - 0.5, y, L.PerRing)
		lampRing(parent, center, S.ColumnRadius + 0.5, y + L.Every / 2, L.PerColumnRing)
		y -= L.Every
	end
	lampRing(parent, center, S.Radius - 0.5, -S.Depth + L.BottomHeight, L.PerRing)
	lampRing(parent, center, S.ColumnRadius + 0.5, -S.Depth + L.BottomHeight, L.PerColumnRing)
end

local function buildRamp(parent: Instance, center: CFrame)
	local R = S.Ramp
	local model = Instance.new("Model")
	model.Name = "SpiralRamp"
	model.Parent = parent

	local column = block(
		model,
		"Column",
		Vector3.new(S.Depth, 2 * S.ColumnRadius, 2 * S.ColumnRadius),
		center * CFrame.new(0, -S.Depth / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		COLUMN_COLOR
	)
	column.Shape = Enum.PartType.Cylinder

	local function point(radius: number, along: number): Vector3
		local x, y, z = Silo.rampPoint(SHAPE, radius, along)
		return center:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local sweep = Silo.rampSweep(SHAPE)
	local steps = math.ceil(sweep / (2 * math.pi) * R.StepsPerTurn)
	for i = 1, steps do
		local a0, a1 = sweep * (i - 1) / steps, sweep * i / steps
		local flat = R.OuterRadius - R.LipWidth
		local inner0, flat0 = point(R.InnerRadius, a0), point(flat, a0)
		local inner1, flat1 = point(R.InnerRadius, a1), point(flat, a1)
		Triangle.make(model, inner0, flat0, flat1, Vector3.yAxis, R.Thickness, RAMP_COLOR)
		Triangle.make(model, inner0, flat1, inner1, Vector3.yAxis, R.Thickness, RAMP_COLOR)

		-- A straight lip up the outer edge that pushes a drifting car back in,
		-- like the brontosaurus's.
		local lip0 = point(R.OuterRadius, a0) + Vector3.new(0, Silo.rampLipHeight(SHAPE, a0), 0)
		local lip1 = point(R.OuterRadius, a1) + Vector3.new(0, Silo.rampLipHeight(SHAPE, a1), 0)
		Triangle.make(model, flat0, lip0, lip1, Vector3.yAxis, R.Thickness, RAMP_COLOR)
		Triangle.make(model, flat0, lip1, flat1, Vector3.yAxis, R.Thickness, RAMP_COLOR)

		-- A glowing edge, so the drop can be seen in the dark.
		local edge = block(
			model,
			"Edge",
			Vector3.new(R.EdgeWidth, 0.2, (lip1 - lip0).Magnitude + 0.4),
			CFrame.lookAt((lip0 + lip1) / 2, lip1),
			LAMP_COLOR
		)
		edge.Material = Enum.Material.Neon
		edge.CanCollide = false
		edge.CastShadow = false
	end

	-- From the rim straight in to the ramp's start, on the ramp's own line.
	local rim = Silo.rimRadius(SHAPE)
	local width = R.OuterRadius - R.InnerRadius
	local lane = (R.OuterRadius + R.InnerRadius) / 2
	local reach = math.sqrt(rim * rim - R.InnerRadius * R.InnerRadius)
	block(
		model,
		"Bridge",
		Vector3.new(width, R.Thickness, reach),
		center * CFrame.new(lane, -R.Thickness / 2, reach / 2),
		FLOOR_COLOR
	)
end

-- The floor closed back round the rim, out to the square hole cut for it.
local function buildCollar(parent: Instance, center: CFrame, half: number)
	local model = Instance.new("Model")
	model.Name = "Collar"
	model.Parent = parent
	local rim = Silo.rimRadius(SHAPE)
	local function atRim(angle: number): Vector3
		return center:PointToWorldSpace(outward(angle) * rim)
	end
	local function atSquare(angle: number): Vector3
		local x, z = Silo.squareEdge(half, angle)
		return center:PointToWorldSpace(Vector3.new(x, 0, z))
	end
	local depth = FLOOR - GROUND_BOTTOM
	for i = 1, S.Slices do
		local a0, a1 = (i - 1) / S.Slices * 2 * math.pi, i / S.Slices * 2 * math.pi
		local rim0, rim1, far0, far1 = atRim(a0), atRim(a1), atSquare(a0), atSquare(a1)
		Triangle.make(model, rim0, far0, far1, Vector3.yAxis, depth, FLOOR_COLOR)
		Triangle.make(model, rim0, far1, rim1, Vector3.yAxis, depth, FLOOR_COLOR)
	end
end

-- Cuts `hole` (world, seen from above) out of every part that it overlaps,
-- replacing it with the pieces around it.
local function cutGround(parts: { BasePart }, hole: Railway.Rect)
	for _, part in parts do
		local p, s = part.Position, part.Size
		local rect = { x1 = p.X - s.X / 2, x2 = p.X + s.X / 2, z1 = p.Z - s.Z / 2, z2 = p.Z + s.Z / 2 }
		local pieces = Railway.cut(rect, { hole })
		if #pieces == 1 and pieces[1] == rect then
			continue
		end
		for _, piece in pieces do
			local copy = part:Clone()
			copy.Size = Vector3.new(piece.x2 - piece.x1, s.Y, piece.z2 - piece.z1)
			copy.CFrame = CFrame.new((piece.x1 + piece.x2) / 2, p.Y, (piece.z1 + piece.z2) / 2)
			copy.Parent = part.Parent
		end
		part:Destroy()
	end
end

-- The park's floor parts in `folder` and TestPark's ground slab tiles under
-- them, for cutting the hole in.
local function groundParts(folder: Folder): { BasePart }
	local parts: { BasePart } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Floor" then
			table.insert(parts, child)
		end
	end
	local testPark = workspace:FindFirstChild("TestPark")
	local slab = testPark and testPark:FindFirstChild("Ground")
	if slab then
		for _, tile in slab:GetChildren() do
			if tile:IsA("BasePart") then
				table.insert(parts, tile)
			end
		end
	end
	return parts
end

function SiloPark.build(folder: Folder, area: MapLayout.Area)
	local center = CFrame.new(area.X, FLOOR, area.Z)
	local half = Silo.rimRadius(SHAPE) + S.CollarWidth
	cutGround(groundParts(folder), {
		x1 = area.X - half,
		x2 = area.X + half,
		z1 = area.Z - half,
		z2 = area.Z + half,
	})
	buildCollar(folder, center, half)
	buildShaft(folder, center)
	buildRamp(folder, center)
	buildLamps(folder, center)
end

return SiloPark
