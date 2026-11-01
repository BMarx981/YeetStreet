--!strict
-- Plant (ModuleScript) -> ServerScriptService.Parks.Plant
-- The nuclear plant, built by ParkService into workspace.Parks.Plant: two
-- cooling towers, each a ring of planks spun from CoolingTower's profile, so a
-- car can drive up the outside, over the rim, and down inside. Numbers are in
-- Tuning.Plant, the shape in CoolingTower.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoolingTower = require(ReplicatedStorage.CoolingTower)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local S = Tuning.Plant
local T = S.Tower
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

local function buildTower(parent: Instance, index: number, center: CFrame)
	local model = Instance.new("Model")
	model.Name = `CoolingTower{index}`
	model.WorldPivot = center
	model.Parent = parent

	local profile = CoolingTower.profile(SHAPE)
	local step = 2 * math.pi / T.Slices
	local half = math.sin(step / 2)
	local apothem = math.cos(step / 2)
	local grime = Rng.new(T.Seed + index)
	for i = 1, T.Slices do
		local angle = (i - 0.5) * step
		local color = T.Clean:Lerp(T.Stained, grime.next())
		for j = 1, #profile - 1 do
			plank(model, center, angle, profile[j], profile[j + 1], half, apothem, color)
		end
	end

	local floor = 2 * CoolingTower.floorRadius(SHAPE) + 2 * T.Thickness
	block(model, "TowerFloor", Vector3.new(floor, 0.2, floor), center * CFrame.new(0, 0.05, 0), T.FloorColor)
end

function Plant.build(folder: Folder, area: MapLayout.Area)
	for i, place in S.Towers do
		buildTower(folder, i, CFrame.new(area.X + place.X, FLOOR, area.Z + place.Z))
	end
end

return Plant
