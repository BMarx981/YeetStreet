--!strict
-- ShotPath (ModuleScript) -> ReplicatedStorage.ShotPath
-- Where a PlaneCar's shot goes. It leaves the gun's muzzle (PlaneCar.muzzles,
-- as a plane or a car by the car's WingsOut attribute) along the barrel, and
-- stops at the map or at Range. Before that, it hits the first other car it
-- passes within HitRadius of; players' characters don't stop it. The server
-- traces each shot for real (GunService); the shooter's game traces the same
-- way to draw it at once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaneCar = require(ReplicatedStorage.PlaneCar)
local PlaneMorph = require(ReplicatedStorage.PlaneMorph)
local Tuning = require(ReplicatedStorage.Tuning)

local G = Tuning.Guns

local ShotPath = {}

-- The car a part belongs to, if any.
local function carOf(part: Instance, cars: Instance): Model?
	local node = part
	while node.Parent and node.Parent ~= cars do
		node = node.Parent
	end
	return if node.Parent == cars and node:IsA("Model") then node else nil
end

-- From the muzzle of `gun` (1 left, 2 right) on `car`, where the shot stops,
-- and the car it hit, if any.
function ShotPath.trace(car: Model, hull: BasePart, gun: number): (Vector3, Vector3, Model?)
	local stages = PlaneMorph.stages(if car:GetAttribute("WingsOut") == true then 0 else 1)
	local muzzle = hull.CFrame * PlaneCar.muzzles(stages)[gun]
	local from = muzzle.Position
	local cars = workspace:FindFirstChild("Cars")
	if not cars then
		return from, from + muzzle.LookVector * G.Range, nil
	end

	local passThrough: { Instance } = { cars }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(passThrough, player.Character)
		end
	end
	local map = RaycastParams.new()
	map.FilterType = Enum.RaycastFilterType.Exclude
	map.FilterDescendantsInstances = passThrough
	local wall = workspace:Raycast(from, muzzle.LookVector * G.Range, map)
	local reach = if wall then wall.Distance else G.Range

	local others: { Instance } = {}
	for _, other in cars:GetChildren() do
		if other ~= car then
			table.insert(others, other)
		end
	end
	local hit: RaycastResult? = nil
	if #others > 0 then
		local targets = RaycastParams.new()
		targets.FilterType = Enum.RaycastFilterType.Include
		targets.FilterDescendantsInstances = others
		hit = workspace:Spherecast(from, G.HitRadius, muzzle.LookVector * reach, targets)
	end
	if hit then
		return from, hit.Position, carOf(hit.Instance, cars)
	end
	return from, from + muzzle.LookVector * reach, nil
end

return ShotPath
