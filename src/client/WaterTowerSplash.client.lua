--!strict
-- WaterTowerSplash (LocalScript) -> StarterPlayerScripts.WaterTowerSplash
-- Bursts water out of Downtown's roof water towers when one is smashed.
-- Each tower has an invisible part tagged WaterTowerSplash in the middle of
-- its tank (CityRoofs); the server knocks its staves loose (PropService),
-- and when a stave comes unanchored here the water flies. It also throws
-- a column of water up wherever a car falls into a roof pool, where the
-- server says on ReplicatedStorage.PoolSplash. Particles are drawn on each
-- client, so the bursts are made here.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local S = Tuning.City.Roofs.Splash
local PS = Tuning.City.Roofs.PoolSplash

local TAG = "WaterTowerSplash"
local WATER_COLOR = ColorSequence.new(Color3.fromRGB(170, 215, 255), Color3.fromRGB(90, 150, 220))

local POOL_SPLASH_LIFE = 3 -- seconds before a pool splash's emitters go, past the last drop

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

-- A column of water up from where a car fell in, taller the faster it fell.
local function poolSplash(position: Vector3, falling: number)
	local anchor = Instance.new("Part")
	anchor.Name = "PoolSplash"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	local drops, mist = emitters(anchor)
	drops.SpreadAngle = Vector2.new(35, 35)
	drops.Speed = NumberRange.new(falling * 0.4, falling * 0.9)
	mist.SpreadAngle = Vector2.new(60, 60)
	anchor.Parent = workspace
	drops:Emit(PS.Drops)
	mist:Emit(PS.Mist)
	Debris:AddItem(anchor, POOL_SPLASH_LIFE)
end

for _, splash in CollectionService:GetTagged(TAG) do
	watch(splash)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(forget)

local remote = ReplicatedStorage:WaitForChild("PoolSplash", 30)
if remote and remote:IsA("RemoteEvent") then
	remote.OnClientEvent:Connect(poolSplash)
else
	warn("WaterTowerSplash: no ReplicatedStorage.PoolSplash RemoteEvent; no pool splashes")
end
