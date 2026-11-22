--!strict
-- Scrapyard park (ModuleScript) -> ServerScriptService.Parks.Scrapyard
-- The junkyard past the east edge wall (Tuning.Scrapyard): a dirt floor, a
-- rusty curved wall all round like the map's edge wall, and a gate through
-- both walls facing the Skate Park. The gate is cut out of TestPark's saved
-- edge wall when the park is built, like the silo's hole in the ground, so
-- the saved place itself never changes. Each machine has its own module:
-- the car crusher (ScrapyardCrusher), Hammer Alley (ScrapyardAlley), the
-- TNT barrel field (ScrapyardTnt), and Scrap Mountain (ScrapyardMountain).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Scrapyard = require(ReplicatedStorage.Scrapyard)
local Tuning = require(ReplicatedStorage.Tuning)
local ScrapyardAlley = require(ServerScriptService.Parks.ScrapyardAlley)
local ScrapyardCrusher = require(ServerScriptService.Parks.ScrapyardCrusher)
local ScrapyardMountain = require(ServerScriptService.Parks.ScrapyardMountain)
local ScrapyardTnt = require(ServerScriptService.Parks.ScrapyardTnt)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)

local S = Tuning.Scrapyard
local FLOOR = Tuning.Map.FloorTop

local ScrapyardPark = {}

local function wallOptions(): CurvedWall.Options
	return {
		radius = S.Wall.Radius,
		endAngle = S.Wall.EndAngle,
		steps = S.Wall.Steps,
		thickness = S.Wall.Thickness,
		color = S.WallColor,
		material = Enum.Material.CorrodedMetal,
	}
end

local function gate(): (number, number)
	return S.GateZ - S.GateWidth / 2, S.GateZ + S.GateWidth / 2
end

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = S.PostColor
	part.Material = Enum.Material.CorrodedMetal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

-- The wall round the yard, as the edge wall is built round the map
-- (TestPark), with the gate left open on the west side.
local function buildWall(folder: Folder, area: MapLayout.Area)
	local wall = Instance.new("Folder")
	wall.Name = "Wall"
	wall.Parent = folder

	local options = wallOptions()
	local depth = CurveProfile.extent(options.radius, options.endAngle)
	local inset = depth + S.Wall.CornerRadius
	local x1, x2 = area.X - area.Width / 2, area.X + area.Width / 2
	local z1, z2 = area.Z - area.Depth / 2, area.Z + area.Depth / 2
	local left, right = x1 + inset, x2 - inset
	local front, back = z1 + inset, z2 - inset

	local function straight(x: number, z: number, out: Vector3, length: number)
		local at = Vector3.new(x, FLOOR, z)
		CurvedWall.straight(wall, CFrame.lookAt(at, at + out), length, options)
	end
	straight(area.X, z1 + depth, -Vector3.zAxis, right - left)
	straight(area.X, z2 - depth, Vector3.zAxis, right - left)
	straight(x2 - depth, (front + back) / 2, Vector3.xAxis, back - front)
	local gateFrom, gateTo = gate()
	for _, piece in Scrapyard.cutSpan(front, back, gateFrom, gateTo) do
		straight(x1 + depth, (piece.from + piece.to) / 2, -Vector3.xAxis, piece.to - piece.from)
	end

	-- Each corner turns left from one side's facing to the next.
	local function corner(x: number, z: number, startOut: Vector3)
		local at = Vector3.new(x, FLOOR, z)
		CurvedWall.corner(wall, CFrame.lookAt(at, at + startOut), S.Wall.CornerRadius, 90, S.Wall.CornerSlices, options)
	end
	corner(left, front, -Vector3.zAxis)
	corner(right, front, Vector3.xAxis)
	corner(right, back, Vector3.zAxis)
	corner(left, back, -Vector3.xAxis)
end

-- Cuts the gate out of the planks of TestPark's east edge wall, replacing
-- each plank it crosses with the pieces either side.
local function cutEdgeWall()
	local testPark = workspace:FindFirstChild("TestPark")
	local edge = testPark and testPark:FindFirstChild("EdgeWall")
	if not edge then
		warn("Scrapyard: no TestPark.EdgeWall to cut the gate in")
		return
	end
	local gateFrom, gateTo = gate()
	local nearest = S.EdgeX - S.Wall.Radius - 10
	for _, plank in edge:GetDescendants() do
		if not (plank:IsA("BasePart") and plank.Name == "Plank") or plank.Position.X < nearest then
			continue
		end
		-- The east side's planks run along Z, their own X.
		local along = plank.CFrame.RightVector
		if math.abs(along.Z) < 0.99 then
			continue
		end
		local middle = plank.Position.Z
		local half = plank.Size.X / 2
		local pieces = Scrapyard.cutSpan(middle - half, middle + half, gateFrom, gateTo)
		if #pieces == 1 and pieces[1].from == middle - half and pieces[1].to == middle + half then
			continue
		end
		for _, piece in pieces do
			local copy = plank:Clone()
			copy.Size = Vector3.new(piece.to - piece.from, plank.Size.Y, plank.Size.Z)
			copy.CFrame = plank.CFrame * CFrame.new(((piece.from + piece.to) / 2 - middle) / along.Z, 0, 0)
			copy.Parent = plank.Parent
		end
		plank:Destroy()
	end
end

-- A post each side of the gate, reaching across both walls, and a beam over
-- the top.
local function buildGate(folder: Folder)
	local model = Instance.new("Model")
	model.Name = "Gate"
	local reach = 2 * CurveProfile.extent(S.Wall.Radius, S.Wall.EndAngle)
	local gateFrom, gateTo = gate()
	for _, z in { gateFrom - S.PostWidth / 2, gateTo + S.PostWidth / 2 } do
		block(
			model,
			"Post",
			Vector3.new(reach, S.PostHeight, S.PostWidth),
			CFrame.new(S.EdgeX, FLOOR + S.PostHeight / 2, z)
		)
	end
	block(
		model,
		"Beam",
		Vector3.new(S.PostWidth, S.BeamHeight, S.GateWidth + 2 * S.PostWidth),
		CFrame.new(S.EdgeX, FLOOR + S.PostHeight - S.BeamHeight / 2, S.GateZ)
	)
	model.Parent = folder
end

function ScrapyardPark.build(folder: Folder, area: MapLayout.Area)
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Floor" then
			child.Color = S.FloorColor
			child.Material = Enum.Material.Ground
		end
	end
	cutEdgeWall()
	buildWall(folder, area)
	buildGate(folder)
	ScrapyardCrusher.build(folder, area)
	ScrapyardAlley.build(folder, area)
	ScrapyardTnt.build(folder, area)
	ScrapyardMountain.build(folder, area)
end

function ScrapyardPark.start(folder: Folder, area: MapLayout.Area)
	ScrapyardCrusher.start(folder, area)
	ScrapyardTnt.start(folder, area)
end

return ScrapyardPark
