--!strict
-- TntBoom (LocalScript) -> StarterPlayerScripts.TntBoom
-- Shows the Scrapyard's TNT barrels blowing up (Parks.ScrapyardTnt). When a
-- barrel's BlownAt attribute changes, Roblox's own explosion goes off where
-- it stands, sized to the blast, which pushes nothing and breaks no one's
-- joints, since the server throws the cars and nobody is ever hurt; a
-- little mushroom cloud like the silo missile's climbs out of it
-- (MushroomCloud); and a boom plays. The barrel is hidden here from BlownAt until it stands back up
-- Respawn seconds later.
--
-- During a replay the barrels are as they were at the moment being watched
-- (ReplayWorld): they blow up as the replay plays past it, and the live ones
-- going off meanwhile are not shown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Tnt = require(ReplicatedStorage.Tnt)
local Tuning = require(ReplicatedStorage.Tuning)
local MushroomCloud = require(script.Parent.MushroomCloud)
local OneShot = require(script.Parent.OneShot)
local ReplayWorld = require(script.Parent.ReplayWorld)

local B = Tuning.Scrapyard.Tnt
local S = Tuning.Scrapyard.Sounds
local CONFIG: Tnt.Config = B :: any
local CLOUD: MushroomCloud.Config = B.Cloud :: any

local area = MapLayout.find(Tuning.Map.Areas :: any, "Scrapyard")
if not area then
	return
end

-- Where the barrels stand, as the server laid them out.
local center = Vector3.new(area.X + B.X, Tuning.Map.FloorTop, area.Z + B.Z)
local spots = Tnt.layout(CONFIG, Rng.new(B.Seed))

local function boom(index: number)
	local spot = spots[index]
	if not spot then
		return
	end
	local at = center + Vector3.new(spot.x, B.Height / 2, spot.z)
	local explosion = Instance.new("Explosion")
	explosion.Position = at
	explosion.BlastRadius = B.BlastRadius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace
	MushroomCloud.play(CLOUD, center + Vector3.new(spot.x, 0, spot.z))
	OneShot.at(S.TntBoom, at, S.Near, S.Far)
end

-- Each barrel model and its place in the layout.
local barrels: { [Model]: number } = {}

local function adopt(barrel: Instance)
	local index = barrel:GetAttribute("Index")
	if not barrel:IsA("Model") or typeof(index) ~= "number" or barrels[barrel] then
		return
	end
	barrels[barrel] = index
	ReplayWorld.follow(barrel)
	barrel:GetAttributeChangedSignal("BlownAt"):Connect(function()
		if not ReplayWorld.isWatching() then
			boom(index)
		end
	end)
end

local field = workspace:WaitForChild("Parks"):WaitForChild("Scrapyard"):WaitForChild("TntField")
for _, barrel in field:GetChildren() do
	adopt(barrel)
end
field.ChildAdded:Connect(adopt)

RunService.RenderStepped:Connect(function()
	local now = ReplayWorld.serverTime()
	for barrel, index in barrels do
		if #ReplayWorld.passed(barrel, "BlownAt") > 0 then
			boom(index)
		end
		local blownAt = ReplayWorld.attribute(barrel, "BlownAt")
		local down = typeof(blownAt) == "number" and now >= blownAt and now - blownAt < B.Respawn
		for _, part in barrel:GetChildren() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = if down then 1 else 0
			end
		end
	end
end)
