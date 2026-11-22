--!strict
-- ScrapyardDressing (ModuleScript) -> ServerScriptService.Parks.ScrapyardDressing
-- The junk along the Scrapyard's walls (Tuning.Scrapyard.Dressing), in a
-- Dressing model, on the spots Dressing picks: stacks of tires, oil drums,
-- and small heaps of junk, each a Shatter model of knockable props that a
-- car bursts with a crash and that pays nothing (PropService); solid rusty
-- shipping containers, one or two high; and tall floodlights shining into
-- the yard. By the gate stands the office shack with the SCRAPYARD sign on
-- its roof.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Dressing = require(ReplicatedStorage.Dressing)
local Junk = require(ReplicatedStorage.Junk)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)
local JunkPieces = require(ServerScriptService.Pieces.JunkPieces)

local D = Tuning.Scrapyard.Dressing
local J = Tuning.Scrapyard.Junk
local FLOOR = Tuning.Map.FloorTop

type Rng = Rng.Rng

local ScrapyardDressing = {}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A model of knockable junk that bursts all at once with a crash.
local function shatter(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Shatter", true)
	model:SetAttribute("BurstSound", "Junk")
	model.Parent = parent
	return model
end

local function knockable(part: BasePart)
	part:SetAttribute("ResetTime", D.ResetTime)
	CollectionService:AddTag(part, "Knockable")
end

-- Two or three stacks of tires lying flat, side by side along the wall.
local function tires(parent: Instance, at: CFrame, rng: Rng)
	local model = shatter(parent, "Tires")
	local stacks = rng.int(2, 3)
	for s = 1, stacks do
		local x = (s - (stacks + 1) / 2) * (J.Tire.Y + 0.4)
		for i = 1, rng.int(3, 6) do
			local part = Instance.new("Part")
			part.Name = "Tire"
			part.Shape = Enum.PartType.Cylinder
			part.Anchored = true
			part.Size = J.Tire
			part.Color = J.TireColor
			part.Material = Enum.Material.SmoothPlastic
			-- A cylinder's axis is its X, stood up so the tire lies flat.
			part.CFrame = at
				* CFrame.new(x + rng.range(-0.3, 0.3), J.Tire.X * (i - 0.5), rng.range(-0.3, 0.3))
				* CFrame.Angles(0, math.rad(rng.range(0, 360)), math.pi / 2)
			part.Parent = model
			knockable(part)
		end
	end
end

-- A few oil drums standing close together.
local function drums(parent: Instance, at: CFrame, rng: Rng)
	local model = shatter(parent, "Drums")
	for _ = 1, rng.int(3, 5) do
		local spot = at * CFrame.new(rng.range(-5, 5), 0, rng.range(-3, 3))
		knockable(JunkPieces.make(model, "Drum", spot, rng))
	end
end

local function heap(parent: Instance, at: CFrame, rng: Rng)
	local model = shatter(parent, "Heap")
	for _, piece in Junk.mound(D.Heap :: any, rng) do
		local spot = at
			* CFrame.new(piece.x, piece.y, piece.z)
			* CFrame.Angles(0, math.rad(piece.yaw), 0)
			* CFrame.Angles(math.rad(piece.tilt), 0, 0)
		knockable(JunkPieces.make(model, piece.kind, spot, rng))
	end
end

-- A rusty shipping container lying along the wall, its doors at one end.
local function container(parent: Instance, at: CFrame, rng: Rng)
	local size = D.Container
	local color = D.ContainerColors[rng.int(1, #D.ContainerColors)]
	local frame = at * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, math.rad(rng.range(-4, 4)), 0)
	block(parent, "Container", size, frame, color, Enum.Material.CorrodedMetal)
	block(
		parent,
		"Doors",
		Vector3.new(0.3, size.Y - 1, size.Z - 1),
		frame * CFrame.new(size.X / 2 + 0.15, 0, 0),
		color:Lerp(Color3.new(0, 0, 0), 0.3),
		Enum.Material.CorrodedMetal
	)
end

local function containers(parent: Instance, at: CFrame, rng: Rng)
	container(parent, at, rng)
	container(parent, at * CFrame.new(rng.range(-2, 2), D.Container.Y, 0), rng)
end

-- A tall pole with a lamp at the top, tipped down to shine into the yard.
local function light(parent: Instance, at: CFrame)
	local L = D.Light
	block(
		parent,
		"LightPole",
		Vector3.new(2, L.Height, 2),
		at * CFrame.new(0, L.Height / 2, 0),
		D.SteelColor,
		Enum.Material.Metal
	)
	local head = at * CFrame.new(0, L.Height, -2) * CFrame.Angles(math.rad(-35), 0, 0)
	block(parent, "LightHead", Vector3.new(8, 3, 3), head, D.SteelColor, Enum.Material.Metal)
	local lens =
		block(parent, "Lens", Vector3.new(7, 2, 0.3), head * CFrame.new(0, 0, -1.6), L.Color, Enum.Material.Neon)
	lens.CanCollide = false
	local lamp = Instance.new("SpotLight")
	lamp.Face = Enum.NormalId.Front
	lamp.Range = L.Range
	lamp.Angle = L.Angle
	lamp.Brightness = L.Brightness
	lamp.Color = L.Color
	lamp.Parent = lens
end

local BUILDERS: { [string]: (Instance, CFrame, Rng) -> () } = {
	Tires = tires,
	Drums = drums,
	Heap = heap,
	Container = container,
	Containers = containers,
}

-- The office shack, its front facing into the yard.
local function shack(parent: Instance, at: CFrame)
	local S = D.Shack
	local size = S.Size
	local model = Instance.new("Model")
	model.Name = "Shack"
	block(model, "Body", size, at * CFrame.new(0, size.Y / 2, 0), S.Color, Enum.Material.CorrodedMetal)
	block(
		model,
		"Roof",
		Vector3.new(size.X + 2, 1, size.Z + 2),
		at * CFrame.new(0, size.Y + 0.5, 0),
		D.SteelColor,
		Enum.Material.Metal
	)
	local front = -size.Z / 2 - 0.1
	block(
		model,
		"Door",
		Vector3.new(4, 8, 0.2),
		at * CFrame.new(-size.X / 4, 4, front),
		Color3.fromRGB(60, 45, 35),
		Enum.Material.Wood
	)
	local window = block(
		model,
		"Window",
		Vector3.new(7, 4, 0.2),
		at * CFrame.new(size.X / 5, 7, front),
		Color3.fromRGB(150, 200, 230),
		Enum.Material.Glass
	)
	window.Transparency = 0.3
	local board = block(
		model,
		"Sign",
		Vector3.new(size.X - 2, 5, 1),
		at * CFrame.new(0, size.Y + 3.5, front + 2),
		Color3.fromRGB(22, 22, 26),
		Enum.Material.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = S.SignColor
	label.Text = "SCRAPYARD"
	label.Parent = gui
	model.Parent = parent
end

-- A place in the yard, on the floor, turned by `facing` degrees.
local function place(area: MapLayout.Area, x: number, z: number, facing: number): CFrame
	return CFrame.new(area.X + x, FLOOR, area.Z + z) * CFrame.Angles(0, math.rad(facing), 0)
end

function ScrapyardDressing.build(folder: Folder, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "Dressing"
	local rng = Rng.new(D.Seed)
	for _, spot in Dressing.spots(D :: any, rng) do
		local at = place(area, spot.x, spot.z, spot.facing)
		if spot.kind == "Light" then
			light(model, at)
		else
			local build = BUILDERS[spot.kind]
			if build then
				build(model, at, rng)
			end
		end
	end
	-- On the west side, facing into the yard like everything there.
	shack(model, place(area, D.Shack.X, D.Shack.Z, 270))
	model.Parent = folder
end

return ScrapyardDressing
