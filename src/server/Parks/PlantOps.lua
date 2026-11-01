--!strict
-- PlantOps (ModuleScript) -> ServerScriptService.Parks.PlantOps
-- The nuclear plant's operations building beside the cooling towers. It drives
-- like a Downtown building: a curve along the foot of each side and round each
-- corner rising to the wall, and a lip along each roof edge. It looks like a
-- laboratory: white panels, ribbon windows behind thin fins, a glowing band, a
-- sign with status lights, and a glass dome, radar dish, antenna, and vents on
-- the roof. Only the tower, curves, lips, and dome are solid; the rest is paint
-- and fittings cars pass through. Numbers are in Tuning.Plant.Ops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)

local O = Tuning.Plant.Ops
local FLOOR = Tuning.Map.FloorTop

local PlantOps = {}

local function solid(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A part cars and wheel rays pass through.
local function fitting(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = solid(parent, name, size, cframe, color)
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- A cylinder standing up, `height` tall from `base`.
local function upright(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	base: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = fitting(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Along the foot of each side a curve, with one round each corner, as on a
-- Downtown building (City.buildSides).
local function buildFoot(parent: Instance, center: CFrame, halfX: number, halfZ: number)
	local R = O.CurveRadius
	local options: CurvedWall.Options = {
		radius = R,
		endAngle = 90,
		steps = O.CurveSteps,
		thickness = 2,
		color = O.Wall,
		material = Enum.Material.SmoothPlastic,
	}
	local corners = {
		center:PointToWorldSpace(Vector3.new(-halfX, 0, -halfZ)),
		center:PointToWorldSpace(Vector3.new(halfX, 0, -halfZ)),
		center:PointToWorldSpace(Vector3.new(halfX, 0, halfZ)),
		center:PointToWorldSpace(Vector3.new(-halfX, 0, halfZ)),
	}
	local outs = { -Vector3.zAxis, Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis }
	for i, from in corners do
		local to = corners[i % 4 + 1]
		local out = outs[i]
		local base = (from + to) / 2 + out * R
		CurvedWall.straight(parent, CFrame.lookAt(base, base - out), (to - from).Magnitude, options)
		-- The curve turns left from where it starts.
		local before = outs[(i + 2) % 4 + 1]
		local left = Vector3.new(before.Z, 0, -before.X)
		local start = if left:Dot(out) > 0.5 then before else out
		CurvedWall.outside(parent, CFrame.lookAt(from, from + start), R, 90, O.CornerSlices, options)
	end
end

-- One side's face: `out` is which way it faces, `width` its length. Its ribbon
-- windows, the fins over them, and its share of the glowing band.
local function dressSide(parent: Instance, center: CFrame, out: Vector3, half: number, width: number)
	local face = center * CFrame.lookAt(out * half, out * (half + 1))
	local y = O.CurveRadius + O.WindowGap
	while y + O.WindowHeight <= O.Height - O.TopBand do
		fitting(
			parent,
			"Window",
			Vector3.new(width - 2 * O.WindowInset, O.WindowHeight, 0.4),
			face * CFrame.new(0, y + O.WindowHeight / 2, -0.2),
			O.Glass,
			Enum.Material.Glass
		)
		y += O.WindowHeight + O.WindowGap
	end
	local top = y - O.WindowGap
	local bottom = O.CurveRadius + O.WindowGap
	local x = -width / 2 + O.WindowInset
	while x <= width / 2 - O.WindowInset do
		fitting(
			parent,
			"Fin",
			Vector3.new(O.FinWidth, top - bottom, O.FinDepth),
			face * CFrame.new(x, (top + bottom) / 2, -O.FinDepth / 2),
			O.Fin,
			Enum.Material.SmoothPlastic
		)
		x += O.FinEvery
	end
	fitting(
		parent,
		"GlowBand",
		Vector3.new(width, O.BandHeight, 0.4),
		face * CFrame.new(0, O.Height - O.TopBand / 2, -0.2),
		O.Glow,
		Enum.Material.Neon
	)
end

-- The name on a board on the side facing `out`, with a row of status lights
-- under it.
local function buildSign(parent: Instance, center: CFrame, out: Vector3, half: number)
	local S = O.Sign
	local face = center * CFrame.lookAt(out * half, out * (half + 1))
	local board = fitting(
		parent,
		"SignBoard",
		Vector3.new(S.Width, S.Height, 1),
		face * CFrame.new(0, S.Y, -O.FinDepth - 0.5),
		O.SignColor,
		Enum.Material.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = S.PixelsPerStud
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SciFi
	label.Text = S.Text
	label.TextScaled = true
	label.TextColor3 = O.Glow
	label.Parent = gui
	gui.Parent = board

	local rng = Rng.new(S.Seed)
	local step = S.Width / S.Lights
	for i = 1, S.Lights do
		local color = S.LightColors[math.floor(rng.next() * #S.LightColors) + 1]
		fitting(
			parent,
			"StatusLight",
			Vector3.new(step * 0.6, S.LightHeight, 0.4),
			face * CFrame.new(-S.Width / 2 + (i - 0.5) * step, S.Y - S.Height / 2 - S.LightHeight, -O.FinDepth - 0.2),
			color,
			Enum.Material.Neon
		)
	end
end

-- A low ramp up to one roof edge, like a Downtown roof's: a wedge rises toward
-- its +Z end, so look inward to rise toward the edge.
local function buildLip(parent: Instance, center: CFrame, out: Vector3, half: number, width: number)
	local L = O.Lip
	local middle = out * (half - L.Length / 2) + Vector3.new(0, O.Height + L.Height / 2, 0)
	local lip = Instance.new("WedgePart")
	lip.Name = "Lip"
	lip.Anchored = true
	lip.Size = Vector3.new(width, L.Height, L.Length)
	lip.CFrame = center * CFrame.lookAt(middle, middle - out)
	lip.Color = O.Wall
	lip.Material = Enum.Material.SmoothPlastic
	lip.TopSurface = Enum.SurfaceType.Smooth
	lip.BottomSurface = Enum.SurfaceType.Smooth
	lip.Parent = parent
end

local function buildDish(parent: Instance, roof: CFrame)
	local D = O.Dish
	local spot = roof * CFrame.new(D.X, 0, D.Z)
	upright(parent, "DishPost", D.PostWidth, D.PostHeight, spot, O.Fin, Enum.Material.Metal)
	-- Tipped back toward the sky, its axis along the cylinder's X.
	local mount = spot * CFrame.new(0, D.PostHeight, 0) * CFrame.Angles(0, math.rad(D.Facing), math.rad(D.Tilt))
	local dish = fitting(
		parent,
		"Dish",
		Vector3.new(D.Thickness, D.Diameter, D.Diameter),
		mount,
		O.Wall,
		Enum.Material.SmoothPlastic
	)
	dish.Shape = Enum.PartType.Cylinder
	fitting(
		parent,
		"DishFeed",
		Vector3.new(D.FeedLength, 1, 1),
		mount * CFrame.new(D.FeedLength / 2, 0, 0),
		O.Fin,
		Enum.Material.Metal
	)
	fitting(parent, "DishTip", Vector3.new(3, 3, 3), mount * CFrame.new(D.FeedLength, 0, 0), O.Glow, Enum.Material.Neon).Shape =
		Enum.PartType.Ball
end

local function buildMast(parent: Instance, roof: CFrame)
	local M = O.Mast
	local spot = roof * CFrame.new(M.X, 0, M.Z)
	upright(parent, "Mast", M.Width, M.Height, spot, O.Fin, Enum.Material.Metal)
	for i = 1, M.Bars do
		local y = M.Height * (1 - i / (M.Bars + 1))
		fitting(
			parent,
			"MastBar",
			Vector3.new(M.BarLength * i / M.Bars, 0.8, 0.8),
			spot * CFrame.new(0, y, 0),
			O.Fin,
			Enum.Material.Metal
		)
	end
	fitting(parent, "Beacon", Vector3.new(4, 4, 4), spot * CFrame.new(0, M.Height, 0), O.Beacon, Enum.Material.Neon).Shape =
		Enum.PartType.Ball
end

local function buildVents(parent: Instance, roof: CFrame)
	local V = O.Vents
	for i = 1, V.Count do
		local spot = roof * CFrame.new(V.X + (i - 1) * V.Every, 0, V.Z)
		upright(parent, "Vent", V.Width, V.Height, spot, O.Fin, Enum.Material.Metal)
		upright(parent, "VentGlow", V.Width + 0.6, 1, spot * CFrame.new(0, V.Height - 3, 0), O.Glow, Enum.Material.Neon)
	end
end

local function buildRoof(parent: Instance, center: CFrame, halfX: number, halfZ: number)
	local model = Instance.new("Model")
	model.Name = "Roof"
	model.Parent = parent
	local width, depth = 2 * halfX, 2 * halfZ
	buildLip(model, center, -Vector3.zAxis, halfZ, width)
	buildLip(model, center, Vector3.zAxis, halfZ, width)
	buildLip(model, center, -Vector3.xAxis, halfX, depth)
	buildLip(model, center, Vector3.xAxis, halfX, depth)

	local roof = center * CFrame.new(0, O.Height, 0)
	-- The dome is half sunk into the roof, and solid: a car can hit it.
	local D = O.Dome
	local dome =
		solid(model, "Dome", Vector3.new(D.Diameter, D.Diameter, D.Diameter), roof * CFrame.new(D.X, 0, D.Z), O.Glass)
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.Glass
	dome.Transparency = D.Transparency
	upright(model, "DomeRing", D.Diameter + 3, 1, roof * CFrame.new(D.X, 0, D.Z), O.Glow, Enum.Material.Neon)

	buildDish(model, roof)
	buildMast(model, roof)
	buildVents(model, roof)
end

function PlantOps.build(folder: Instance, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "OpsBuilding"
	model.Parent = folder
	local center = CFrame.new(area.X + O.X, FLOOR, area.Z + O.Z)
	local halfX, halfZ = O.Width / 2, O.Depth / 2

	local tower =
		solid(model, "Tower", Vector3.new(O.Width, O.Height, O.Depth), center * CFrame.new(0, O.Height / 2, 0), O.Wall)
	tower.Name = "Tower"
	buildFoot(model, center, halfX, halfZ)

	local dress = Instance.new("Model")
	dress.Name = "Dress"
	dress.Parent = model
	dressSide(dress, center, Vector3.zAxis, halfZ, O.Width)
	dressSide(dress, center, -Vector3.zAxis, halfZ, O.Width)
	dressSide(dress, center, Vector3.xAxis, halfX, O.Depth)
	dressSide(dress, center, -Vector3.xAxis, halfX, O.Depth)
	buildSign(dress, center, Vector3.zAxis, halfZ)

	buildRoof(model, center, halfX, halfZ)
end

return PlantOps
