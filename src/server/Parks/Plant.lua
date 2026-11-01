--!strict
-- Plant (ModuleScript) -> ServerScriptService.Parks.Plant
-- The nuclear plant, built by ParkService into workspace.Parks.Plant: two
-- cooling towers, each a ring of planks spun from CoolingTower's profile, so a
-- car can drive up the outside, over the rim, and down inside, where hot water
-- bursts and throws it out (CarController, ScoreService, PlantWater). Numbers
-- are in Tuning.Plant, the shape in CoolingTower.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoolingTower = require(ReplicatedStorage.CoolingTower)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local S = Tuning.Plant
local T = S.Tower
local W = S.Water
local SHAPE: CoolingTower.Shape = T :: any
local FLOOR = Tuning.Map.FloorTop

local Plant = {}

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

-- A plank of the surface around `angle`, from `a` to `b` on the profile, its
-- top on the surface and the rest of it inside the wall.
local function plank(
	parent: Instance,
	center: CFrame,
	angle: number,
	a: CoolingTower.Point,
	b: CoolingTower.Point,
	half: number,
	apothem: number,
	color: Color3
)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local p0 = out * a.R * apothem + Vector3.yAxis * a.Y
	local p1 = out * b.R * apothem + Vector3.yAxis * b.Y
	local chord = p1 - p0
	local nr, ny = CoolingTower.normal(a, b)
	local normal = out * nr + Vector3.yAxis * ny
	local across = chord.Unit:Cross(normal)
	block(
		parent,
		"Plank",
		Vector3.new(2 * math.max(a.R, b.R) * half + 0.4, T.Thickness, chord.Magnitude + 0.4),
		center * CFrame.fromMatrix((p0 + p1) / 2 - normal * T.Thickness / 2, across, normal, across:Cross(normal)),
		color
	)
end

-- An unseen part in the tower's opening, with steam rising from it all the time.
local function buildSteam(parent: Instance, center: CFrame)
	local F = S.Steam
	local part = block(
		parent,
		"Steam",
		Vector3.new(F.Width, 1, F.Width),
		center * CFrame.new(0, T.Height - F.Below, 0),
		Color3.new(1, 1, 1)
	)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.EmissionDirection = Enum.NormalId.Top
	steam.Rate = F.Rate
	steam.Color = ColorSequence.new(Color3.fromRGB(245, 247, 250), Color3.fromRGB(215, 220, 226))
	steam.Size = NumberSequence.new(F.MinSize, F.MaxSize)
	steam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, F.Thickness),
		NumberSequenceKeypoint.new(1, 1),
	})
	steam.Lifetime = NumberRange.new(F.Lifetime * 0.8, F.Lifetime * 1.2)
	steam.Speed = NumberRange.new(F.MinRise, F.MaxRise)
	steam.SpreadAngle = Vector2.new(8, 8)
	steam.RotSpeed = NumberRange.new(-12, 12)
	steam.Rotation = NumberRange.new(0, 360)
	steam.Acceleration = Vector3.new(F.Drift, 0, 0)
	steam.LightInfluence = 1
	steam.Parent = part
end

local function buildTower(parent: Instance, index: number, center: CFrame)
	local model = Instance.new("Model")
	model.Name = `CoolingTower{index}`
	model.WorldPivot = center
	model.Parent = parent

	local profile = CoolingTower.profile(SHAPE)
	local step = 2 * math.pi / T.Slices
	local half = math.sin(step / 2)
	local apothem = math.cos(step / 2)
	for i = 1, T.Slices do
		local angle = (i - 0.5) * step
		for j = 1, #profile - 1 do
			local a, b = profile[j], profile[j + 1]
			local color = T.Stained:Lerp(T.Clean, (a.Y + b.Y) / 2 / T.Height)
			plank(model, center, angle, a, b, half, apothem, color)
		end
	end

	local floor = 2 * CoolingTower.floorRadius(SHAPE) + 2 * T.Thickness
	block(model, "TowerFloor", Vector3.new(floor, 0.2, floor), center * CFrame.new(0, 0.05, 0), T.FloorColor)

	-- Paint a car drives through. PlantWater makes it boil and burst.
	local water = block(
		model,
		"HotWater",
		Vector3.new(W.Height, 2 * W.Radius, 2 * W.Radius),
		center * CFrame.new(0, W.Height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		W.Look.Calm
	)
	water.Shape = Enum.PartType.Cylinder
	water.Material = Enum.Material.Neon
	water.CanCollide = false
	water.CanQuery = false
	water.CanTouch = false
	water.CastShadow = false
	water:SetAttribute("Tower", index)
	CollectionService:AddTag(water, "TowerWater")

	buildSteam(model, center)
end

function Plant.build(folder: Folder, area: MapLayout.Area)
	for i, place in S.Towers do
		buildTower(folder, i, CFrame.new(area.X + place.X, FLOOR, area.Z + place.Z))
	end
end

return Plant
