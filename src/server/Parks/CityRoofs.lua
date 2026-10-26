--!strict
-- CityRoofs (ModuleScript) -> ServerScriptService.Parks.CityRoofs
-- What goes on the dense city's roofs (Roofs), built by Parks.City into a
-- Roofs model in the park's folder, one Roof model a building with its Kind
-- attribute. It reads the roofs from the buildings already in the folder
-- (every Tower part; the spiral towers have none and are left out) and the
-- cranes standing on them, so it builds the same on a city just built from
-- code and on one saved with the place, without the rest being rebuilt.
-- Rebuilding replaces the folder's Roofs model.
--
-- A lip runs along each roof edge: a wedge in the building's own color and
-- material, rising toward the edge. Numbers are in Tuning.City.Roofs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Roofs = require(ReplicatedStorage.Roofs)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.City.Roofs
local FLOOR = Tuning.Map.FloorTop

local CityRoofs = {}

-- The footprint of an upright box part in park coordinates.
local function footprint(part: BasePart, area: MapLayout.Area): Roofs.Rect
	local p, s = part.Position, part.Size
	return {
		x1 = p.X - s.X / 2 - area.X,
		x2 = p.X + s.X / 2 - area.X,
		z1 = p.Z - s.Z / 2 - area.Z,
		z2 = p.Z + s.Z / 2 - area.Z,
	}
end

-- Every roof in the folder, west to east and then north to south, so the
-- kinds come out the same whichever order the buildings were made in. Each
-- tower's part is kept beside its roof for its look.
local function roofsIn(folder: Instance, area: MapLayout.Area): ({ Roofs.Roof }, { [Roofs.Roof]: BasePart })
	local masts: { BasePart } = {}
	local cranes = folder:FindFirstChild("Cranes")
	if cranes then
		for _, part in cranes:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Mast" then
				table.insert(masts, part)
			end
		end
	end
	local roofs: { Roofs.Roof } = {}
	local towers: { [Roofs.Roof]: BasePart } = {}
	local buildings = folder:FindFirstChild("Buildings")
	for _, part in if buildings then buildings:GetDescendants() else {} do
		if part:IsA("BasePart") and part.Name == "Tower" then
			local rect = footprint(part, area)
			local top = part.Position.Y + part.Size.Y / 2
			local roof: Roofs.Roof = {
				x1 = rect.x1,
				x2 = rect.x2,
				z1 = rect.z1,
				z2 = rect.z2,
				height = top - FLOOR,
				busy = {},
			}
			for _, mast in masts do
				local at = mast.Position
				local foot = at.Y - mast.Size.Y / 2
				if
					at.X - area.X > roof.x1
					and at.X - area.X < roof.x2
					and at.Z - area.Z > roof.z1
					and at.Z - area.Z < roof.z2
					and math.abs(foot - top) < 1
				then
					table.insert(roof.busy, footprint(mast, area))
				end
			end
			table.insert(roofs, roof)
			towers[roof] = part
		end
	end
	table.sort(roofs, function(a, b)
		if a.x1 ~= b.x1 then
			return a.x1 < b.x1
		end
		return a.z1 < b.z1
	end)
	return roofs, towers
end

-- A lip along one edge, its back face flush with the building's side.
local function lip(parent: Instance, area: MapLayout.Area, roof: Roofs.Roof, edge: Roofs.Lip, tower: BasePart)
	local out = Vector3.new(edge.outX, 0, edge.outZ)
	local length = math.abs(edge.x2 - edge.x1) + math.abs(edge.z2 - edge.z1)
	local middle = Vector3.new(area.X + (edge.x1 + edge.x2) / 2, FLOOR + roof.height, area.Z + (edge.z1 + edge.z2) / 2)
	local center = middle - out * (T.LipLength / 2) + Vector3.new(0, T.LipHeight / 2, 0)
	-- A wedge rises toward its +Z end, so look inward to rise toward the edge.
	local part = Instance.new("WedgePart")
	part.Name = "Lip"
	part.Anchored = true
	part.Size = Vector3.new(length, T.LipHeight, T.LipLength)
	part.CFrame = CFrame.lookAt(center, center - out)
	part.Color = tower.Color
	part.Material = tower.Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

function CityRoofs.build(folder: Instance, area: MapLayout.Area)
	local old = folder:FindFirstChild("Roofs")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Roofs"
	local roofs, towers = roofsIn(folder, area)
	for _, plan in Roofs.plan(roofs, T :: any, Rng.new(T.Seed)) do
		local roof = Instance.new("Model")
		roof.Name = "Roof"
		roof:SetAttribute("Kind", plan.kind)
		for _, edge in plan.lips do
			lip(roof, area, plan.roof, edge, towers[plan.roof])
		end
		roof.Parent = model
	end
	model.Parent = folder
end

return CityRoofs
