--!strict
-- GarageRing (LocalScript) -> StarterPlayerScripts.GarageRing
-- Paints a dashed ring on the ground around every model tagged Garage, at
-- Tuning.Garage.Reach, so players can see where the garage opens (GarageMenu).
-- It lights up while the player is inside. Each dash sits on whatever is under
-- it, so a ring follows slopes and passes under a building's roof.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GarageRing = require(ReplicatedStorage.GarageRing)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.Garage
local R = T.Ring
local TAG = "Garage"
local COLOR = Color3.fromRGB(255, 196, 0)

local player = Players.LocalPlayer

type Ring = {
	center: Vector3,
	folder: Folder,
	lit: boolean,
}

local rings: { [Instance]: Ring } = {}

local function groundBelow(from: Vector3, depth: number, ignore: Instance): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(from, Vector3.new(0, -depth, 0), params)
	return if hit then hit.Position.Y else nil
end

local function setLit(ring: Ring, lit: boolean)
	ring.lit = lit
	for _, dash in ring.folder:GetChildren() do
		if dash:IsA("BasePart") then
			dash.Transparency = if lit then R.LitTransparency else R.Transparency
		end
	end
end

local function add(garage: Instance)
	if rings[garage] or not garage:IsA("PVInstance") then
		return
	end
	local center = garage:GetPivot().Position
	local groundY = groundBelow(center + Vector3.new(0, R.Probe, 0), R.Probe * 4, garage) or center.Y
	local folder = Instance.new("Folder")
	folder.Name = "GarageRing"
	for _, d in GarageRing.dashes(T.Reach, R.Dashes, R.DashShare) do
		local x, z = center.X + d.x, center.Z + d.z
		local y = groundBelow(Vector3.new(x, groundY + R.Probe, z), R.Probe * 2, garage) or groundY
		local at = Vector3.new(x, y + R.Lift, z)
		local dash = Instance.new("Part")
		dash.Name = "Dash"
		dash.Anchored = true
		dash.CanCollide = false
		dash.CanQuery = false
		dash.CanTouch = false
		dash.CastShadow = false
		dash.Material = Enum.Material.Neon
		dash.Color = COLOR
		dash.Size = Vector3.new(R.Width, R.Thickness, d.length)
		dash.CFrame = CFrame.lookAt(at, at + Vector3.new(d.alongX, 0, d.alongZ))
		dash.Parent = folder
	end
	local ring = { center = center, folder = folder, lit = false }
	setLit(ring, false)
	folder.Parent = workspace
	rings[garage] = ring
end

local function remove(garage: Instance)
	local ring = rings[garage]
	if ring then
		ring.folder:Destroy()
		rings[garage] = nil
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
for _, garage in CollectionService:GetTagged(TAG) do
	add(garage)
end

while true do
	task.wait(R.CheckEvery)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	for _, ring in rings do
		local inside = hrp ~= nil and hrp:IsA("BasePart") and (ring.center - hrp.Position).Magnitude <= T.Reach
		if inside ~= ring.lit then
			setLit(ring, inside)
		end
	end
end
