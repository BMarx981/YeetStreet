--!strict
-- WaterTowerSplash (LocalScript) -> StarterPlayerScripts.WaterTowerSplash
-- Bursts water out of Downtown's roof water towers when one is smashed.
-- Each tower has an invisible part tagged WaterTowerSplash in the middle of
-- its tank (CityRoofs); the server knocks its staves loose (PropService),
-- and when a stave comes unanchored here the water flies. Particles are
-- drawn on each client, so the burst is made here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local S = Tuning.City.Roofs.Splash

local TAG = "WaterTowerSplash"
local WATER_COLOR = ColorSequence.new(Color3.fromRGB(170, 215, 255), Color3.fromRGB(90, 150, 220))

local watched: { [Instance]: RBXScriptConnection } = {}

local function emitters(splash: BasePart): (ParticleEmitter, ParticleEmitter)
	local drops = Instance.new("ParticleEmitter")
	drops.Enabled = false
	drops.Color = WATER_COLOR
	drops.Transparency = NumberSequence.new(0.1, 0.6)
	drops.Size = NumberSequence.new(1.6, 0.6)
	drops.Lifetime = NumberRange.new(1, 2)
	drops.Speed = NumberRange.new(25, 70)
	drops.SpreadAngle = Vector2.new(180, 180)
	drops.Acceleration = Vector3.new(0, -workspace.Gravity * 0.6, 0)
	drops.Parent = splash

	local mist = Instance.new("ParticleEmitter")
	mist.Enabled = false
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	mist.Size = NumberSequence.new(6, 20)
	mist.Transparency = NumberSequence.new(0.5, 1)
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Speed = NumberRange.new(10, 25)
	mist.SpreadAngle = Vector2.new(180, 180)
	mist.Acceleration = Vector3.new(0, -8, 0)
	mist.Parent = splash
	return drops, mist
end

local function watch(splash: Instance)
	local stave = splash.Parent and splash.Parent:FindFirstChild("Stave")
	if watched[splash] or not splash:IsA("BasePart") or not (stave and stave:IsA("BasePart")) then
		return
	end
	local drops, mist = emitters(splash)
	watched[splash] = stave:GetPropertyChangedSignal("Anchored"):Connect(function()
		if not stave.Anchored then
			drops:Emit(S.Drops)
			mist:Emit(S.Mist)
		end
	end)
end

local function forget(splash: Instance)
	local connection = watched[splash]
	if connection then
		connection:Disconnect()
		watched[splash] = nil
	end
end

for _, splash in CollectionService:GetTagged(TAG) do
	watch(splash)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(forget)
